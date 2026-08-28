import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum LibraryDestination: String, CaseIterable, Identifiable, Hashable {
    case library
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "资料库"
        case .trash: return "废纸篓"
        }
    }

    var systemImage: String {
        switch self {
        case .library: return "books.vertical"
        case .trash: return "trash"
        }
    }
}

@MainActor
@Observable
final class LibraryViewModel {
    @ObservationIgnored private var store: LibraryStore?

    private(set) var snapshot: LibrarySnapshot?
    private(set) var activeDocument: StoredDocument?
    private(set) var isLoading = false
    private(set) var isAddingResources = false
    private(set) var errorMessage: String?
    private(set) var maintenanceMessage: String?

    var destination: LibraryDestination = .library
    var selectedFolderID: NodeID?
    var searchText = ""

    private var folderHistory: [NodeID] = []
    private var folderHistoryIndex = 0

    var currentFolder: LibraryEntry? {
        guard let snapshot else { return nil }
        return snapshot.entry(selectedFolderID ?? snapshot.rootNodeID) ?? snapshot.root
    }

    var currentPath: [LibraryEntry] {
        guard let snapshot, let currentFolder else { return [] }
        return snapshot.path(to: currentFolder.id)
    }

    var displayedEntries: [LibraryEntry] {
        guard let snapshot, let currentFolder else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return snapshot.activeEntriesMatching(query)
        }
        return snapshot.children(of: currentFolder.id)
    }

    var canGoBack: Bool {
        folderHistoryIndex > 0
    }

    var canGoForward: Bool {
        folderHistoryIndex < folderHistory.count - 1
    }

    func start() async {
        guard store == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let openedStore = try await LibraryBootstrap.open()
            store = openedStore
            let loadedSnapshot = try await openedStore.snapshot()
            applyInitialSnapshot(loadedSnapshot)
        } catch {
            errorMessage = localized(error)
        }
    }

    func refresh() async {
        guard let store else { return }
        do {
            let refreshed = try await store.refresh()
            applySnapshot(refreshed)
        } catch {
            errorMessage = localized(error)
        }
    }

    func selectDestination(_ destination: LibraryDestination) {
        self.destination = destination
        activeDocument = nil
        searchText = ""
        if destination == .library, let snapshot {
            resetHistory(to: snapshot.rootNodeID)
        }
    }

    func selectFolder(_ id: NodeID) {
        guard snapshot?.entry(id)?.isFolder == true else { return }
        activeDocument = nil
        navigate(to: id)
    }

    func openDocument(_ id: NodeID) async {
        guard let store else { return }
        do {
            activeDocument = try await store.readDocument(id)
        } catch {
            errorMessage = localized(error)
        }
    }

    func openEntry(_ id: NodeID) async {
        guard let entry = snapshot?.entry(id) else { return }
        switch entry.kind {
        case .folder:
            selectFolder(id)
        case .document:
            await openDocument(id)
        case .resourceLink:
            await openExternalResourceLink(entry)
        }
    }

    func closeDocument() {
        activeDocument = nil
    }

    func goBack() {
        guard canGoBack else { return }
        folderHistoryIndex -= 1
        selectedFolderID = folderHistory[folderHistoryIndex]
        activeDocument = nil
        searchText = ""
    }

    func goForward() {
        guard canGoForward else { return }
        folderHistoryIndex += 1
        selectedFolderID = folderHistory[folderHistoryIndex]
        activeDocument = nil
        searchText = ""
    }

    func createFolder(title: String) async {
        guard let store, let snapshot, let parent = currentFolder else { return }
        await performMutation {
            try await store.createFolder(
                in: parent.id,
                title: title,
                expectedRevision: snapshot.revision
            ).receipt
        }
    }

    func createDocument(title: String) async {
        guard let store, let snapshot, let parent = currentFolder else { return }
        var createdID: NodeID?
        await performMutation {
            let created = try await store.createDocument(
                in: parent.id,
                title: title,
                data: Data(),
                expectedRevision: snapshot.revision
            )
            createdID = created.id
            return created.receipt
        }
        if let createdID {
            await openDocument(createdID)
        }
    }

    func createExternalLinks(to urls: [URL]) async {
        guard let store,
              let snapshot,
              let parent = currentFolder,
              !urls.isEmpty,
              !isAddingResources else { return }
        isAddingResources = true
        defer { isAddingResources = false }
        do {
            let selectedURLs = urls
            let drafts = try await Task.detached(priority: .userInitiated) {
                try LibraryExternalLinkImporter.drafts(for: selectedURLs)
            }.value
            await performMutation {
                try await store.createExternalLinkedTree(
                    in: parent.id,
                    drafts: drafts,
                    expectedRevision: snapshot.revision
                ).receipt
            }
        } catch {
            errorMessage = localized(error)
        }
    }

    func createExternalFileLink(to url: URL) async {
        await createExternalLinks(to: [url])
    }

    func canRelinkFolder(_ id: NodeID) -> Bool {
        folderRelinkPlan(for: id) != nil
    }

    func relinkFile(_ id: NodeID, to url: URL) async {
        guard let store,
              let snapshot,
              let entry = snapshot.entry(id),
              entry.externalResource?.kind == .file,
              !isAddingResources else { return }
        isAddingResources = true
        defer { isAddingResources = false }

        do {
            let file = try await Task.detached(priority: .userInitiated) {
                try LibraryExternalLinkImporter.fileDraft(for: url)
            }.value
            await performMutation {
                try await store.replaceExternalResourceLocator(
                    for: entry.id,
                    locatorData: file.locatorData,
                    lastKnownName: file.lastKnownName,
                    contentTypeIdentifier: file.contentTypeIdentifier,
                    preservesImportOrigin: false,
                    expectedRevision: snapshot.revision
                )
            }
        } catch {
            errorMessage = localized(error)
        }
    }

    func relinkFolder(_ id: NodeID, to url: URL) async {
        guard let store,
              let snapshot,
              let plan = folderRelinkPlan(for: id),
              !isAddingResources else { return }
        isAddingResources = true
        defer { isAddingResources = false }

        do {
            let drafts = try await Task.detached(priority: .userInitiated) {
                try LibraryExternalLinkImporter.relinkDrafts(
                    for: url,
                    importID: plan.importID,
                    targets: plan.targets
                )
            }.value
            await performMutation {
                try await store.replaceExternalResourceLocators(
                    drafts,
                    expectedRevision: snapshot.revision
                )
            }
        } catch {
            errorMessage = localized(error)
        }
    }

    func rename(_ id: NodeID, to title: String) async {
        guard let store, let snapshot else { return }
        await performMutation {
            try await store.rename(id, to: title, expectedRevision: snapshot.revision)
        }
    }

    func move(_ id: NodeID, to parentID: NodeID) async {
        guard let store, let snapshot else { return }
        await performMutation {
            try await store.move(id, to: parentID, expectedRevision: snapshot.revision)
        }
    }

    func moveToTrash(_ id: NodeID) async {
        guard let store, let snapshot else { return }
        await performMutation {
            try await store.trash(id, expectedRevision: snapshot.revision)
        }
        if activeDocument?.nodeID == id {
            activeDocument = nil
        }
        if selectedFolderID == id, let snapshot = self.snapshot {
            resetHistory(to: snapshot.rootNodeID)
        }
    }

    func restore(_ id: NodeID, to parentID: NodeID? = nil) async {
        guard let store, let snapshot else { return }
        await performMutation {
            try await store.restore(
                id,
                to: parentID,
                expectedRevision: snapshot.revision
            )
        }
    }

    func permanentlyDelete(_ id: NodeID) async {
        guard let store, let snapshot else { return }
        await performMutation {
            try await store.permanentlyDeleteTrashItem(
                id,
                expectedRevision: snapshot.revision
            )
        }
    }

    func saveActiveDocument(text: String) async {
        guard let store, let snapshot, let document = activeDocument else { return }
        await performMutation {
            try await store.updateDocument(
                document.nodeID,
                data: Data(text.utf8),
                expectedNodeRevision: snapshot.entry(document.nodeID)?.lastModifiedRevision,
                expectedRevision: snapshot.revision
            )
        }
        await openDocument(document.nodeID)
    }

    func folderDestinations(excluding id: NodeID? = nil) -> [LibraryEntry] {
        snapshot?.folderDestinations(excluding: id) ?? []
    }

    func makeReadOnlyCodexLibraryTools() throws -> KuzioCodexLibraryTools {
        guard let store else {
            throw KuzioCoworkRuntimeError.libraryUnavailable
        }
        return KuzioCodexLibraryTools(store: store)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func folderRelinkPlan(for folderID: NodeID) -> LibraryFolderRelinkPlan? {
        guard let snapshot,
              snapshot.entry(folderID)?.isFolder == true else { return nil }

        let descendants = descendantResourceEntries(in: folderID, snapshot: snapshot)
        guard !descendants.isEmpty else { return nil }
        let importIDs = Set(descendants.compactMap { $0.externalResource?.origin?.importID })

        if importIDs.count == 1, let importID = importIDs.first {
            var targetsByResourceID: [ResourceID: LibraryExternalResourceRelinkTarget] = [:]
            for entry in snapshot.entries.values {
                guard let resource = entry.externalResource,
                      resource.kind == .file,
                      let origin = resource.origin,
                      origin.importID == importID else { continue }
                targetsByResourceID[resource.resourceID] = LibraryExternalResourceRelinkTarget(
                    resourceID: resource.resourceID,
                    relativePathComponents: origin.relativePathComponents
                )
            }
            let targets = targetsByResourceID.values.sorted {
                $0.resourceID.description < $1.resourceID.description
            }
            return targets.isEmpty ? nil : LibraryFolderRelinkPlan(
                importID: importID,
                targets: targets
            )
        }

        guard importIDs.isEmpty else { return nil }
        return legacyFolderRelinkPlan(for: folderID, snapshot: snapshot)
    }

    private func descendantResourceEntries(
        in folderID: NodeID,
        snapshot: LibrarySnapshot
    ) -> [LibraryEntry] {
        var result: [LibraryEntry] = []
        var stack = snapshot.entry(folderID)?.childIDs ?? []
        var visited: Set<NodeID> = []

        while let id = stack.popLast() {
            guard visited.insert(id).inserted,
                  let entry = snapshot.entry(id) else { continue }
            if entry.isFolder {
                stack.append(contentsOf: entry.childIDs)
            } else if entry.isResourceLink {
                result.append(entry)
            }
        }
        return result
    }

    private func legacyFolderRelinkPlan(
        for folderID: NodeID,
        snapshot: LibrarySnapshot
    ) -> LibraryFolderRelinkPlan? {
        let importID = ImportID()
        var targetsByResourceID: [ResourceID: LibraryExternalResourceRelinkTarget] = [:]
        var stack = (snapshot.entry(folderID)?.childIDs ?? []).reversed().map {
            ($0, [String]())
        }
        var visited: Set<NodeID> = []

        while let (id, parentComponents) = stack.popLast() {
            guard visited.insert(id).inserted,
                  let entry = snapshot.entry(id) else { continue }
            if entry.isFolder {
                let components = parentComponents + [entry.title]
                for childID in entry.childIDs.reversed() {
                    stack.append((childID, components))
                }
                continue
            }
            guard entry.isResourceLink,
                  let resource = entry.externalResource,
                  resource.kind == .file,
                  resource.origin == nil else { continue }
            let target = LibraryExternalResourceRelinkTarget(
                resourceID: resource.resourceID,
                relativePathComponents: parentComponents + [resource.lastKnownName]
            )
            if let existing = targetsByResourceID[resource.resourceID], existing != target {
                return nil
            }
            targetsByResourceID[resource.resourceID] = target
        }

        let targets = targetsByResourceID.values.sorted {
            $0.resourceID.description < $1.resourceID.description
        }
        return targets.isEmpty ? nil : LibraryFolderRelinkPlan(
            importID: importID,
            targets: targets
        )
    }

    private func performMutation(
        _ operation: () async throws -> LibraryCommitReceipt
    ) async {
        do {
            let receipt = try await operation()
            if receipt.cleanupPending {
                maintenanceMessage = "资料库已更新，残留对象将在后续维护中清理。"
            }
            await refresh()
        } catch {
            errorMessage = localized(error)
        }
    }

    private func openExternalResourceLink(_ entry: LibraryEntry) async {
        guard let store, let metadata = entry.externalResource else {
            errorMessage = localized(LibraryExternalResourceAccessError.linkUnavailable(entry.title))
            return
        }

        do {
            let resource = try await store.readExternalResource(metadata.resourceID)
            guard resource.kind == .file else {
                throw LibraryExternalResourceAccessError.unsupportedResourceKind
            }
            try await openExternalFile(resource, from: entry, using: store)
        } catch {
            errorMessage = localized(error)
        }
    }

    private func openExternalFile(
        _ resource: StoredExternalResource,
        from entry: LibraryEntry,
        using store: LibraryStore
    ) async throws {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: resource.locatorData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw LibraryExternalResourceAccessError.linkUnavailable(resource.lastKnownName)
        }

        let startedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard (try? url.checkResourceIsReachable()) == true else {
            throw LibraryExternalResourceAccessError.linkUnavailable(resource.lastKnownName)
        }

        if isStale {
            guard let snapshot else {
                throw LibraryExternalResourceAccessError.linkUnavailable(resource.lastKnownName)
            }
            let file = try LibraryExternalLinkImporter.fileDraft(for: url)
            let receipt = try await store.replaceExternalResourceLocator(
                for: entry.id,
                locatorData: file.locatorData,
                lastKnownName: file.lastKnownName,
                contentTypeIdentifier: file.contentTypeIdentifier,
                expectedRevision: snapshot.revision
            )
            if receipt.cleanupPending {
                maintenanceMessage = "资料库已更新，残留对象将在后续维护中清理。"
            }
            applySnapshot(try await store.refresh())
        }

        guard NSWorkspace.shared.open(url) else {
            throw LibraryExternalResourceAccessError.openFailed(resource.lastKnownName)
        }
    }

    private func applyInitialSnapshot(_ snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
        destination = .library
        resetHistory(to: snapshot.rootNodeID)
    }

    private func applySnapshot(_ snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
        if let selectedFolderID,
           snapshot.entry(selectedFolderID)?.isFolder == true {
            self.selectedFolderID = selectedFolderID
        } else {
            resetHistory(to: snapshot.rootNodeID)
        }
    }

    private func navigate(to id: NodeID) {
        guard selectedFolderID != id else { return }
        if folderHistoryIndex < folderHistory.count - 1 {
            folderHistory.removeSubrange((folderHistoryIndex + 1)...)
        }
        folderHistory.append(id)
        folderHistoryIndex = folderHistory.count - 1
        selectedFolderID = id
        searchText = ""
    }

    private func resetHistory(to id: NodeID) {
        folderHistory = [id]
        folderHistoryIndex = 0
        selectedFolderID = id
        activeDocument = nil
        searchText = ""
    }

    private func localized(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "资料库操作失败。"
    }
}

private struct LibraryFolderRelinkPlan: Sendable {
    let importID: ImportID
    let targets: [LibraryExternalResourceRelinkTarget]
}

private struct LibraryExternalResourceRelinkTarget: Hashable, Sendable {
    let resourceID: ResourceID
    let relativePathComponents: [String]
}

private enum LibraryExternalLinkImporter {
    private struct PendingItem: Sendable {
        let url: URL
        let parentDraftIndex: Int?
        let importID: ImportID?
        let relativePathComponents: [String]
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .contentTypeKey,
        .isDirectoryKey,
        .isPackageKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .nameKey,
    ]

    static func drafts(for selectedURLs: [URL]) throws -> [LibraryLinkedItemDraft] {
        guard !selectedURLs.isEmpty else { return [] }

        var scopedURLs: [URL] = []
        for url in selectedURLs where url.startAccessingSecurityScopedResource() {
            scopedURLs.append(url)
        }
        defer {
            for url in scopedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var drafts: [LibraryLinkedItemDraft] = []
        var pending = selectedURLs.reversed().map {
            PendingItem(
                url: $0,
                parentDraftIndex: nil,
                importID: nil,
                relativePathComponents: []
            )
        }

        while let item = pending.popLast() {
            try Task.checkCancellation()
            guard drafts.count < LibraryManifestValidator.maximumNodeCount else {
                throw LibraryExternalResourceAccessError.tooManyItems
            }

            let values = try resourceValues(for: item.url)
            let name = values.name ?? item.url.lastPathComponent
            guard !name.isEmpty else {
                throw LibraryExternalResourceAccessError.unsupportedItem("未命名项目")
            }
            guard values.isSymbolicLink != true else {
                throw LibraryExternalResourceAccessError.unsupportedItem(name)
            }

            if values.isDirectory == true, values.isPackage != true {
                let importID = item.importID ?? ImportID()
                let folderIndex = drafts.count
                drafts.append(
                    LibraryLinkedItemDraft(
                        parentDraftIndex: item.parentDraftIndex,
                        title: name,
                        kind: .folder
                    )
                )

                let children: [URL]
                do {
                    children = try FileManager.default.contentsOfDirectory(
                        at: item.url,
                        includingPropertiesForKeys: Array(resourceKeys),
                        options: [.skipsHiddenFiles]
                    )
                } catch {
                    throw LibraryExternalResourceAccessError.itemReadFailed(name)
                }
                for child in children.sorted(by: linkedItemOrder).reversed() {
                    pending.append(
                        PendingItem(
                            url: child,
                            parentDraftIndex: folderIndex,
                            importID: importID,
                            relativePathComponents: item.relativePathComponents
                                + [child.lastPathComponent]
                        )
                    )
                }
                continue
            }

            guard values.isRegularFile == true || values.isPackage == true else {
                throw LibraryExternalResourceAccessError.unsupportedItem(name)
            }
            drafts.append(
                LibraryLinkedItemDraft(
                    parentDraftIndex: item.parentDraftIndex,
                    title: name,
                    kind: .file(
                        try fileDraft(
                            for: item.url,
                            resourceValues: values,
                            origin: item.importID.map {
                                LibraryExternalResourceOrigin(
                                    importID: $0,
                                    relativePathComponents: item.relativePathComponents
                                )
                            }
                        )
                    )
                )
            )
        }

        return drafts
    }

    static func fileDraft(for url: URL) throws -> LibraryLinkedFileDraft {
        let values = try resourceValues(for: url)
        guard values.isSymbolicLink != true,
              values.isRegularFile == true || values.isPackage == true else {
            throw LibraryExternalResourceAccessError.unsupportedItem(
                values.name ?? url.lastPathComponent
            )
        }
        return try fileDraft(for: url, resourceValues: values, origin: nil)
    }

    static func relinkDrafts(
        for rootURL: URL,
        importID: ImportID,
        targets: [LibraryExternalResourceRelinkTarget]
    ) throws -> [LibraryExternalResourceRelinkDraft] {
        guard !targets.isEmpty else { return [] }
        let startedAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let rootValues = try resourceValues(for: rootURL)
        guard rootValues.isDirectory == true,
              rootValues.isPackage != true,
              rootValues.isSymbolicLink != true else {
            throw LibraryExternalResourceAccessError.unsupportedItem(
                rootValues.name ?? rootURL.lastPathComponent
            )
        }

        return try targets.map { target in
            try Task.checkCancellation()
            let targetURL = try childURL(
                under: rootURL,
                relativePathComponents: target.relativePathComponents
            )
            let file = try fileDraft(for: targetURL)
            return LibraryExternalResourceRelinkDraft(
                resourceID: target.resourceID,
                locatorData: file.locatorData,
                lastKnownName: file.lastKnownName,
                contentTypeIdentifier: file.contentTypeIdentifier,
                origin: LibraryExternalResourceOrigin(
                    importID: importID,
                    relativePathComponents: target.relativePathComponents
                )
            )
        }
    }

    private static func fileDraft(
        for url: URL,
        resourceValues: URLResourceValues,
        origin: LibraryExternalResourceOrigin?
    ) throws -> LibraryLinkedFileDraft {
        let name = resourceValues.name ?? url.lastPathComponent
        guard !name.isEmpty else {
            throw LibraryExternalResourceAccessError.unsupportedItem("未命名项目")
        }
        let bookmarkData: Data
        do {
            bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: [.contentTypeKey, .nameKey],
                relativeTo: nil
            )
        } catch {
            throw LibraryExternalResourceAccessError.linkCreationFailed(name)
        }
        return LibraryLinkedFileDraft(
            locatorData: bookmarkData,
            lastKnownName: name,
            contentTypeIdentifier: resourceValues.contentType?.identifier,
            origin: origin
        )
    }

    private static func childURL(
        under rootURL: URL,
        relativePathComponents: [String]
    ) throws -> URL {
        guard !relativePathComponents.isEmpty else {
            throw LibraryExternalResourceAccessError.unsupportedItem(rootURL.lastPathComponent)
        }
        var result = rootURL.standardizedFileURL
        for component in relativePathComponents {
            guard !component.isEmpty,
                  component != ".",
                  component != "..",
                  !component.contains("/") else {
                throw LibraryExternalResourceAccessError.unsupportedItem(component)
            }
            result.appendPathComponent(component, isDirectory: false)
        }

        let rootPath = rootURL.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard result.standardizedFileURL.path.hasPrefix(prefix) else {
            throw LibraryExternalResourceAccessError.unsupportedItem(result.lastPathComponent)
        }
        return result
    }

    private static func resourceValues(for url: URL) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: resourceKeys)
        } catch {
            throw LibraryExternalResourceAccessError.itemReadFailed(url.lastPathComponent)
        }
    }

    private static func linkedItemOrder(_ left: URL, _ right: URL) -> Bool {
        left.lastPathComponent.localizedStandardCompare(right.lastPathComponent) == .orderedAscending
    }
}

private enum LibraryExternalResourceAccessError: LocalizedError {
    case itemReadFailed(String)
    case unsupportedItem(String)
    case tooManyItems
    case linkCreationFailed(String)
    case linkUnavailable(String)
    case openFailed(String)
    case unsupportedResourceKind

    var errorDescription: String? {
        switch self {
        case .itemReadFailed(let name):
            return "无法读取“\(name)”。"
        case .unsupportedItem(let name):
            return "无法链接“\(name)”。"
        case .tooManyItems:
            return "所选内容超过资料库容量。"
        case .linkCreationFailed(let name):
            return "无法为“\(name)”创建只读链接。"
        case .linkUnavailable(let name):
            return "无法访问“\(name)”。文件可能已移动、离线或权限已失效。"
        case .openFailed(let name):
            return "系统无法打开“\(name)”。"
        case .unsupportedResourceKind:
            return "当前版本只支持打开文件链接。"
        }
    }
}
