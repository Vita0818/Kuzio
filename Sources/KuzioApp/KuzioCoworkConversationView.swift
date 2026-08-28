import IntatisSharedUI
import SwiftUI

/// Thin lifecycle host for IntatisSharedUI.CoworkShell.
///
/// Kuzio contributes selected library context and runtime actions only. The
/// complete Harness presentation is rendered by the dependency.
@MainActor
struct KuzioCoworkHarnessHost: View {
    let library: LibraryViewModel
    let target: KuzioCoworkConversationTarget
    let onClose: () -> Void

    @State private var model: KuzioCoworkHarnessHostModel
    @State private var showsInspector = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        library: LibraryViewModel,
        target: KuzioCoworkConversationTarget,
        onClose: @escaping () -> Void
    ) {
        self.library = library
        self.target = target
        self.onClose = onClose
        _model = State(initialValue: KuzioCoworkHarnessHostModel(
            target: target
        ))
    }

    var body: some View {
        @Bindable var harness = model

        CoworkShell(
            threadSnapshot: model.threadSnapshot,
            presentationScope: IntatisThreadPresentationScope(
                kind: "cowork",
                sessionID: model.presentationSessionID
            ),
            sessionTitle: target.title,
            thinkingScopeID: model.presentationSessionID,
            agents: model.agents,
            pending: model.pendingPermission,
            summary: model.summary,
            project: model.projectInfo,
            goal: model.goal,
            errorTexts: errorTexts,
            isWorking: model.isWorking,
            isAcceptingSubmission: model.isAcceptingSubmission,
            threadStyle: .standard(colorScheme),
            splitLayout: .workspace,
            headerActions: [closeAction],
            showsInspector: $showsInspector,
            input: $harness.input,
            onSend: {
                Task { await model.send() }
            },
            onCancelCurrent: cancelAction,
            onResolve: { action in
                Task { await model.resolvePendingApproval(action) }
            },
            selectedAgentID: model.selectedAgentID,
            isThreadSnapshotLoading: model.isThreadSnapshotLoading,
            isRichRenderingEligible: true,
            onSelectAgent: { agentID in
                Task { await model.selectAgent(agentID) }
            }
        )
        .accessibilityIdentifier("cowork.harness.intatis-shared-ui")
        .task {
            await library.start()
            await model.start(using: library)
        }
        .onDisappear {
            Task {
                await model.shutdown()
            }
        }
    }

    private var closeAction: IntatisThreadHeaderAction {
        IntatisThreadHeaderAction(
            title: "Close AI conversation",
            systemImage: "xmark",
            isIconOnly: true,
            presentation: .compactSystemIcon,
            help: "Close AI conversation",
            accessibilityIdentifier: "cowork.harness.close",
            action: onClose
        )
    }

    private var cancelAction: (() -> Void)? {
        guard model.isWorking else { return nil }
        return {
            Task { await model.interrupt() }
        }
    }

    private var errorTexts: [String] {
        model.errorMessage.map { [$0] } ?? []
    }
}
