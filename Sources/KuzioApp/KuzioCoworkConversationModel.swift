import Foundation
import IntatisCodexRuntime
import IntatisConversation
import IntatisCore
import IntatisProtocol
import IntatisSharedUI
import Observation

enum KuzioCoworkConnectionState: Equatable, Sendable {
    case idle
    case starting
    case ready
    case failed
}

/// Host-only state for the shared Intatis CoworkShell.
///
/// Kuzio owns selected-node context, the project tool bridge, and runtime
/// lifetime. Message, composer, permission, inspector, rich-text, scrolling,
/// and status presentation remain owned by IntatisSharedUI.CoworkShell.
@MainActor
@Observable
final class KuzioCoworkHarnessHostModel {
    private static let mainAgentKey = "main"
    private static let mainAgentID = AgentID(rawValue: mainAgentKey)

    let target: KuzioCoworkConversationTarget

    var input = ""
    private(set) var connectionState: KuzioCoworkConnectionState = .idle
    private(set) var sessionID: SessionID?
    private(set) var selectedAgentID = mainAgentKey
    private(set) var isThreadSnapshotLoading = false
    private(set) var isRunning = false
    private(set) var errorMessage: String?
    private(set) var goal: CoworkGoalCardInfo?

    private(set) var threadItemsByAgentID: [String: [CodeItem]] = [
        mainAgentKey: [],
    ]
    private(set) var childDescriptorsByThreadID:
        [String: CodexRuntimeThreadDescriptor] = [:]
    private(set) var knownChildThreadIDs: Set<String> = []
    private(set) var activeChildThreadIDs: Set<String> = []

    @ObservationIgnored private var runtime: CodexAppServerSession?
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var rootThreadID: String?
    @ObservationIgnored private var threadIDByAgentID: [String: String] = [:]
    @ObservationIgnored private var pendingApprovals:
        [CodexRuntimeApprovalRequest] = []
    @ObservationIgnored private var resolvingApprovalID: String?
    private var projectionRevision: UInt64 = 0
    @ObservationIgnored private let projectionGeneration = UUID()
    @ObservationIgnored private var selectionLoadID: UUID?

    private(set) var modelName = "current model"

    init(target: KuzioCoworkConversationTarget) {
        self.target = target
    }

    var presentationSessionID: String {
        sessionID?.rawValue ?? target.requestID.uuidString.lowercased()
    }

    var threadSnapshot: CoworkAgentThreadSnapshot {
        let key = agents.contains(where: { $0.id == selectedAgentID })
            ? selectedAgentID
            : Self.mainAgentKey
        return CoworkAgentThreadSnapshot(
            agentID: AgentID(rawValue: key),
            items: threadItemsByAgentID[key] ?? [],
            projectedThroughSeq: Int(clamping: projectionRevision),
            projectionGeneration: projectionGeneration,
            isAgentWorking: isAgentWorking(key)
        )
    }

    var agents: [CoworkAgentInfo] {
        var result = [CoworkAgentInfo(
            id: Self.mainAgentKey,
            name: Self.mainAgentKey,
            workspace: virtualPath,
            model: modelName,
            permissionProfile: "read-only",
            inferenceProfileLabel: modelName,
            inferenceResolution: .resolved,
            status: mainStatus,
            role: "main",
            isAttached: true,
            canRemove: false,
            isConversationSelectable: true
        )]

        let orderedThreadIDs = knownChildThreadIDs.sorted { lhs, rhs in
            let lhsCreated = childDescriptorsByThreadID[lhs]?.createdAt
                ?? Int.max
            let rhsCreated = childDescriptorsByThreadID[rhs]?.createdAt
                ?? Int.max
            if lhsCreated != rhsCreated { return lhsCreated < rhsCreated }
            return lhs < rhs
        }

        for threadID in orderedThreadIDs {
            let descriptor = childDescriptorsByThreadID[threadID]
            let key = childAgentKey(threadID)
            let childModel = descriptor?.requestedModel ?? modelName
            result.append(CoworkAgentInfo(
                id: key,
                name: descriptor?.displayName ?? fallbackChildName(threadID),
                workspace: virtualPath,
                model: childModel,
                permissionProfile: "read-only",
                inferenceProfileLabel: childModel,
                inferenceResolution: .resolved,
                status: activeChildThreadIDs.contains(threadID)
                    ? "running"
                    : descriptor?.status ?? "idle",
                role: descriptor?.agentRole ?? "worker",
                isAttached: descriptor?.isArchived != true,
                canRemove: false,
                isConversationSelectable: true
            ))
        }
        return result
    }

    var summary: CoworkStatusSummary {
        let statuses = agents.map { normalizedStatus($0.status) }
        let running = statuses.filter {
            ["active", "running", "thinking", "tool"].contains($0)
        }.count
        let completed = statuses.filter {
            ["completed", "complete", "done"].contains($0)
        }.count
        let failed = statuses.filter {
            ["failed", "error", "blocked"].contains($0)
        }.count
        return CoworkStatusSummary(
            activeCount: max(agents.count - completed - failed, 0),
            runningCount: running,
            completedCount: completed,
            failedCount: failed
        )
    }

    var projectInfo: CoworkProjectInfo {
        CoworkProjectInfo(
            sessionID: presentationSessionID,
            mainAgentName: Self.mainAgentKey,
            defaultModel: modelName,
            defaultPermission: "read-only",
            tokenBudget: goal?.tokenBudget.map { "\($0) tokens" },
            workspaces: [
                CoworkWorkspaceInfo(
                    path: target.nodeID.description,
                    displayName: virtualPath,
                    agentName: Self.mainAgentKey,
                    isPrimary: true,
                    access: "read_only",
                    canRemove: false
                ),
            ]
        )
    }

    var pendingPermission: PendingPermission? {
        guard let request = pendingApprovals.first else { return nil }
        return PendingPermission(
            request: PermissionRequestPayload(
                requestId: RequestID(rawValue: request.requestID.description),
                agent: Self.mainAgentID,
                tool: request.kind.rawValue,
                args: request.summary,
                risk: .high,
                reason: request.title,
                approvalMode: .manual
            ),
            state: resolvingApprovalID == request.requestID.description
                ? .resolving
                : .livePending,
            requestedSeq: Int(clamping: projectionRevision)
        )
    }

    var isWorking: Bool {
        isRunning || !activeChildThreadIDs.isEmpty
    }

    var isAcceptingSubmission: Bool {
        connectionState != .ready || isRunning
    }

    func start(using library: LibraryViewModel) async {
        guard runtime == nil,
              connectionState == .idle || connectionState == .failed else {
            return
        }
        connectionState = .starting
        errorMessage = nil

        do {
            let libraryTools = try library.makeReadOnlyCodexLibraryTools()
            let dynamicTools = try libraryTools.dynamicTools()
            let prepared = try await KuzioCoworkRuntimeProfile.prepare(
                target: target,
                dynamicTools: dynamicTools
            )
            let runtime = CodexAppServerSession(
                configuration: prepared.configuration
            )
            let events = await runtime.events()
            self.runtime = runtime
            sessionID = prepared.sessionID
            modelName = prepared.configuration.route.model.rawValue
            eventTask = Task { @MainActor [weak self] in
                for await event in events {
                    guard !Task.isCancelled else { return }
                    self?.handle(event)
                }
            }

            let identity = try await runtime.start()
            rootThreadID = identity.threadID
            do {
                let history = try await runtime.threadHistory(
                    threadID: identity.threadID
                )
                mergeHistory(history, agentKey: Self.mainAgentKey)
            } catch {
                errorMessage = localized(error)
            }
            for descriptor in await runtime.descendantThreadDescriptors() {
                updateChildDescriptor(descriptor)
            }
            connectionState = .ready
        } catch {
            await stopRuntime()
            connectionState = .failed
            errorMessage = localized(error)
        }
    }

    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let runtime,
              connectionState == .ready,
              !isRunning,
              !text.isEmpty else {
            return
        }

        let itemID = "local-user:\(UUID().uuidString.lowercased())"
        appendItem(
            CodeItem(
                id: itemID,
                kind: .user,
                title: "You",
                body: text,
                timestamp: Date()
            ),
            agentKey: Self.mainAgentKey
        )
        isRunning = true
        errorMessage = nil

        do {
            _ = try await runtime.startTurn(text: text)
            input = ""
        } catch {
            removeItem(id: itemID, agentKey: Self.mainAgentKey)
            isRunning = false
            errorMessage = localized(error)
        }
    }

    func interrupt() async {
        guard let runtime, isWorking else { return }
        do {
            try await runtime.interruptCurrentTurn()
        } catch {
            errorMessage = localized(error)
        }
    }

    func resolvePendingApproval(
        _ action: PermissionResponseAction
    ) async {
        guard let runtime, let request = pendingApprovals.first else { return }
        resolvingApprovalID = request.requestID.description
        let decision: CodexRuntimeApprovalDecision
        switch action {
        case .approve:
            decision = .accept
        case .approveAndRemember:
            decision = .acceptForSession
        case .decline:
            decision = .decline
        case .cancelTurn:
            decision = .cancel
        }

        do {
            try await runtime.resolveApproval(
                requestID: request.requestID,
                decision: decision
            )
            pendingApprovals.removeAll {
                $0.requestID == request.requestID
            }
        } catch {
            errorMessage = localized(error)
        }
        resolvingApprovalID = nil
    }

    func selectAgent(_ agentID: String) async {
        guard agents.contains(where: { $0.id == agentID }) else { return }
        selectedAgentID = agentID
        guard let runtime,
              let threadID = threadID(forAgentKey: agentID),
              (threadItemsByAgentID[agentID] ?? []).isEmpty else {
            return
        }

        let loadID = UUID()
        selectionLoadID = loadID
        isThreadSnapshotLoading = true
        defer {
            if selectionLoadID == loadID {
                isThreadSnapshotLoading = false
                selectionLoadID = nil
            }
        }

        do {
            let history = try await runtime.threadHistory(threadID: threadID)
            mergeHistory(history, agentKey: agentID)
        } catch {
            errorMessage = localized(error)
        }
    }

    func shutdown() async {
        await stopRuntime()
    }

    private func stopRuntime() async {
        let task = eventTask
        eventTask = nil
        task?.cancel()
        if let runtime {
            await runtime.shutdown()
        }
        self.runtime = nil
        if let task {
            _ = await task.result
        }
        isRunning = false
        activeChildThreadIDs.removeAll()
        pendingApprovals.removeAll()
        resolvingApprovalID = nil
    }

    private func handle(_ event: CodexRuntimeEvent) {
        switch event {
        case .ready(let identity):
            rootThreadID = identity.threadID

        case .turnStarted:
            isRunning = true

        case .assistantDelta(let itemID, let text, let phase):
            updateMessage(
                agentKey: Self.mainAgentKey,
                itemID: itemID,
                title: Self.mainAgentKey,
                delta: text,
                completedText: nil,
                phase: phase,
                complete: false
            )

        case .assistantCompleted(let itemID, let text, let phase):
            updateMessage(
                agentKey: Self.mainAgentKey,
                itemID: itemID,
                title: Self.mainAgentKey,
                delta: "",
                completedText: text,
                phase: phase,
                complete: true
            )

        case .reasoningDelta, .appServerEvent:
            break

        case .itemStarted(let item):
            updateRuntimeItem(
                agentKey: Self.mainAgentKey,
                item: item,
                complete: false
            )

        case .itemCompleted(let item):
            updateRuntimeItem(
                agentKey: Self.mainAgentKey,
                item: item,
                complete: true
            )

        case .approvalRequested(let request):
            if !pendingApprovals.contains(where: {
                $0.requestID == request.requestID
            }) {
                pendingApprovals.append(request)
                bumpProjection()
            }

        case .approvalResolved(let requestID):
            pendingApprovals.removeAll { $0.requestID == requestID }
            if resolvingApprovalID == requestID.description {
                resolvingApprovalID = nil
            }
            bumpProjection()

        case .responsesUsage(let usage):
            attachUsage(
                usage,
                agentKey: Self.mainAgentKey,
                agentID: Self.mainAgentID
            )

        case .goalUpdated(let snapshot):
            goal = snapshot.map(goalCard)
            bumpProjection()

        case .turnCompleted(let result):
            isRunning = false
            if !result.succeeded {
                errorMessage = result.errorMessage
                    ?? "Cowork task ended with status \(result.status)."
            }

        case .runtimeError(_, let message, let fatal):
            errorMessage = message
            if fatal {
                connectionState = .failed
                isRunning = false
            }

        case .child(let childEvent):
            handleChild(childEvent)
        }
    }

    private func handleChild(_ event: CodexRuntimeChildEvent) {
        switch event {
        case .threadUpdated(let descriptor):
            updateChildDescriptor(descriptor)

        case .turnStarted(let threadID, _):
            registerChildThread(threadID)
            activeChildThreadIDs.insert(threadID)
            bumpProjection()

        case .assistantDelta(
            let threadID,
            _,
            let itemID,
            let text,
            let phase
        ):
            registerChildThread(threadID)
            updateMessage(
                agentKey: childAgentKey(threadID),
                itemID: itemID,
                title: childDisplayName(threadID),
                delta: text,
                completedText: nil,
                phase: phase,
                complete: false
            )

        case .assistantCompleted(
            let threadID,
            _,
            let itemID,
            let text,
            let phase
        ):
            registerChildThread(threadID)
            updateMessage(
                agentKey: childAgentKey(threadID),
                itemID: itemID,
                title: childDisplayName(threadID),
                delta: "",
                completedText: text,
                phase: phase,
                complete: true
            )

        case .userMessage(let threadID, _, let itemID, let text):
            registerChildThread(threadID)
            upsertItem(
                CodeItem(
                    id: messageItemID(
                        agentKey: childAgentKey(threadID),
                        itemID: itemID
                    ),
                    kind: .user,
                    title: Self.mainAgentKey,
                    body: text,
                    timestamp: Date()
                ),
                agentKey: childAgentKey(threadID)
            )

        case .reasoningDelta, .appServerEvent:
            break

        case .itemStarted(let threadID, _, let item):
            registerChildThread(threadID)
            updateRuntimeItem(
                agentKey: childAgentKey(threadID),
                item: item,
                complete: false
            )

        case .itemCompleted(let threadID, _, let item):
            registerChildThread(threadID)
            updateRuntimeItem(
                agentKey: childAgentKey(threadID),
                item: item,
                complete: true
            )

        case .responsesUsage(let threadID, let usage):
            registerChildThread(threadID)
            let key = childAgentKey(threadID)
            attachUsage(
                usage,
                agentKey: key,
                agentID: AgentID(rawValue: key)
            )

        case .turnCompleted(let threadID, let result):
            registerChildThread(threadID)
            activeChildThreadIDs.remove(threadID)
            if !result.succeeded {
                let body = result.errorMessage
                    ?? "Child task ended with status \(result.status)."
                appendItem(
                    CodeItem(
                        id: "\(childAgentKey(threadID)):turn:\(result.turnID)",
                        kind: .runtimeEvent,
                        title: "Task failed",
                        body: body,
                        isFailure: true,
                        timestamp: Date()
                    ),
                    agentKey: childAgentKey(threadID)
                )
            } else {
                bumpProjection()
            }
        }
    }

    private func updateMessage(
        agentKey: String,
        itemID: String,
        title: String,
        delta: String,
        completedText: String?,
        phase: MessagePhase?,
        complete: Bool
    ) {
        let id = messageItemID(agentKey: agentKey, itemID: itemID)
        var items = threadItemsByAgentID[agentKey] ?? []
        if let index = items.firstIndex(where: { $0.id == id }) {
            if let completedText {
                items[index].body = completedText
            } else {
                items[index].body += delta
            }
            items[index].complete = complete
            if let phase { items[index].messagePhase = phase }
        } else {
            items.append(CodeItem(
                id: id,
                kind: .agent,
                title: title,
                body: completedText ?? delta,
                complete: complete,
                timestamp: Date(),
                messagePhase: phase
            ))
        }
        threadItemsByAgentID[agentKey] = items
        bumpProjection()
    }

    private func updateRuntimeItem(
        agentKey: String,
        item: CodexRuntimeItem,
        complete: Bool
    ) {
        let statusLine = item.status.map { "Status: \($0)" }
        let body = [item.detail, statusLine]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        upsertItem(
            CodeItem(
                id: runtimeItemID(agentKey: agentKey, itemID: item.id),
                kind: .runtimeEvent,
                title: item.title,
                body: body,
                complete: complete,
                tags: [item.kind.rawValue],
                isFailure: item.isFailure,
                timestamp: Date()
            ),
            agentKey: agentKey
        )
    }

    private func attachUsage(
        _ usage: CodexRuntimeResponsesUsage,
        agentKey: String,
        agentID: AgentID
    ) {
        var items = threadItemsByAgentID[agentKey] ?? []
        let index: Int?
        if let responseID = usage.responseMessageItemID {
            index = items.firstIndex(where: {
                $0.id == messageItemID(
                    agentKey: agentKey,
                    itemID: responseID
                )
            })
        } else {
            index = items.lastIndex(where: { $0.kind == .agent })
        }
        guard let index else { return }

        let payload = ResponsesUsagePayload(
            turnID: TurnID(rawValue: usage.turnID),
            responseMessageID: usage.responseMessageItemID.map {
                MessageID(rawValue: $0)
            },
            agentID: agentID,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.cachedInputTokens,
            cacheWriteInputTokens: usage.cacheWriteInputTokens,
            outputTokens: usage.outputTokens,
            reasoningOutputTokens: usage.reasoningOutputTokens,
            totalTokens: usage.totalTokens,
            durationMs: usage.durationMs
        )
        items[index].responsesUsage = ResponsesUsageSnapshot(
            id: "\(agentKey):usage:\(usage.turnID)",
            payload: payload
        )
        threadItemsByAgentID[agentKey] = items
        bumpProjection()
    }

    private func mergeHistory(
        _ history: CodexRuntimeThreadHistory,
        agentKey: String
    ) {
        let title = agentKey == Self.mainAgentKey
            ? Self.mainAgentKey
            : childDisplayName(history.threadID)
        var merged = history.items.map {
            codeItem(from: $0, agentKey: agentKey, title: title)
        }
        for liveItem in threadItemsByAgentID[agentKey] ?? [] {
            if let index = merged.firstIndex(where: { $0.id == liveItem.id }) {
                merged[index] = liveItem
            } else {
                merged.append(liveItem)
            }
        }
        threadItemsByAgentID[agentKey] = merged
        bumpProjection()
    }

    private func codeItem(
        from source: CodexRuntimeTranscriptItem,
        agentKey: String,
        title: String
    ) -> CodeItem {
        switch source {
        case .user(let id, _, let text):
            return CodeItem(
                id: messageItemID(agentKey: agentKey, itemID: id),
                kind: .user,
                title: "You",
                body: text
            )
        case .assistant(let id, _, let text, let phase, let complete):
            return CodeItem(
                id: messageItemID(agentKey: agentKey, itemID: id),
                kind: .agent,
                title: title,
                body: text,
                complete: complete,
                messagePhase: phase
            )
        case .runtime(_, let item):
            let statusLine = item.status.map { "Status: \($0)" }
            return CodeItem(
                id: runtimeItemID(agentKey: agentKey, itemID: item.id),
                kind: .runtimeEvent,
                title: item.title,
                body: [item.detail, statusLine]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n"),
                tags: [item.kind.rawValue],
                isFailure: item.isFailure
            )
        }
    }

    private func updateChildDescriptor(
        _ descriptor: CodexRuntimeThreadDescriptor
    ) {
        knownChildThreadIDs.insert(descriptor.threadID)
        childDescriptorsByThreadID[descriptor.threadID] = descriptor
        let key = descriptor.agentID.rawValue
        threadIDByAgentID[key] = descriptor.threadID
        if threadItemsByAgentID[key] == nil {
            threadItemsByAgentID[key] = []
        }
        if ["completed", "failed", "cancelled"].contains(
            normalizedStatus(descriptor.status)
        ) {
            activeChildThreadIDs.remove(descriptor.threadID)
        }
        bumpProjection()
    }

    private func registerChildThread(_ threadID: String) {
        knownChildThreadIDs.insert(threadID)
        let key = childAgentKey(threadID)
        threadIDByAgentID[key] = threadID
        if threadItemsByAgentID[key] == nil {
            threadItemsByAgentID[key] = []
        }
    }

    private func upsertItem(_ item: CodeItem, agentKey: String) {
        var items = threadItemsByAgentID[agentKey] ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var replacement = item
            replacement.responsesUsage = items[index].responsesUsage
            replacement.turnStats = items[index].turnStats
            replacement.timestamp = items[index].timestamp ?? item.timestamp
            items[index] = replacement
        } else {
            items.append(item)
        }
        threadItemsByAgentID[agentKey] = items
        bumpProjection()
    }

    private func appendItem(_ item: CodeItem, agentKey: String) {
        var items = threadItemsByAgentID[agentKey] ?? []
        items.append(item)
        threadItemsByAgentID[agentKey] = items
        bumpProjection()
    }

    private func removeItem(id: String, agentKey: String) {
        var items = threadItemsByAgentID[agentKey] ?? []
        items.removeAll { $0.id == id }
        threadItemsByAgentID[agentKey] = items
        bumpProjection()
    }

    private func goalCard(
        _ snapshot: CodexRuntimeGoalSnapshot
    ) -> CoworkGoalCardInfo {
        CoworkGoalCardInfo(
            id: "codex-goal:\(snapshot.threadID)",
            objective: snapshot.objective,
            status: snapshot.status,
            activeElapsedSeconds: Double(snapshot.timeUsedSeconds),
            tokensUsed: snapshot.tokensUsed,
            tokenBudget: snapshot.tokenBudget,
            revision: snapshot.updatedAt,
            canPause: false,
            canResume: false,
            canEdit: false,
            canClear: false
        )
    }

    private func threadID(forAgentKey key: String) -> String? {
        if key == Self.mainAgentKey { return rootThreadID }
        return threadIDByAgentID[key]
    }

    private func childAgentKey(_ threadID: String) -> String {
        childDescriptorsByThreadID[threadID]?.agentID.rawValue
            ?? "codex:\(threadID)"
    }

    private func childDisplayName(_ threadID: String) -> String {
        childDescriptorsByThreadID[threadID]?.displayName
            ?? fallbackChildName(threadID)
    }

    private func fallbackChildName(_ threadID: String) -> String {
        "agent-" + String(threadID.suffix(8))
    }

    private func isAgentWorking(_ agentKey: String) -> Bool {
        if agentKey == Self.mainAgentKey { return isRunning }
        guard let threadID = threadIDByAgentID[agentKey] else { return false }
        return activeChildThreadIDs.contains(threadID)
    }

    private var mainStatus: String {
        if isRunning { return "running" }
        switch connectionState {
        case .idle: return "idle"
        case .starting: return "starting"
        case .ready: return "ready"
        case .failed: return "failed"
        }
    }

    private var virtualPath: String {
        let path = target.virtualPath.joined(separator: " / ")
        return path.isEmpty ? target.title : path
    }

    private func normalizedStatus(_ status: String) -> String {
        status
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }

    private func messageItemID(agentKey: String, itemID: String) -> String {
        "\(agentKey):message:\(itemID)"
    }

    private func runtimeItemID(agentKey: String, itemID: String) -> String {
        "\(agentKey):runtime:\(itemID)"
    }

    private func bumpProjection() {
        projectionRevision &+= 1
    }

    private func localized(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "Cowork session could not continue."
    }
}
