import Foundation

enum StoredNodeKind: String, Codable, Hashable, Sendable {
    case folder
    case document
    case resourceLink = "resource-link"
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

struct StoredResourceLinkRecord: Codable, Hashable, Sendable {
    let resourceID: ResourceID
}

enum StoredExternalResourceKind: String, Codable, Hashable, Sendable {
    case file
    case directory
    case https
}

enum StoredExternalResourceAccessMode: String, Codable, Hashable, Sendable {
    case readOnly = "read-only"
}

struct StoredLocatorReference: Codable, Hashable, Sendable {
    let objectID: ObjectID
    let locatorSchemaVersion: UInt32
    let byteCount: UInt64
    let sha256: String
}

struct StoredExternalResourceOrigin: Codable, Hashable, Sendable {
    let importID: ImportID
    let relativePathComponents: [String]
}

struct StoredExternalResourceRecord: Codable, Hashable, Sendable {
    let id: ResourceID
    let kind: StoredExternalResourceKind
    let accessMode: StoredExternalResourceAccessMode
    var locator: StoredLocatorReference
    var lastKnownName: String
    var contentTypeIdentifier: String?
    var origin: StoredExternalResourceOrigin?
    let createdAtUnixMilliseconds: Int64
    var modifiedAtUnixMilliseconds: Int64
    var lastModifiedRevision: UInt64
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
    var resourceLink: StoredResourceLinkRecord?
}

struct StoredTrashRecord: Codable, Hashable, Sendable {
    let rootNodeID: NodeID
    let originalParentID: NodeID
    let originalChildIndex: Int
    let trashedAtUnixMilliseconds: Int64
}

struct LibraryManifestHeader: Codable, Sendable {
    let formatIdentifier: String
    let layoutVersion: UInt32
    let schemaVersion: UInt32
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

struct LibraryManifestV2: Codable, Hashable, Sendable {
    static let formatIdentifier = LibraryManifestV1.formatIdentifier
    static let layoutVersion = LibraryManifestV1.layoutVersion
    static let schemaVersion: UInt32 = 2

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
    var externalResources: [StoredExternalResourceRecord]
    var trash: [StoredTrashRecord]

    init(
        formatIdentifier: String,
        layoutVersion: UInt32,
        schemaVersion: UInt32,
        libraryID: LibraryID,
        revision: UInt64,
        lastTransactionID: TransactionID?,
        rootNodeID: NodeID,
        createdAtUnixMilliseconds: Int64,
        modifiedAtUnixMilliseconds: Int64,
        nodes: [StoredNodeRecord],
        externalResources: [StoredExternalResourceRecord],
        trash: [StoredTrashRecord]
    ) {
        self.formatIdentifier = formatIdentifier
        self.layoutVersion = layoutVersion
        self.schemaVersion = schemaVersion
        self.libraryID = libraryID
        self.revision = revision
        self.lastTransactionID = lastTransactionID
        self.rootNodeID = rootNodeID
        self.createdAtUnixMilliseconds = createdAtUnixMilliseconds
        self.modifiedAtUnixMilliseconds = modifiedAtUnixMilliseconds
        self.nodes = nodes
        self.externalResources = externalResources
        self.trash = trash
    }

    init(projecting legacy: LibraryManifestV1) {
        self.init(
            formatIdentifier: legacy.formatIdentifier,
            layoutVersion: legacy.layoutVersion,
            schemaVersion: Self.schemaVersion,
            libraryID: legacy.libraryID,
            revision: legacy.revision,
            lastTransactionID: legacy.lastTransactionID,
            rootNodeID: legacy.rootNodeID,
            createdAtUnixMilliseconds: legacy.createdAtUnixMilliseconds,
            modifiedAtUnixMilliseconds: legacy.modifiedAtUnixMilliseconds,
            nodes: legacy.nodes,
            externalResources: [],
            trash: legacy.trash
        )
    }
}

enum DecodedLibraryManifest: Sendable {
    case v1(LibraryManifestV1)
    case v2(LibraryManifestV2)

    var libraryID: LibraryID {
        switch self {
        case .v1(let manifest): manifest.libraryID
        case .v2(let manifest): manifest.libraryID
        }
    }

    var revision: UInt64 {
        switch self {
        case .v1(let manifest): manifest.revision
        case .v2(let manifest): manifest.revision
        }
    }

    var lastTransactionID: TransactionID? {
        switch self {
        case .v1(let manifest): manifest.lastTransactionID
        case .v2(let manifest): manifest.lastTransactionID
        }
    }
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
