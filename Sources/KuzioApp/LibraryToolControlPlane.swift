import Foundation

enum LibraryToolName: String, CaseIterable, Codable, Sendable {
    case getState = "library_get_state"
    case listChildren = "library_list_children"
    case readContent = "library_read_content"
    case createFolder = "library_create_folder"
    case renameNode = "library_rename_node"
    case moveNode = "library_move_node"
    case trashNode = "library_trash_node"
    case restoreNode = "library_restore_node"
}

enum LibraryToolCapability: String, Codable, Hashable, Sendable {
    case readStructure = "read_structure"
    case readContent = "read_content"
    case mutateStructure = "mutate_structure"
}

struct LibraryToolAuthorization: Sendable {
    let capabilities: Set<LibraryToolCapability>

    init(capabilities: Set<LibraryToolCapability>) {
        self.capabilities = capabilities
    }

    func allows(_ capability: LibraryToolCapability) -> Bool {
        capabilities.contains(capability)
    }
}

enum LibraryToolCall: Sendable {
    case getState
    case listChildren(parentNodeID: NodeID)
    case readContent(nodeID: NodeID, byteOffset: UInt64, maximumBytes: Int)
    case createFolder(
        parentNodeID: NodeID,
        title: String,
        index: Int?,
        expectedRevision: UInt64
    )
    case renameNode(nodeID: NodeID, title: String, expectedRevision: UInt64)
    case moveNode(
        nodeID: NodeID,
        destinationParentNodeID: NodeID,
        index: Int?,
        expectedRevision: UInt64
    )
    case trashNode(nodeID: NodeID, expectedRevision: UInt64)
    case restoreNode(
        nodeID: NodeID,
        destinationParentNodeID: NodeID?,
        index: Int?,
        expectedRevision: UInt64
    )

    var name: LibraryToolName {
        switch self {
        case .getState: .getState
        case .listChildren: .listChildren
        case .readContent: .readContent
        case .createFolder: .createFolder
        case .renameNode: .renameNode
        case .moveNode: .moveNode
        case .trashNode: .trashNode
        case .restoreNode: .restoreNode
        }
    }

    var requiredCapability: LibraryToolCapability {
        switch self {
        case .getState, .listChildren:
            .readStructure
        case .readContent:
            .readContent
        case .createFolder, .renameNode, .moveNode, .trashNode, .restoreNode:
            .mutateStructure
        }
    }
}

enum LibraryToolNodeKind: String, Codable, Equatable, Sendable {
    case folder
    case document
    case resourceLink = "resource_link"
}

struct LibraryToolNode: Codable, Equatable, Sendable {
    let nodeID: NodeID
    let parentNodeID: NodeID?
    let kind: LibraryToolNodeKind
    let title: String
    let childCount: Int
    let lastModifiedRevision: UInt64
    let resourceID: ResourceID?
    let mediaType: String?
    let byteCount: UInt64?
    let isTrashedRoot: Bool

    private enum CodingKeys: String, CodingKey {
        case nodeID
        case parentNodeID
        case kind
        case title
        case childCount
        case lastModifiedRevision
        case resourceID
        case mediaType
        case byteCount
        case isTrashedRoot
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeID, forKey: .nodeID)
        if let parentNodeID {
            try container.encode(parentNodeID, forKey: .parentNodeID)
        } else {
            try container.encodeNil(forKey: .parentNodeID)
        }
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(childCount, forKey: .childCount)
        try container.encode(lastModifiedRevision, forKey: .lastModifiedRevision)
        if let resourceID {
            try container.encode(resourceID, forKey: .resourceID)
        } else {
            try container.encodeNil(forKey: .resourceID)
        }
        if let mediaType {
            try container.encode(mediaType, forKey: .mediaType)
        } else {
            try container.encodeNil(forKey: .mediaType)
        }
        if let byteCount {
            try container.encode(byteCount, forKey: .byteCount)
        } else {
            try container.encodeNil(forKey: .byteCount)
        }
        try container.encode(isTrashedRoot, forKey: .isTrashedRoot)
    }
}

struct LibraryToolStateOutput: Codable, Equatable, Sendable {
    let libraryID: LibraryID
    let revision: UInt64
    let root: LibraryToolNode
    let trash: [LibraryToolNode]
}

struct LibraryToolChildrenOutput: Codable, Equatable, Sendable {
    let revision: UInt64
    let parent: LibraryToolNode
    let children: [LibraryToolNode]
}

enum LibraryToolContentSource: String, Codable, Equatable, Sendable {
    case document
    case resourceLink = "resource_link"
}

struct LibraryToolContentOutput: Codable, Equatable, Sendable {
    let revision: UInt64
    let nodeID: NodeID
    let source: LibraryToolContentSource
    let mediaType: String?
    let contentTypeIdentifier: String?
    let text: String
    let byteOffset: UInt64
    let nextByteOffset: UInt64?
    let totalByteCount: UInt64
    let truncated: Bool

    private enum CodingKeys: String, CodingKey {
        case revision
        case nodeID
        case source
        case mediaType
        case contentTypeIdentifier
        case text
        case byteOffset
        case nextByteOffset
        case totalByteCount
        case truncated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(revision, forKey: .revision)
        try container.encode(nodeID, forKey: .nodeID)
        try container.encode(source, forKey: .source)
        if let mediaType {
            try container.encode(mediaType, forKey: .mediaType)
        } else {
            try container.encodeNil(forKey: .mediaType)
        }
        if let contentTypeIdentifier {
            try container.encode(contentTypeIdentifier, forKey: .contentTypeIdentifier)
        } else {
            try container.encodeNil(forKey: .contentTypeIdentifier)
        }
        try container.encode(text, forKey: .text)
        try container.encode(byteOffset, forKey: .byteOffset)
        if let nextByteOffset {
            try container.encode(nextByteOffset, forKey: .nextByteOffset)
        } else {
            try container.encodeNil(forKey: .nextByteOffset)
        }
        try container.encode(totalByteCount, forKey: .totalByteCount)
        try container.encode(truncated, forKey: .truncated)
    }
}

struct LibraryToolMutationOutput: Codable, Equatable, Sendable {
    let revision: UInt64
    let transactionID: TransactionID
    let primaryNodeID: NodeID?
    let createdNodeIDs: [NodeID]
    let changedNodeIDs: [NodeID]
    let deletedNodeIDs: [NodeID]
    let cleanupPending: Bool

    private enum CodingKeys: String, CodingKey {
        case revision
        case transactionID
        case primaryNodeID
        case createdNodeIDs
        case changedNodeIDs
        case deletedNodeIDs
        case cleanupPending
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(revision, forKey: .revision)
        try container.encode(transactionID, forKey: .transactionID)
        if let primaryNodeID {
            try container.encode(primaryNodeID, forKey: .primaryNodeID)
        } else {
            try container.encodeNil(forKey: .primaryNodeID)
        }
        try container.encode(createdNodeIDs, forKey: .createdNodeIDs)
        try container.encode(changedNodeIDs, forKey: .changedNodeIDs)
        try container.encode(deletedNodeIDs, forKey: .deletedNodeIDs)
        try container.encode(cleanupPending, forKey: .cleanupPending)
    }
}

enum LibraryToolOutput: Sendable {
    case state(LibraryToolStateOutput)
    case children(LibraryToolChildrenOutput)
    case content(LibraryToolContentOutput)
    case mutation(LibraryToolMutationOutput)
}

enum LibraryToolErrorCode: String, Codable, Equatable, Sendable {
    case invalidArguments = "invalid_arguments"
    case permissionDenied = "permission_denied"
    case nodeNotFound = "node_not_found"
    case resourceNotFound = "resource_not_found"
    case parentNotFound = "parent_not_found"
    case parentNotFolder = "parent_not_folder"
    case kindMismatch = "kind_mismatch"
    case rootMutationForbidden = "root_mutation_forbidden"
    case cycleDetected = "cycle_detected"
    case alreadyTrashed = "already_trashed"
    case notInTrash = "not_in_trash"
    case invalidRestoreDestination = "invalid_restore_destination"
    case revisionConflict = "revision_conflict"
    case resourceUnavailable = "resource_unavailable"
    case unsupportedContent = "unsupported_content"
    case contentNotUTF8 = "content_not_utf8"
    case storeFailure = "store_failure"
}

struct LibraryToolFailure: Error, Codable, Equatable, Sendable {
    let code: LibraryToolErrorCode
    let argument: String?
    let nodeID: NodeID?
    let resourceID: ResourceID?
    let expectedRevision: UInt64?
    let actualRevision: UInt64?

    init(
        code: LibraryToolErrorCode,
        argument: String? = nil,
        nodeID: NodeID? = nil,
        resourceID: ResourceID? = nil,
        expectedRevision: UInt64? = nil,
        actualRevision: UInt64? = nil
    ) {
        self.code = code
        self.argument = argument
        self.nodeID = nodeID
        self.resourceID = resourceID
        self.expectedRevision = expectedRevision
        self.actualRevision = actualRevision
    }
}

enum LibraryToolExecutionResult: Sendable {
    case success(LibraryToolOutput)
    case failure(LibraryToolFailure)
}

actor LibraryToolControlPlane {
    static let defaultContentReadBytes = 65_536
    static let maximumContentReadBytes = 262_144

    private let store: LibraryStore
    private let authorization: LibraryToolAuthorization

    init(store: LibraryStore, authorization: LibraryToolAuthorization) {
        self.store = store
        self.authorization = authorization
    }

    func execute(_ call: LibraryToolCall) async -> LibraryToolExecutionResult {
        guard authorization.allows(call.requiredCapability) else {
            return .failure(LibraryToolFailure(code: .permissionDenied))
        }

        do {
            return .success(try await executeAuthorized(call))
        } catch let failure as LibraryToolFailure {
            return .failure(failure)
        } catch let error as LibraryStoreError {
            return .failure(Self.failure(for: error))
        } catch {
            return .failure(LibraryToolFailure(code: .storeFailure))
        }
    }

    private func executeAuthorized(_ call: LibraryToolCall) async throws -> LibraryToolOutput {
        switch call {
        case .getState:
            let snapshot = try await store.refresh()
            let trash = snapshot.trashItems.compactMap { item in
                snapshot.entry(item.id).map(Self.toolNode)
            }
            return .state(
                LibraryToolStateOutput(
                    libraryID: snapshot.libraryID,
                    revision: snapshot.revision,
                    root: Self.toolNode(snapshot.root),
                    trash: trash
                )
            )

        case .listChildren(let parentNodeID):
            let snapshot = try await store.refresh()
            guard let parent = snapshot.entry(parentNodeID) else {
                throw LibraryStoreError.nodeNotFound(parentNodeID)
            }
            guard parent.isFolder else {
                throw LibraryStoreError.kindMismatch(parentNodeID)
            }
            return .children(
                LibraryToolChildrenOutput(
                    revision: snapshot.revision,
                    parent: Self.toolNode(parent),
                    children: snapshot.children(of: parentNodeID).map(Self.toolNode)
                )
            )

        case .readContent(let nodeID, let byteOffset, let maximumBytes):
            return .content(
                try await readContent(
                    nodeID: nodeID,
                    byteOffset: byteOffset,
                    maximumBytes: maximumBytes
                )
            )

        case .createFolder(let parentNodeID, let title, let index, let expectedRevision):
            let created = try await store.createFolder(
                in: parentNodeID,
                title: title,
                at: index,
                expectedRevision: expectedRevision
            )
            return .mutation(Self.mutationOutput(created.receipt, primaryNodeID: created.id))

        case .renameNode(let nodeID, let title, let expectedRevision):
            let receipt = try await store.rename(
                nodeID,
                to: title,
                expectedRevision: expectedRevision
            )
            return .mutation(Self.mutationOutput(receipt))

        case .moveNode(
            let nodeID,
            let destinationParentNodeID,
            let index,
            let expectedRevision
        ):
            let receipt = try await store.move(
                nodeID,
                to: destinationParentNodeID,
                at: index,
                expectedRevision: expectedRevision
            )
            return .mutation(Self.mutationOutput(receipt))

        case .trashNode(let nodeID, let expectedRevision):
            let receipt = try await store.trash(
                nodeID,
                expectedRevision: expectedRevision
            )
            return .mutation(Self.mutationOutput(receipt))

        case .restoreNode(
            let nodeID,
            let destinationParentNodeID,
            let index,
            let expectedRevision
        ):
            let receipt = try await store.restore(
                nodeID,
                to: destinationParentNodeID,
                at: index,
                expectedRevision: expectedRevision
            )
            return .mutation(Self.mutationOutput(receipt))
        }
    }

    private func readContent(
        nodeID: NodeID,
        byteOffset: UInt64,
        maximumBytes: Int
    ) async throws -> LibraryToolContentOutput {
        guard (4...Self.maximumContentReadBytes).contains(maximumBytes) else {
            throw LibraryToolFailure(code: .invalidArguments, argument: "maximum_bytes")
        }

        let snapshot = try await store.refresh()
        guard let entry = snapshot.entry(nodeID) else {
            throw LibraryStoreError.nodeNotFound(nodeID)
        }

        switch entry.kind {
        case .folder:
            throw LibraryStoreError.kindMismatch(nodeID)

        case .document:
            let document = try await store.readDocument(
                nodeID,
                expectedRevision: snapshot.revision
            )
            return try Self.contentOutput(
                revision: snapshot.revision,
                nodeID: nodeID,
                source: .document,
                mediaType: document.mediaType,
                contentTypeIdentifier: nil,
                completeData: document.data,
                byteOffset: byteOffset,
                maximumBytes: maximumBytes
            )

        case .resourceLink:
            guard let resourceID = entry.externalResource?.resourceID else {
                throw LibraryStoreError.kindMismatch(nodeID)
            }
            let resource = try await store.readExternalResource(
                resourceID,
                expectedRevision: snapshot.revision
            )
            guard resource.kind == .file else {
                throw LibraryToolFailure(code: .unsupportedContent, resourceID: resourceID)
            }
            let chunk = try Self.readExternalFileChunk(
                resource,
                byteOffset: byteOffset,
                maximumBytes: maximumBytes
            )
            return try Self.contentOutput(
                revision: snapshot.revision,
                nodeID: nodeID,
                source: .resourceLink,
                mediaType: nil,
                contentTypeIdentifier: resource.contentTypeIdentifier,
                chunkData: chunk.data,
                byteOffset: byteOffset,
                totalByteCount: chunk.totalByteCount
            )
        }
    }

    private static func toolNode(_ entry: LibraryEntry) -> LibraryToolNode {
        let kind: LibraryToolNodeKind = switch entry.kind {
        case .folder: .folder
        case .document: .document
        case .resourceLink: .resourceLink
        }
        return LibraryToolNode(
            nodeID: entry.id,
            parentNodeID: entry.parentID,
            kind: kind,
            title: entry.title,
            childCount: entry.childIDs.count,
            lastModifiedRevision: entry.lastModifiedRevision,
            resourceID: entry.externalResource?.resourceID,
            mediaType: entry.document?.mediaType,
            byteCount: entry.document?.byteCount,
            isTrashedRoot: entry.isTrashedRoot
        )
    }

    private static func mutationOutput(
        _ receipt: LibraryCommitReceipt,
        primaryNodeID: NodeID? = nil
    ) -> LibraryToolMutationOutput {
        LibraryToolMutationOutput(
            revision: receipt.revision,
            transactionID: receipt.transactionID,
            primaryNodeID: primaryNodeID,
            createdNodeIDs: receipt.createdNodeIDs.sorted(by: nodeIDOrder),
            changedNodeIDs: receipt.changedNodeIDs.sorted(by: nodeIDOrder),
            deletedNodeIDs: receipt.deletedNodeIDs.sorted(by: nodeIDOrder),
            cleanupPending: receipt.cleanupPending
        )
    }

    private static func nodeIDOrder(_ left: NodeID, _ right: NodeID) -> Bool {
        left.description < right.description
    }

    private static func contentOutput(
        revision: UInt64,
        nodeID: NodeID,
        source: LibraryToolContentSource,
        mediaType: String?,
        contentTypeIdentifier: String?,
        completeData: Data,
        byteOffset: UInt64,
        maximumBytes: Int
    ) throws -> LibraryToolContentOutput {
        let totalByteCount = UInt64(completeData.count)
        guard byteOffset <= totalByteCount else {
            throw LibraryToolFailure(code: .invalidArguments, argument: "byte_offset")
        }
        let start = Int(byteOffset)
        let count = min(maximumBytes, completeData.count - start)
        let chunk = completeData.subdata(in: start..<(start + count))
        return try contentOutput(
            revision: revision,
            nodeID: nodeID,
            source: source,
            mediaType: mediaType,
            contentTypeIdentifier: contentTypeIdentifier,
            chunkData: chunk,
            byteOffset: byteOffset,
            totalByteCount: totalByteCount
        )
    }

    private static func contentOutput(
        revision: UInt64,
        nodeID: NodeID,
        source: LibraryToolContentSource,
        mediaType: String?,
        contentTypeIdentifier: String?,
        chunkData: Data,
        byteOffset: UInt64,
        totalByteCount: UInt64
    ) throws -> LibraryToolContentOutput {
        let decoded = try decodedUTF8Prefix(chunkData)
        let next = byteOffset + UInt64(decoded.byteCount)
        let truncated = next < totalByteCount
        return LibraryToolContentOutput(
            revision: revision,
            nodeID: nodeID,
            source: source,
            mediaType: mediaType,
            contentTypeIdentifier: contentTypeIdentifier,
            text: decoded.text,
            byteOffset: byteOffset,
            nextByteOffset: truncated ? next : nil,
            totalByteCount: totalByteCount,
            truncated: truncated
        )
    }

    private static func decodedUTF8Prefix(_ data: Data) throws -> (text: String, byteCount: Int) {
        if data.isEmpty {
            return ("", 0)
        }

        for trimmedByteCount in 0...min(3, data.count - 1) {
            let byteCount = data.count - trimmedByteCount
            let prefix = data.prefix(byteCount)
            if let text = String(data: prefix, encoding: .utf8) {
                return (text, byteCount)
            }
        }
        throw LibraryToolFailure(code: .contentNotUTF8)
    }

    private static func readExternalFileChunk(
        _ resource: StoredExternalResource,
        byteOffset: UInt64,
        maximumBytes: Int
    ) throws -> (data: Data, totalByteCount: UInt64) {
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
            throw LibraryToolFailure(
                code: .resourceUnavailable,
                resourceID: resource.resourceID
            )
        }

        let startedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard (try? url.checkResourceIsReachable()) == true else {
            throw LibraryToolFailure(
                code: .resourceUnavailable,
                resourceID: resource.resourceID
            )
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<(Data, UInt64), Error>?
        coordinator.coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            result = Result {
                let values = try coordinatedURL.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
                )
                guard values.isDirectory != true,
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else {
                    throw LibraryToolFailure(
                        code: .unsupportedContent,
                        resourceID: resource.resourceID
                    )
                }

                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer { try? handle.close() }
                let totalByteCount = try handle.seekToEnd()
                guard byteOffset <= totalByteCount else {
                    throw LibraryToolFailure(
                        code: .invalidArguments,
                        argument: "byte_offset",
                        resourceID: resource.resourceID
                    )
                }
                try handle.seek(toOffset: byteOffset)
                let requestedByteCount = Int(
                    min(UInt64(maximumBytes), totalByteCount - byteOffset)
                )
                let data = try handle.read(upToCount: requestedByteCount) ?? Data()
                guard data.count == requestedByteCount else {
                    throw LibraryToolFailure(
                        code: .resourceUnavailable,
                        resourceID: resource.resourceID
                    )
                }
                return (data, totalByteCount)
            }
        }

        if coordinationError != nil {
            throw LibraryToolFailure(
                code: .resourceUnavailable,
                resourceID: resource.resourceID
            )
        }
        guard let result else {
            throw LibraryToolFailure(
                code: .resourceUnavailable,
                resourceID: resource.resourceID
            )
        }
        do {
            return try result.get()
        } catch let failure as LibraryToolFailure {
            throw failure
        } catch {
            throw LibraryToolFailure(
                code: .resourceUnavailable,
                resourceID: resource.resourceID
            )
        }
    }

    private static func failure(for error: LibraryStoreError) -> LibraryToolFailure {
        switch error {
        case .invalidTitle, .invalidExternalResourceMetadata, .invalidResourceLocator,
             .invalidLinkedTree, .linkedTreeTooLarge:
            return LibraryToolFailure(code: .invalidArguments)
        case .invariantViolation(let reason) where reason == "invalid-child-index":
            return LibraryToolFailure(code: .invalidArguments, argument: "index")
        case .nodeNotFound(let nodeID):
            return LibraryToolFailure(code: .nodeNotFound, nodeID: nodeID)
        case .resourceNotFound(let resourceID):
            return LibraryToolFailure(code: .resourceNotFound, resourceID: resourceID)
        case .parentNotFound(let nodeID):
            return LibraryToolFailure(code: .parentNotFound, nodeID: nodeID)
        case .parentNotFolder(let nodeID):
            return LibraryToolFailure(code: .parentNotFolder, nodeID: nodeID)
        case .kindMismatch(let nodeID):
            return LibraryToolFailure(code: .kindMismatch, nodeID: nodeID)
        case .rootMutationForbidden:
            return LibraryToolFailure(code: .rootMutationForbidden)
        case .cycleDetected:
            return LibraryToolFailure(code: .cycleDetected)
        case .alreadyTrashed(let nodeID):
            return LibraryToolFailure(code: .alreadyTrashed, nodeID: nodeID)
        case .notInTrash(let nodeID):
            return LibraryToolFailure(code: .notInTrash, nodeID: nodeID)
        case .invalidRestoreDestination(let nodeID):
            return LibraryToolFailure(code: .invalidRestoreDestination, nodeID: nodeID)
        case .revisionConflict(let expected, let actual):
            return LibraryToolFailure(
                code: .revisionConflict,
                expectedRevision: expected,
                actualRevision: actual
            )
        case .permissionDenied:
            return LibraryToolFailure(code: .permissionDenied)
        default:
            return LibraryToolFailure(code: .storeFailure)
        }
    }
}
