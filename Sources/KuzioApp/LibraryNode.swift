import Foundation

enum LibraryEntryKind: Hashable, Sendable {
    case folder
    case document
    case resourceLink
}

struct LibraryDocumentMetadata: Hashable, Sendable {
    let mediaType: String
    let byteCount: UInt64
    let contentRevision: UInt64
}

enum LibraryExternalResourceKind: Hashable, Sendable {
    case file
    case directory
    case https
}

struct LibraryExternalResourceOrigin: Hashable, Sendable {
    let importID: ImportID
    let relativePathComponents: [String]
}

struct LibraryExternalResourceMetadata: Hashable, Sendable {
    let resourceID: ResourceID
    let kind: LibraryExternalResourceKind
    let lastKnownName: String
    let contentTypeIdentifier: String?
    let locatorByteCount: UInt64
    let origin: LibraryExternalResourceOrigin?
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
    let externalResource: LibraryExternalResourceMetadata?
    let isTrashedRoot: Bool

    var isFolder: Bool {
        kind == .folder
    }

    var isDocument: Bool {
        kind == .document
    }

    var isResourceLink: Bool {
        kind == .resourceLink
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

struct StoredExternalResource: Sendable {
    let resourceID: ResourceID
    let kind: LibraryExternalResourceKind
    let locatorData: Data
    let lastKnownName: String
    let contentTypeIdentifier: String?
    let origin: LibraryExternalResourceOrigin?
    let modifiedAt: Date
}

struct LibraryLinkedFileDraft: Sendable {
    let locatorData: Data
    let lastKnownName: String
    let contentTypeIdentifier: String?
    let origin: LibraryExternalResourceOrigin?

    init(
        locatorData: Data,
        lastKnownName: String,
        contentTypeIdentifier: String?,
        origin: LibraryExternalResourceOrigin? = nil
    ) {
        self.locatorData = locatorData
        self.lastKnownName = lastKnownName
        self.contentTypeIdentifier = contentTypeIdentifier
        self.origin = origin
    }
}

struct LibraryExternalResourceRelinkDraft: Sendable {
    let resourceID: ResourceID
    let locatorData: Data
    let lastKnownName: String
    let contentTypeIdentifier: String?
    let origin: LibraryExternalResourceOrigin
}

enum LibraryLinkedItemDraftKind: Sendable {
    case folder
    case file(LibraryLinkedFileDraft)
}

struct LibraryLinkedItemDraft: Sendable {
    let parentDraftIndex: Int?
    let title: String
    let kind: LibraryLinkedItemDraftKind
}

struct LibraryCommitReceipt: Sendable {
    let revision: UInt64
    let transactionID: TransactionID
    let createdNodeIDs: [NodeID]
    let changedNodeIDs: [NodeID]
    let deletedNodeIDs: [NodeID]
    let createdResourceIDs: [ResourceID]
    let changedResourceIDs: [ResourceID]
    let deletedResourceIDs: [ResourceID]
    let cleanupPending: Bool
}

struct CreatedLibraryNode: Sendable {
    let id: NodeID
    let receipt: LibraryCommitReceipt
}

struct CreatedExternalResourceLink: Sendable {
    let nodeID: NodeID
    let resourceID: ResourceID
    let receipt: LibraryCommitReceipt
}

struct CreatedLinkedTree: Sendable {
    let rootNodeIDs: [NodeID]
    let receipt: LibraryCommitReceipt
}
