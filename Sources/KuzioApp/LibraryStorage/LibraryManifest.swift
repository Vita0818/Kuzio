import Foundation

enum StoredNodeKind: String, Codable, Hashable, Sendable {
    case folder
    case document
}

struct StoredFolderRecord: Codable, Hashable, Sendable {
    var children: [NodeID]
}

struct StoredPayloadReference: Codable, Hashable, Sendable {
    let objectID: ObjectID
    let mediaType: String
    let payloadSchemaVersion: UInt32
    let byteCount: UInt64
    let sha256: String
}

struct StoredDocumentRecord: Codable, Hashable, Sendable {
    var contentRevision: UInt64
    var payload: StoredPayloadReference
}

struct StoredNodeRecord: Codable, Hashable, Sendable {
    let id: NodeID
    let kind: StoredNodeKind
    var title: String
    let createdAtUnixMilliseconds: Int64
    var modifiedAtUnixMilliseconds: Int64
    var lastModifiedRevision: UInt64
    var folder: StoredFolderRecord?
    var document: StoredDocumentRecord?
}

struct StoredTrashRecord: Codable, Hashable, Sendable {
    let rootNodeID: NodeID
    let originalParentID: NodeID
    let originalChildIndex: Int
    let trashedAtUnixMilliseconds: Int64
}

struct LibraryManifestV1: Codable, Hashable, Sendable {
    static let formatIdentifier = "com.vitemis.kuzio.library"
    static let layoutVersion: UInt32 = 1
    static let schemaVersion: UInt32 = 1

    let formatIdentifier: String
    let layoutVersion: UInt32
    let schemaVersion: UInt32
    let libraryID: LibraryID
    var revision: UInt64
    var lastTransactionID: TransactionID?
    let rootNodeID: NodeID
    let createdAtUnixMilliseconds: Int64
    var modifiedAtUnixMilliseconds: Int64
    var nodes: [StoredNodeRecord]
    var trash: [StoredTrashRecord]
}

struct LibraryTransactionIntent: Codable, Sendable {
    let transactionID: TransactionID
    let libraryID: LibraryID
    let baseRevision: UInt64
    let targetRevision: UInt64
    let createdObjectIDs: [ObjectID]
    let invalidatesPreviousManifest: Bool
}

struct LibraryPurgeIntent: Codable, Sendable {
    let transactionID: TransactionID
    let targetRevision: UInt64
    let objectIDs: [ObjectID]
}

enum LibraryClock {
    static func nowUnixMilliseconds() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000).rounded())
    }

    static func date(fromUnixMilliseconds value: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
    }
}
