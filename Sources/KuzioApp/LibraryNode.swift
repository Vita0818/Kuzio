import Foundation

enum LibraryEntryKind: Hashable, Sendable {
    case folder
    case document
}

struct LibraryDocumentMetadata: Hashable, Sendable {
    let mediaType: String
    let byteCount: UInt64
    let contentRevision: UInt64
}

struct LibraryEntry: Identifiable, Hashable, Sendable {
    let id: NodeID
    let parentID: NodeID?
    let kind: LibraryEntryKind
    let title: String
    let childIDs: [NodeID]
    let createdAt: Date
    let modifiedAt: Date
    let lastModifiedRevision: UInt64
    let document: LibraryDocumentMetadata?
    let isTrashedRoot: Bool

    var isFolder: Bool {
        kind == .folder
    }

}

struct LibraryTrashItem: Identifiable, Hashable, Sendable {
    let id: NodeID
    let title: String
    let kind: LibraryEntryKind
    let trashedAt: Date
}

struct LibrarySnapshot: Sendable {
    let libraryID: LibraryID
    let revision: UInt64
    let rootNodeID: NodeID
    let entries: [NodeID: LibraryEntry]
    let trashItems: [LibraryTrashItem]

    var root: LibraryEntry {
        guard let root = entries[rootNodeID] else {
            preconditionFailure("Validated snapshots always contain the root node.")
        }
        return root
    }

    func entry(_ id: NodeID) -> LibraryEntry? {
        entries[id]
    }

    func children(of folderID: NodeID) -> [LibraryEntry] {
        guard let folder = entries[folderID], folder.isFolder else {
            return []
        }
        return folder.childIDs.compactMap { entries[$0] }
    }

    func path(to id: NodeID) -> [LibraryEntry] {
        var result: [LibraryEntry] = []
        var currentID: NodeID? = id
        var visited: Set<NodeID> = []

        while let nodeID = currentID,
              let entry = entries[nodeID],
              visited.insert(nodeID).inserted {
            result.append(entry)
            currentID = entry.parentID
        }

        return result.reversed()
    }

    func activeEntriesMatching(_ query: String) -> [LibraryEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        var result: [LibraryEntry] = []
        var stack = [rootNodeID]
        var visited: Set<NodeID> = []

        while let id = stack.popLast() {
            guard visited.insert(id).inserted, let entry = entries[id] else {
                continue
            }

            if id != rootNodeID, entry.title.localizedStandardContains(normalized) {
                result.append(entry)
            }
            stack.append(contentsOf: entry.childIDs.reversed())
        }

        return result
    }

    func folderDestinations(excluding excludedRoot: NodeID? = nil) -> [LibraryEntry] {
        var result: [LibraryEntry] = []
        var excluded: Set<NodeID> = []

        if let excludedRoot {
            var stack = [excludedRoot]
            while let id = stack.popLast() {
                guard excluded.insert(id).inserted, let entry = entries[id] else {
                    continue
                }
                stack.append(contentsOf: entry.childIDs)
            }
        }

        var stack = [rootNodeID]
        var visited: Set<NodeID> = []
        while let id = stack.popLast() {
            guard visited.insert(id).inserted, let entry = entries[id] else {
                continue
            }
            if entry.isFolder, !excluded.contains(id) {
                result.append(entry)
            }
            stack.append(contentsOf: entry.childIDs.reversed())
        }
        return result
    }
}

struct StoredDocument: Sendable {
    let nodeID: NodeID
    let title: String
    let data: Data
    let mediaType: String
    let contentRevision: UInt64
    let modifiedAt: Date

    var text: String? {
        String(data: data, encoding: .utf8)
    }
}

struct LibraryCommitReceipt: Sendable {
    let revision: UInt64
    let transactionID: TransactionID
    let createdNodeIDs: [NodeID]
    let changedNodeIDs: [NodeID]
    let deletedNodeIDs: [NodeID]
    let cleanupPending: Bool
}

struct CreatedLibraryNode: Sendable {
    let id: NodeID
    let receipt: LibraryCommitReceipt
}
