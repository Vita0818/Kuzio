import Foundation

struct ValidatedLibraryGraph: Sendable {
    let nodes: [NodeID: StoredNodeRecord]
    let parentByNodeID: [NodeID: NodeID]
    let trashByRootID: [NodeID: StoredTrashRecord]
}

enum LibraryManifestValidator {
    static let maximumNodeCount = 100_000
    static let maximumTitleUTF8Bytes = 1_024

    static func normalizeTitle(_ rawTitle: String) throws -> String {
        let title = rawTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping

        guard !title.isEmpty,
              title.utf8.count <= maximumTitleUTF8Bytes,
              !title.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw LibraryStoreError.invalidTitle
        }
        return title
    }

    static func normalizeMediaType(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty,
              value.utf8.count <= 255,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw LibraryStoreError.invariantViolation("invalid-media-type")
        }
        return value
    }

    static func validate(
        _ manifest: LibraryManifestV1,
        paths: LibraryPackagePaths,
        validatesPayloadFiles: Bool
    ) throws -> ValidatedLibraryGraph {
        guard manifest.formatIdentifier == LibraryManifestV1.formatIdentifier else {
            throw LibraryStoreError.unsupportedFormat
        }
        guard manifest.layoutVersion == LibraryManifestV1.layoutVersion else {
            throw LibraryStoreError.unsupportedLayoutVersion(manifest.layoutVersion)
        }
        guard manifest.schemaVersion == LibraryManifestV1.schemaVersion else {
            throw LibraryStoreError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.revision > 0,
              manifest.createdAtUnixMilliseconds <= manifest.modifiedAtUnixMilliseconds,
              !manifest.nodes.isEmpty,
              manifest.nodes.count <= maximumNodeCount else {
            throw LibraryStoreError.invariantViolation("manifest-resource-bound")
        }

        var nodes: [NodeID: StoredNodeRecord] = [:]
        nodes.reserveCapacity(manifest.nodes.count)

        for node in manifest.nodes {
            guard nodes[node.id] == nil else {
                throw LibraryStoreError.invariantViolation("duplicate-node-id")
            }
            guard try normalizeTitle(node.title) == node.title else {
                throw LibraryStoreError.invariantViolation("noncanonical-title")
            }
            guard node.createdAtUnixMilliseconds <= node.modifiedAtUnixMilliseconds,
                  node.lastModifiedRevision > 0,
                  node.lastModifiedRevision <= manifest.revision else {
                throw LibraryStoreError.invariantViolation("invalid-node-version")
            }

            switch node.kind {
            case .folder:
                guard node.folder != nil, node.document == nil else {
                    throw LibraryStoreError.invariantViolation("folder-shape")
                }
                if let children = node.folder?.children,
                   Set(children).count != children.count {
                    throw LibraryStoreError.invariantViolation("duplicate-child")
                }
            case .document:
                guard node.folder == nil, node.document != nil else {
                    throw LibraryStoreError.invariantViolation("document-shape")
                }
                guard let document = node.document,
                      document.contentRevision > 0,
                      document.payload.payloadSchemaVersion == 1,
                      document.payload.byteCount <= UInt64(LibraryStoreIO.maximumPayloadBytes),
                      try normalizeMediaType(document.payload.mediaType) == document.payload.mediaType,
                      document.payload.sha256.count == 64,
                      document.payload.sha256.utf8.allSatisfy({ byte in
                          (48...57).contains(byte) || (97...102).contains(byte)
                      }) else {
                    throw LibraryStoreError.invariantViolation("invalid-document-record")
                }
            }
            nodes[node.id] = node
        }

        guard let root = nodes[manifest.rootNodeID], root.kind == .folder else {
            throw LibraryStoreError.invariantViolation("missing-root-folder")
        }

        var trashByRootID: [NodeID: StoredTrashRecord] = [:]
        for record in manifest.trash {
            guard record.rootNodeID != manifest.rootNodeID,
                  let trashedRoot = nodes[record.rootNodeID],
                  trashByRootID[record.rootNodeID] == nil,
                  record.originalChildIndex >= 0,
                  record.trashedAtUnixMilliseconds >= trashedRoot.createdAtUnixMilliseconds,
                  record.trashedAtUnixMilliseconds <= manifest.modifiedAtUnixMilliseconds else {
                throw LibraryStoreError.invariantViolation("invalid-trash-root")
            }
            trashByRootID[record.rootNodeID] = record
        }

        var ownership: [NodeID: String] = [:]
        var parentByNodeID: [NodeID: NodeID] = [:]
        try traverse(
            rootID: manifest.rootNodeID,
            owner: "active",
            nodes: nodes,
            ownership: &ownership,
            parentByNodeID: &parentByNodeID
        )

        for trashRootID in trashByRootID.keys.sorted(by: { $0.description < $1.description }) {
            try traverse(
                rootID: trashRootID,
                owner: "trash:\(trashRootID.description)",
                nodes: nodes,
                ownership: &ownership,
                parentByNodeID: &parentByNodeID
            )
        }

        guard ownership.count == nodes.count else {
            throw LibraryStoreError.invariantViolation("orphan-node")
        }

        if validatesPayloadFiles {
            var seenObjectIDs: Set<ObjectID> = []
            for node in nodes.values where node.kind == .document {
                guard let payload = node.document?.payload,
                      seenObjectIDs.insert(payload.objectID).inserted else {
                    throw LibraryStoreError.invariantViolation("duplicate-payload-reference")
                }

                let objectURL = try paths.objectURL(for: payload.objectID, createShard: false)

                guard FileManager.default.fileExists(atPath: objectURL.path) else {
                    throw LibraryStoreError.missingObject(payload.objectID)
                }
                try paths.validateObjectFile(objectURL, objectID: payload.objectID)

                let attributes = try FileManager.default.attributesOfItem(atPath: objectURL.path)
                guard let size = attributes[.size] as? NSNumber,
                      size.uint64Value == payload.byteCount else {
                    throw LibraryStoreError.objectSizeMismatch(payload.objectID)
                }
            }
        }

        return ValidatedLibraryGraph(
            nodes: nodes,
            parentByNodeID: parentByNodeID,
            trashByRootID: trashByRootID
        )
    }

    static func snapshot(
        manifest: LibraryManifestV1,
        graph: ValidatedLibraryGraph
    ) -> LibrarySnapshot {
        let trashRootIDs = Set(graph.trashByRootID.keys)
        var entries: [NodeID: LibraryEntry] = [:]
        entries.reserveCapacity(graph.nodes.count)

        for node in graph.nodes.values {
            let documentMetadata = node.document.map {
                LibraryDocumentMetadata(
                    mediaType: $0.payload.mediaType,
                    byteCount: $0.payload.byteCount,
                    contentRevision: $0.contentRevision
                )
            }
            entries[node.id] = LibraryEntry(
                id: node.id,
                parentID: graph.parentByNodeID[node.id],
                kind: node.kind == .folder ? .folder : .document,
                title: node.title,
                childIDs: node.folder?.children ?? [],
                createdAt: LibraryClock.date(fromUnixMilliseconds: node.createdAtUnixMilliseconds),
                modifiedAt: LibraryClock.date(fromUnixMilliseconds: node.modifiedAtUnixMilliseconds),
                lastModifiedRevision: node.lastModifiedRevision,
                document: documentMetadata,
                isTrashedRoot: trashRootIDs.contains(node.id)
            )
        }

        let trashItems = manifest.trash.compactMap { record -> LibraryTrashItem? in
            guard let entry = entries[record.rootNodeID] else {
                return nil
            }
            return LibraryTrashItem(
                id: entry.id,
                title: entry.title,
                kind: entry.kind,
                trashedAt: LibraryClock.date(fromUnixMilliseconds: record.trashedAtUnixMilliseconds)
            )
        }
        .sorted { left, right in
            if left.trashedAt != right.trashedAt {
                return left.trashedAt > right.trashedAt
            }
            return left.title.localizedStandardCompare(right.title) == .orderedAscending
        }

        return LibrarySnapshot(
            libraryID: manifest.libraryID,
            revision: manifest.revision,
            rootNodeID: manifest.rootNodeID,
            entries: entries,
            trashItems: trashItems
        )
    }

    private static func traverse(
        rootID: NodeID,
        owner: String,
        nodes: [NodeID: StoredNodeRecord],
        ownership: inout [NodeID: String],
        parentByNodeID: inout [NodeID: NodeID]
    ) throws {
        var stack: [(id: NodeID, parent: NodeID?, ancestors: Set<NodeID>)] = [
            (rootID, nil, []),
        ]

        while let current = stack.popLast() {
            if current.ancestors.contains(current.id) {
                throw LibraryStoreError.cycleDetected
            }
            guard let node = nodes[current.id] else {
                throw LibraryStoreError.invariantViolation("dangling-child")
            }
            guard ownership[current.id] == nil else {
                throw LibraryStoreError.invariantViolation("multiple-parents-or-overlap")
            }

            ownership[current.id] = owner
            if let parent = current.parent {
                parentByNodeID[current.id] = parent
            }

            guard let children = node.folder?.children else {
                continue
            }

            var ancestors = current.ancestors
            ancestors.insert(current.id)
            for childID in children.reversed() {
                stack.append((childID, current.id, ancestors))
            }
        }
    }
}
