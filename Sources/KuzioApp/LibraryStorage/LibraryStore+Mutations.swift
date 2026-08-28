import Darwin
import Foundation

extension LibraryStore {
    func createFolder(
        in parentID: NodeID,
        title: String,
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> CreatedLibraryNode {
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(parentID) else {
            throw LibraryStoreError.parentNotFound(parentID)
        }
        guard var parent = graph.nodes[parentID], var folder = parent.folder else {
            throw LibraryStoreError.parentNotFolder(parentID)
        }

        let now = mutationTimestamp()
        let nodeID = NodeID()
        let targetRevision = manifest.revision + 1
        let node = StoredNodeRecord(
            id: nodeID,
            kind: .folder,
            title: normalizedTitle,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: targetRevision,
            folder: StoredFolderRecord(children: []),
            document: nil,
            resourceLink: nil
        )

        let insertionIndex = try resolvedInsertionIndex(index, count: folder.children.count)
        folder.children.insert(nodeID, at: insertionIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = targetRevision

        var nodes = graph.nodes
        nodes[nodeID] = node
        nodes[parentID] = parent
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        let receipt = try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [nodeID],
            changedNodeIDs: [parentID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
        return CreatedLibraryNode(id: nodeID, receipt: receipt)
    }

    func createDocument(
        in parentID: NodeID,
        title: String,
        data: Data,
        mediaType: String = "text/markdown; charset=utf-8",
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> CreatedLibraryNode {
        guard data.count <= LibraryStoreIO.maximumPayloadBytes else {
            throw LibraryStoreError.io(operation: "write", relativePath: "objects", code: Int(EFBIG))
        }
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let normalizedMediaType = try LibraryManifestValidator.normalizeMediaType(mediaType)
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(parentID) else {
            throw LibraryStoreError.parentNotFound(parentID)
        }
        guard var parent = graph.nodes[parentID], var folder = parent.folder else {
            throw LibraryStoreError.parentNotFolder(parentID)
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        let nodeID = NodeID()
        let objectID = ObjectID()
        let payload = StoredPayloadReference(
            objectID: objectID,
            mediaType: normalizedMediaType,
            payloadSchemaVersion: 1,
            byteCount: UInt64(data.count),
            sha256: LibraryStoreIO.sha256Hex(data)
        )
        let node = StoredNodeRecord(
            id: nodeID,
            kind: .document,
            title: normalizedTitle,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: targetRevision,
            folder: nil,
            document: StoredDocumentRecord(contentRevision: 1, payload: payload),
            resourceLink: nil
        )

        let insertionIndex = try resolvedInsertionIndex(index, count: folder.children.count)
        folder.children.insert(nodeID, at: insertionIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = targetRevision

        var nodes = graph.nodes
        nodes[nodeID] = node
        nodes[parentID] = parent
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        let receipt = try commit(
            candidate: candidate,
            newObjects: [objectID: data],
            createdNodeIDs: [nodeID],
            changedNodeIDs: [parentID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
        return CreatedLibraryNode(id: nodeID, receipt: receipt)
    }

    func createExternalResourceLink(
        in parentID: NodeID,
        title: String,
        kind: StoredExternalResourceKind,
        locatorData: Data,
        lastKnownName: String,
        contentTypeIdentifier: String? = nil,
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> CreatedExternalResourceLink {
        try LibraryManifestValidator.validateLocatorData(locatorData, kind: kind)
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let normalizedLastKnownName = try LibraryManifestValidator.normalizeTitle(lastKnownName)
        let normalizedContentTypeIdentifier = try LibraryManifestValidator
            .normalizeContentTypeIdentifier(contentTypeIdentifier)
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(parentID) else {
            throw LibraryStoreError.parentNotFound(parentID)
        }
        guard var parent = graph.nodes[parentID], var folder = parent.folder else {
            throw LibraryStoreError.parentNotFolder(parentID)
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        let nodeID = NodeID()
        let resourceID = ResourceID()
        let locatorObjectID = ObjectID()
        let resource = StoredExternalResourceRecord(
            id: resourceID,
            kind: kind,
            accessMode: .readOnly,
            locator: StoredLocatorReference(
                objectID: locatorObjectID,
                locatorSchemaVersion: 1,
                byteCount: UInt64(locatorData.count),
                sha256: LibraryStoreIO.sha256Hex(locatorData)
            ),
            lastKnownName: normalizedLastKnownName,
            contentTypeIdentifier: normalizedContentTypeIdentifier,
            origin: nil,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: targetRevision
        )
        let node = StoredNodeRecord(
            id: nodeID,
            kind: .resourceLink,
            title: normalizedTitle,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: targetRevision,
            folder: nil,
            document: nil,
            resourceLink: StoredResourceLinkRecord(resourceID: resourceID)
        )

        let insertionIndex = try resolvedInsertionIndex(index, count: folder.children.count)
        folder.children.insert(nodeID, at: insertionIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = targetRevision

        var nodes = graph.nodes
        nodes[nodeID] = node
        nodes[parentID] = parent
        var externalResources = graph.externalResources
        externalResources[resourceID] = resource
        let candidate = candidateManifest(
            nodes: nodes,
            externalResources: externalResources,
            trash: manifest.trash,
            now: now
        )
        let receipt = try commit(
            candidate: candidate,
            newObjects: [locatorObjectID: locatorData],
            createdNodeIDs: [nodeID],
            changedNodeIDs: [parentID],
            deletedNodeIDs: [],
            createdResourceIDs: [resourceID],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
        return CreatedExternalResourceLink(
            nodeID: nodeID,
            resourceID: resourceID,
            receipt: receipt
        )
    }

    func createExternalLinkedTree(
        in parentID: NodeID,
        drafts: [LibraryLinkedItemDraft],
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> CreatedLinkedTree {
        guard !drafts.isEmpty else {
            throw LibraryStoreError.invalidLinkedTree
        }

        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(parentID) else {
            throw LibraryStoreError.parentNotFound(parentID)
        }
        guard var parent = graph.nodes[parentID], var parentFolder = parent.folder else {
            throw LibraryStoreError.parentNotFolder(parentID)
        }
        guard drafts.count <= LibraryManifestValidator.maximumNodeCount - graph.nodes.count else {
            throw LibraryStoreError.linkedTreeTooLarge
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        var nodes = graph.nodes
        var externalResources = graph.externalResources
        var newObjects: [ObjectID: Data] = [:]
        var nodeIDsByDraftIndex: [NodeID] = []
        var kindsByDraftIndex: [StoredNodeKind] = []
        var rootNodeIDs: [NodeID] = []
        var createdResourceIDs: [ResourceID] = []
        nodeIDsByDraftIndex.reserveCapacity(drafts.count)
        kindsByDraftIndex.reserveCapacity(drafts.count)

        for (draftIndex, draft) in drafts.enumerated() {
            try Task.checkCancellation()
            let normalizedTitle = try LibraryManifestValidator.normalizeTitle(draft.title)
            let nodeID = NodeID()
            let node: StoredNodeRecord

            switch draft.kind {
            case .folder:
                node = StoredNodeRecord(
                    id: nodeID,
                    kind: .folder,
                    title: normalizedTitle,
                    createdAtUnixMilliseconds: now,
                    modifiedAtUnixMilliseconds: now,
                    lastModifiedRevision: targetRevision,
                    folder: StoredFolderRecord(children: []),
                    document: nil,
                    resourceLink: nil
                )

            case .file(let file):
                try LibraryManifestValidator.validateLocatorData(file.locatorData, kind: .file)
                let normalizedLastKnownName = try LibraryManifestValidator
                    .normalizeTitle(file.lastKnownName)
                let normalizedContentTypeIdentifier = try LibraryManifestValidator
                    .normalizeContentTypeIdentifier(file.contentTypeIdentifier)
                let storedOrigin = file.origin.map {
                    StoredExternalResourceOrigin(
                        importID: $0.importID,
                        relativePathComponents: $0.relativePathComponents
                    )
                }
                try LibraryManifestValidator.validateOrigin(storedOrigin, kind: .file)
                let resourceID = ResourceID()
                let locatorObjectID = ObjectID()
                let resource = StoredExternalResourceRecord(
                    id: resourceID,
                    kind: .file,
                    accessMode: .readOnly,
                    locator: StoredLocatorReference(
                        objectID: locatorObjectID,
                        locatorSchemaVersion: 1,
                        byteCount: UInt64(file.locatorData.count),
                        sha256: LibraryStoreIO.sha256Hex(file.locatorData)
                    ),
                    lastKnownName: normalizedLastKnownName,
                    contentTypeIdentifier: normalizedContentTypeIdentifier,
                    origin: storedOrigin,
                    createdAtUnixMilliseconds: now,
                    modifiedAtUnixMilliseconds: now,
                    lastModifiedRevision: targetRevision
                )
                externalResources[resourceID] = resource
                newObjects[locatorObjectID] = file.locatorData
                createdResourceIDs.append(resourceID)
                node = StoredNodeRecord(
                    id: nodeID,
                    kind: .resourceLink,
                    title: normalizedTitle,
                    createdAtUnixMilliseconds: now,
                    modifiedAtUnixMilliseconds: now,
                    lastModifiedRevision: targetRevision,
                    folder: nil,
                    document: nil,
                    resourceLink: StoredResourceLinkRecord(resourceID: resourceID)
                )
            }

            nodes[nodeID] = node
            nodeIDsByDraftIndex.append(nodeID)
            kindsByDraftIndex.append(node.kind)

            if let parentDraftIndex = draft.parentDraftIndex {
                guard parentDraftIndex >= 0,
                      parentDraftIndex < draftIndex,
                      kindsByDraftIndex[parentDraftIndex] == .folder else {
                    throw LibraryStoreError.invalidLinkedTree
                }
                let importedParentID = nodeIDsByDraftIndex[parentDraftIndex]
                guard var importedParent = nodes[importedParentID],
                      var importedFolder = importedParent.folder else {
                    throw LibraryStoreError.invalidLinkedTree
                }
                importedFolder.children.append(nodeID)
                importedParent.folder = importedFolder
                importedParent.modifiedAtUnixMilliseconds = now
                importedParent.lastModifiedRevision = targetRevision
                nodes[importedParentID] = importedParent
            } else {
                rootNodeIDs.append(nodeID)
            }
        }

        guard !rootNodeIDs.isEmpty else {
            throw LibraryStoreError.invalidLinkedTree
        }
        let insertionIndex = try resolvedInsertionIndex(index, count: parentFolder.children.count)
        parentFolder.children.insert(contentsOf: rootNodeIDs, at: insertionIndex)
        parent.folder = parentFolder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = targetRevision
        nodes[parentID] = parent

        let candidate = candidateManifest(
            nodes: nodes,
            externalResources: externalResources,
            trash: manifest.trash,
            now: now
        )
        let receipt = try commit(
            candidate: candidate,
            newObjects: newObjects,
            createdNodeIDs: nodeIDsByDraftIndex,
            changedNodeIDs: [parentID],
            deletedNodeIDs: [],
            createdResourceIDs: createdResourceIDs,
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
        return CreatedLinkedTree(rootNodeIDs: rootNodeIDs, receipt: receipt)
    }

    func createResourceAlias(
        to resourceID: ResourceID,
        in parentID: NodeID,
        title: String,
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> CreatedLibraryNode {
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard graph.externalResources[resourceID] != nil else {
            throw LibraryStoreError.resourceNotFound(resourceID)
        }
        guard graph.nodes.values.contains(where: { node in
            active.contains(node.id) && node.resourceLink?.resourceID == resourceID
        }) else {
            throw LibraryStoreError.resourceNotFound(resourceID)
        }
        guard active.contains(parentID) else {
            throw LibraryStoreError.parentNotFound(parentID)
        }
        guard var parent = graph.nodes[parentID], var folder = parent.folder else {
            throw LibraryStoreError.parentNotFolder(parentID)
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        let nodeID = NodeID()
        let node = StoredNodeRecord(
            id: nodeID,
            kind: .resourceLink,
            title: normalizedTitle,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: targetRevision,
            folder: nil,
            document: nil,
            resourceLink: StoredResourceLinkRecord(resourceID: resourceID)
        )

        let insertionIndex = try resolvedInsertionIndex(index, count: folder.children.count)
        folder.children.insert(nodeID, at: insertionIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = targetRevision

        var nodes = graph.nodes
        nodes[nodeID] = node
        nodes[parentID] = parent
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        let receipt = try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [nodeID],
            changedNodeIDs: [parentID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
        return CreatedLibraryNode(id: nodeID, receipt: receipt)
    }

    func replaceExternalResourceLocator(
        for nodeID: NodeID,
        locatorData: Data,
        lastKnownName: String,
        contentTypeIdentifier: String? = nil,
        preservesImportOrigin: Bool = true,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard activeNodeIDs(graph: graph).contains(nodeID) else {
            throw LibraryStoreError.nodeNotFound(nodeID)
        }
        guard let resourceID = graph.nodes[nodeID]?.resourceLink?.resourceID,
              var resource = graph.externalResources[resourceID] else {
            throw LibraryStoreError.kindMismatch(nodeID)
        }
        try LibraryManifestValidator.validateLocatorData(locatorData, kind: resource.kind)
        let normalizedLastKnownName = try LibraryManifestValidator.normalizeTitle(lastKnownName)
        let normalizedContentTypeIdentifier = try LibraryManifestValidator
            .normalizeContentTypeIdentifier(contentTypeIdentifier)

        let locatorObjectID = ObjectID()
        let now = mutationTimestamp()
        resource.locator = StoredLocatorReference(
            objectID: locatorObjectID,
            locatorSchemaVersion: 1,
            byteCount: UInt64(locatorData.count),
            sha256: LibraryStoreIO.sha256Hex(locatorData)
        )
        resource.lastKnownName = normalizedLastKnownName
        resource.contentTypeIdentifier = normalizedContentTypeIdentifier
        if !preservesImportOrigin {
            resource.origin = nil
        }
        resource.modifiedAtUnixMilliseconds = now
        resource.lastModifiedRevision = manifest.revision + 1

        var externalResources = graph.externalResources
        externalResources[resourceID] = resource
        let candidate = candidateManifest(
            nodes: graph.nodes,
            externalResources: externalResources,
            trash: manifest.trash,
            now: now
        )
        return try commit(
            candidate: candidate,
            newObjects: [locatorObjectID: locatorData],
            createdNodeIDs: [],
            changedNodeIDs: [],
            deletedNodeIDs: [],
            changedResourceIDs: [resourceID],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func replaceExternalResourceLocators(
        _ drafts: [LibraryExternalResourceRelinkDraft],
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        guard !drafts.isEmpty,
              Set(drafts.map(\.resourceID)).count == drafts.count,
              Set(drafts.map(\.origin.importID)).count == 1,
              Set(drafts.map(\.origin.relativePathComponents)).count == drafts.count else {
            throw LibraryStoreError.invalidLinkedTree
        }

        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard let importID = drafts.first?.origin.importID else {
            throw LibraryStoreError.invalidLinkedTree
        }
        let existingBatchResourceIDs = Set(graph.externalResources.values.compactMap { resource in
            resource.origin?.importID == importID ? resource.id : nil
        })
        let requestedResourceIDs = Set(drafts.map(\.resourceID))
        guard existingBatchResourceIDs.isEmpty || existingBatchResourceIDs == requestedResourceIDs else {
            throw LibraryStoreError.invalidLinkedTree
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        var externalResources = graph.externalResources
        var newObjects: [ObjectID: Data] = [:]

        for draft in drafts {
            guard var resource = externalResources[draft.resourceID],
                  resource.kind == .file,
                  resource.origin == nil || resource.origin?.importID == importID else {
                throw LibraryStoreError.invalidLinkedTree
            }
            try LibraryManifestValidator.validateLocatorData(draft.locatorData, kind: .file)
            let normalizedLastKnownName = try LibraryManifestValidator
                .normalizeTitle(draft.lastKnownName)
            let normalizedContentTypeIdentifier = try LibraryManifestValidator
                .normalizeContentTypeIdentifier(draft.contentTypeIdentifier)
            let storedOrigin = StoredExternalResourceOrigin(
                importID: draft.origin.importID,
                relativePathComponents: draft.origin.relativePathComponents
            )
            try LibraryManifestValidator.validateOrigin(storedOrigin, kind: .file)

            let locatorObjectID = ObjectID()
            resource.locator = StoredLocatorReference(
                objectID: locatorObjectID,
                locatorSchemaVersion: 1,
                byteCount: UInt64(draft.locatorData.count),
                sha256: LibraryStoreIO.sha256Hex(draft.locatorData)
            )
            resource.lastKnownName = normalizedLastKnownName
            resource.contentTypeIdentifier = normalizedContentTypeIdentifier
            resource.origin = storedOrigin
            resource.modifiedAtUnixMilliseconds = now
            resource.lastModifiedRevision = targetRevision
            externalResources[draft.resourceID] = resource
            newObjects[locatorObjectID] = draft.locatorData
        }

        let candidate = candidateManifest(
            nodes: graph.nodes,
            externalResources: externalResources,
            trash: manifest.trash,
            now: now
        )
        return try commit(
            candidate: candidate,
            newObjects: newObjects,
            createdNodeIDs: [],
            changedNodeIDs: [],
            deletedNodeIDs: [],
            changedResourceIDs: drafts.map(\.resourceID).sorted {
                $0.description < $1.description
            },
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func updateDocument(
        _ nodeID: NodeID,
        data: Data,
        mediaType: String? = nil,
        expectedNodeRevision: UInt64? = nil,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        guard data.count <= LibraryStoreIO.maximumPayloadBytes else {
            throw LibraryStoreError.io(operation: "write", relativePath: "objects", code: Int(EFBIG))
        }
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard var node = graph.nodes[nodeID] else {
            throw LibraryStoreError.nodeNotFound(nodeID)
        }
        guard activeNodeIDs(graph: graph).contains(nodeID) else {
            throw LibraryStoreError.alreadyTrashed(nodeID)
        }
        guard var document = node.document else {
            throw LibraryStoreError.kindMismatch(nodeID)
        }
        if let expectedNodeRevision,
           node.lastModifiedRevision != expectedNodeRevision {
            throw LibraryStoreError.revisionConflict(
                expected: expectedNodeRevision,
                actual: node.lastModifiedRevision
            )
        }

        let objectID = ObjectID()
        let resolvedMediaType = try LibraryManifestValidator.normalizeMediaType(
            mediaType ?? document.payload.mediaType
        )
        document.contentRevision += 1
        document.payload = StoredPayloadReference(
            objectID: objectID,
            mediaType: resolvedMediaType,
            payloadSchemaVersion: 1,
            byteCount: UInt64(data.count),
            sha256: LibraryStoreIO.sha256Hex(data)
        )
        let now = mutationTimestamp()
        node.document = document
        node.modifiedAtUnixMilliseconds = now
        node.lastModifiedRevision = manifest.revision + 1

        var nodes = graph.nodes
        nodes[nodeID] = node
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        return try commit(
            candidate: candidate,
            newObjects: [objectID: data],
            createdNodeIDs: [],
            changedNodeIDs: [nodeID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func rename(
        _ nodeID: NodeID,
        to title: String,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        guard nodeID != manifest.rootNodeID else {
            throw LibraryStoreError.rootMutationForbidden
        }
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard var node = graph.nodes[nodeID] else {
            throw LibraryStoreError.nodeNotFound(nodeID)
        }
        guard activeNodeIDs(graph: graph).contains(nodeID) else {
            throw LibraryStoreError.alreadyTrashed(nodeID)
        }
        let now = mutationTimestamp()
        node.title = normalizedTitle
        node.modifiedAtUnixMilliseconds = now
        node.lastModifiedRevision = manifest.revision + 1

        var nodes = graph.nodes
        nodes[nodeID] = node
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        return try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [],
            changedNodeIDs: [nodeID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func move(
        _ nodeID: NodeID,
        to destinationParentID: NodeID,
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        guard nodeID != manifest.rootNodeID else {
            throw LibraryStoreError.rootMutationForbidden
        }
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(nodeID) else {
            throw LibraryStoreError.nodeNotFound(nodeID)
        }
        guard active.contains(destinationParentID) else {
            throw LibraryStoreError.parentNotFound(destinationParentID)
        }
        guard var destination = graph.nodes[destinationParentID],
              var destinationFolder = destination.folder else {
            throw LibraryStoreError.parentNotFolder(destinationParentID)
        }
        let subtree = subtreeNodeIDs(rootID: nodeID, graph: graph)
        guard !subtree.contains(destinationParentID) else {
            throw LibraryStoreError.cycleDetected
        }
        guard let originalParentID = graph.parentByNodeID[nodeID],
              var originalParent = graph.nodes[originalParentID],
              var originalFolder = originalParent.folder,
              let originalIndex = originalFolder.children.firstIndex(of: nodeID) else {
            throw LibraryStoreError.invariantViolation("missing-active-parent")
        }

        let now = mutationTimestamp()
        let targetRevision = manifest.revision + 1
        originalFolder.children.remove(at: originalIndex)
        originalParent.folder = originalFolder
        originalParent.modifiedAtUnixMilliseconds = now
        originalParent.lastModifiedRevision = targetRevision

        if originalParentID == destinationParentID {
            destination = originalParent
            destinationFolder = originalFolder
        }
        let insertionIndex = try resolvedInsertionIndex(index, count: destinationFolder.children.count)
        destinationFolder.children.insert(nodeID, at: insertionIndex)
        destination.folder = destinationFolder
        destination.modifiedAtUnixMilliseconds = now
        destination.lastModifiedRevision = targetRevision

        var nodes = graph.nodes
        nodes[originalParentID] = originalParentID == destinationParentID ? destination : originalParent
        nodes[destinationParentID] = destination
        if var movedNode = nodes[nodeID] {
            movedNode.modifiedAtUnixMilliseconds = now
            movedNode.lastModifiedRevision = targetRevision
            nodes[nodeID] = movedNode
        }
        let changed = Array(Set([nodeID, originalParentID, destinationParentID]))
        let candidate = candidateManifest(nodes: nodes, trash: manifest.trash, now: now)
        return try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [],
            changedNodeIDs: changed,
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func trash(
        _ nodeID: NodeID,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        guard nodeID != manifest.rootNodeID else {
            throw LibraryStoreError.rootMutationForbidden
        }
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        let active = activeNodeIDs(graph: graph)
        guard active.contains(nodeID) else {
            if graph.trashByRootID[nodeID] != nil {
                throw LibraryStoreError.alreadyTrashed(nodeID)
            }
            throw LibraryStoreError.nodeNotFound(nodeID)
        }
        guard let parentID = graph.parentByNodeID[nodeID],
              var parent = graph.nodes[parentID],
              var folder = parent.folder,
              let childIndex = folder.children.firstIndex(of: nodeID) else {
            throw LibraryStoreError.invariantViolation("missing-active-parent")
        }

        let now = mutationTimestamp()
        folder.children.remove(at: childIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = manifest.revision + 1

        var nodes = graph.nodes
        nodes[parentID] = parent
        if var trashedNode = nodes[nodeID] {
            trashedNode.modifiedAtUnixMilliseconds = now
            trashedNode.lastModifiedRevision = manifest.revision + 1
            nodes[nodeID] = trashedNode
        }
        var trash = manifest.trash
        trash.append(
            StoredTrashRecord(
                rootNodeID: nodeID,
                originalParentID: parentID,
                originalChildIndex: childIndex,
                trashedAtUnixMilliseconds: now
            )
        )
        let candidate = candidateManifest(nodes: nodes, trash: trash, now: now)
        return try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [],
            changedNodeIDs: [parentID, nodeID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func restore(
        _ nodeID: NodeID,
        to destinationParentID: NodeID? = nil,
        at index: Int? = nil,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard let trashRecord = graph.trashByRootID[nodeID] else {
            throw LibraryStoreError.notInTrash(nodeID)
        }
        let active = activeNodeIDs(graph: graph)
        let targetParentID = destinationParentID ?? trashRecord.originalParentID
        guard active.contains(targetParentID),
              var parent = graph.nodes[targetParentID],
              var folder = parent.folder else {
            throw LibraryStoreError.invalidRestoreDestination(targetParentID)
        }

        let insertionIndex: Int
        if let index {
            insertionIndex = try resolvedInsertionIndex(index, count: folder.children.count)
        } else if destinationParentID == nil {
            insertionIndex = min(trashRecord.originalChildIndex, folder.children.count)
        } else {
            insertionIndex = folder.children.count
        }

        let now = mutationTimestamp()
        folder.children.insert(nodeID, at: insertionIndex)
        parent.folder = folder
        parent.modifiedAtUnixMilliseconds = now
        parent.lastModifiedRevision = manifest.revision + 1

        var nodes = graph.nodes
        nodes[targetParentID] = parent
        if var restoredNode = nodes[nodeID] {
            restoredNode.modifiedAtUnixMilliseconds = now
            restoredNode.lastModifiedRevision = manifest.revision + 1
            nodes[nodeID] = restoredNode
        }
        var trash = manifest.trash
        trash.removeAll { $0.rootNodeID == nodeID }
        let candidate = candidateManifest(nodes: nodes, trash: trash, now: now)
        return try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [],
            changedNodeIDs: [targetParentID, nodeID],
            deletedNodeIDs: [],
            invalidatesPreviousManifest: false,
            purgeObjectIDs: []
        )
    }

    func permanentlyDeleteTrashItem(
        _ nodeID: NodeID,
        expectedRevision: UInt64
    ) throws -> LibraryCommitReceipt {
        let graph = try validatedCurrentGraph(expectedRevision: expectedRevision)
        guard graph.trashByRootID[nodeID] != nil else {
            throw LibraryStoreError.notInTrash(nodeID)
        }

        let deletedIDs = subtreeNodeIDs(rootID: nodeID, graph: graph)
        var objectIDs = deletedIDs.compactMap { graph.nodes[$0]?.document?.payload.objectID }
        var nodes = graph.nodes
        for id in deletedIDs {
            nodes.removeValue(forKey: id)
        }

        let remainingResourceIDs = Set(nodes.values.compactMap { $0.resourceLink?.resourceID })
        let deletedResourceIDs = Set(graph.externalResources.keys).subtracting(remainingResourceIDs)
        var externalResources = graph.externalResources
        for resourceID in deletedResourceIDs {
            if let resource = externalResources.removeValue(forKey: resourceID) {
                objectIDs.append(resource.locator.objectID)
            }
        }
        var trash = manifest.trash
        trash.removeAll { $0.rootNodeID == nodeID }
        let now = mutationTimestamp()
        let candidate = candidateManifest(
            nodes: nodes,
            externalResources: externalResources,
            trash: trash,
            now: now
        )
        return try commit(
            candidate: candidate,
            newObjects: [:],
            createdNodeIDs: [],
            changedNodeIDs: [],
            deletedNodeIDs: Array(deletedIDs),
            deletedResourceIDs: Array(deletedResourceIDs),
            invalidatesPreviousManifest: true,
            purgeObjectIDs: objectIDs
        )
    }

    func collectGarbage() throws -> Int {
        try coordinatedCollectGarbage()
    }

    private func validatedCurrentGraph(expectedRevision: UInt64) throws -> ValidatedLibraryGraph {
        guard manifest.revision == expectedRevision else {
            throw LibraryStoreError.revisionConflict(
                expected: expectedRevision,
                actual: manifest.revision
            )
        }
        return try LibraryManifestValidator.validate(
            manifest,
            paths: paths,
            validatesPayloadFiles: false
        )
    }

    private func candidateManifest(
        nodes: [NodeID: StoredNodeRecord],
        externalResources: [ResourceID: StoredExternalResourceRecord]? = nil,
        trash: [StoredTrashRecord],
        now: Int64
    ) -> LibraryManifestV2 {
        var candidate = manifest
        candidate.revision += 1
        candidate.modifiedAtUnixMilliseconds = now
        candidate.nodes = nodes.values.sorted { $0.id.description < $1.id.description }
        if let externalResources {
            candidate.externalResources = externalResources.values.sorted {
                $0.id.description < $1.id.description
            }
        }
        candidate.trash = trash.sorted { $0.rootNodeID.description < $1.rootNodeID.description }
        return candidate
    }

    private func resolvedInsertionIndex(_ index: Int?, count: Int) throws -> Int {
        guard let index else {
            return count
        }
        guard (0...count).contains(index) else {
            throw LibraryStoreError.invariantViolation("invalid-child-index")
        }
        return index
    }

    private func activeNodeIDs(graph: ValidatedLibraryGraph) -> Set<NodeID> {
        var result: Set<NodeID> = []
        var stack = [manifest.rootNodeID]
        while let id = stack.popLast() {
            guard result.insert(id).inserted, let node = graph.nodes[id] else {
                continue
            }
            stack.append(contentsOf: node.folder?.children ?? [])
        }
        return result
    }

    private func subtreeNodeIDs(
        rootID: NodeID,
        graph: ValidatedLibraryGraph
    ) -> Set<NodeID> {
        var result: Set<NodeID> = []
        var stack = [rootID]
        while let id = stack.popLast() {
            guard result.insert(id).inserted, let node = graph.nodes[id] else {
                continue
            }
            stack.append(contentsOf: node.folder?.children ?? [])
        }
        return result
    }

    private func mutationTimestamp() -> Int64 {
        max(LibraryClock.nowUnixMilliseconds(), manifest.modifiedAtUnixMilliseconds)
    }
}
