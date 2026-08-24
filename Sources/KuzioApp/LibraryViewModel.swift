import Foundation
import Observation

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

    func dismissError() {
        errorMessage = nil
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
