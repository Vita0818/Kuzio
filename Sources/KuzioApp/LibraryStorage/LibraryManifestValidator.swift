import Foundation

struct ValidatedLibraryGraph: Sendable {
    let nodes: [NodeID: StoredNodeRecord]
    let parentByNodeID: [NodeID: NodeID]
    let trashByRootID: [NodeID: StoredTrashRecord]
    let externalResources: [ResourceID: StoredExternalResourceRecord]
}

enum LibraryManifestValidator {
    static let maximumNodeCount = 100_000
    static let maximumTitleUTF8Bytes = 1_024
    static let maximumContentTypeIdentifierUTF8Bytes = 255
    static let maximumOriginPathComponentCount = 1_024
    static let maximumOriginPathUTF8Bytes = 32 * 1_024

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

    static func normalizeContentTypeIdentifier(_ rawValue: String?) throws -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= maximumContentTypeIdentifierUTF8Bytes,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw LibraryStoreError.invalidExternalResourceMetadata
        }
        return value
    }

    static func validateLocatorData(
        _ data: Data,
        kind: StoredExternalResourceKind
    ) throws {
        guard !data.isEmpty, data.count <= LibraryStoreIO.maximumLocatorBytes else {
            throw LibraryStoreError.invalidResourceLocator
        }

        guard kind == .https else { return }
        guard let value = String(data: data, encoding: .utf8),
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil else {
            throw LibraryStoreError.invalidResourceLocator
        }
    }

    static func validateOrigin(
        _ origin: StoredExternalResourceOrigin?,
        kind: StoredExternalResourceKind
    ) throws {
        guard let origin else { return }
        guard kind == .file,
              !origin.relativePathComponents.isEmpty,
              origin.relativePathComponents.count <= maximumOriginPathComponentCount else {
            throw LibraryStoreError.invalidExternalResourceMetadata
        }

        var byteCount = 0
        for component in origin.relativePathComponents {
            guard component != ".",
                  component != "..",
                  !component.contains("/"),
                  try normalizeTitle(component) == component else {
                throw LibraryStoreError.invalidExternalResourceMetadata
            }
            byteCount += component.utf8.count
            guard byteCount <= maximumOriginPathUTF8Bytes else {
                throw LibraryStoreError.invalidExternalResourceMetadata
            }
        }
    }

    static func validate(
        _ decoded: DecodedLibraryManifest,
        paths: LibraryPackagePaths,
        validatesPayloadFiles: Bool
    ) throws -> ValidatedLibraryGraph {
        switch decoded {
        case .v1(let manifest):
            return try validateLegacy(
                manifest,
                paths: paths,
                validatesPayloadFiles: validatesPayloadFiles
            )
        case .v2(let manifest):
            return try validate(
                manifest,
                paths: paths,
                validatesPayloadFiles: validatesPayloadFiles
            )
        }
    }

    static func validateLegacy(
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
        return try validate(
            LibraryManifestV2(projecting: manifest),
            paths: paths,
            validatesPayloadFiles: validatesPayloadFiles
        )
    }

    static func validate(
        _ manifest: LibraryManifestV2,
        paths: LibraryPackagePaths,
        validatesPayloadFiles: Bool
    ) throws -> ValidatedLibraryGraph {
        guard manifest.formatIdentifier == LibraryManifestV2.formatIdentifier else {
            throw LibraryStoreError.unsupportedFormat
        }
        guard manifest.layoutVersion == LibraryManifestV2.layoutVersion else {
            throw LibraryStoreError.unsupportedLayoutVersion(manifest.layoutVersion)
        }
        guard manifest.schemaVersion == LibraryManifestV2.schemaVersion else {
            throw LibraryStoreError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.revision > 0,
              manifest.createdAtUnixMilliseconds <= manifest.modifiedAtUnixMilliseconds,
              !manifest.nodes.isEmpty,
              manifest.nodes.count <= maximumNodeCount,
              manifest.externalResources.count <= manifest.nodes.count else {
            throw LibraryStoreError.invariantViolation("manifest-resource-bound")
        }

        var nodes: [NodeID: StoredNodeRecord] = [:]
        nodes.reserveCapacity(manifest.nodes.count)
        var linkedResourceIDs: [ResourceID] = []
        var seenObjectIDs: Set<ObjectID> = []

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
                guard node.folder != nil,
                      node.document == nil,
                      node.resourceLink == nil else {
                    throw LibraryStoreError.invariantViolation("folder-shape")
                }
                if let children = node.folder?.children,
                   Set(children).count != children.count {
                    throw LibraryStoreError.invariantViolation("duplicate-child")
                }
            case .document:
                guard node.folder == nil,
                      node.document != nil,
                      node.resourceLink == nil else {
                    throw LibraryStoreError.invariantViolation("document-shape")
                }
                guard let document = node.document,
                      document.contentRevision > 0,
                      document.payload.payloadSchemaVersion == 1,
                      document.payload.byteCount <= UInt64(LibraryStoreIO.maximumPayloadBytes),
                      try normalizeMediaType(document.payload.mediaType) == document.payload.mediaType,
                      isCanonicalSHA256(document.payload.sha256),
                      seenObjectIDs.insert(document.payload.objectID).inserted else {
                    throw LibraryStoreError.invariantViolation("invalid-document-record")
                }
            case .resourceLink:
                guard node.folder == nil,
                      node.document == nil,
                      let resourceLink = node.resourceLink else {
                    throw LibraryStoreError.invariantViolation("resource-link-shape")
                }
                linkedResourceIDs.append(resourceLink.resourceID)
            }
            nodes[node.id] = node
        }

        guard let root = nodes[manifest.rootNodeID], root.kind == .folder else {
            throw LibraryStoreError.invariantViolation("missing-root-folder")
        }

        var externalResources: [ResourceID: StoredExternalResourceRecord] = [:]
        externalResources.reserveCapacity(manifest.externalResources.count)
        for resource in manifest.externalResources {
            guard externalResources[resource.id] == nil else {
                throw LibraryStoreError.invariantViolation("duplicate-resource-id")
            }
            guard try normalizeTitle(resource.lastKnownName) == resource.lastKnownName,
                  try normalizeContentTypeIdentifier(resource.contentTypeIdentifier)
                    == resource.contentTypeIdentifier,
                  resource.createdAtUnixMilliseconds <= resource.modifiedAtUnixMilliseconds,
                  resource.lastModifiedRevision > 0,
                  resource.lastModifiedRevision <= manifest.revision,
                  resource.locator.locatorSchemaVersion == 1,
                  resource.locator.byteCount > 0,
                  resource.locator.byteCount <= UInt64(LibraryStoreIO.maximumLocatorBytes),
                  isCanonicalSHA256(resource.locator.sha256),
                  seenObjectIDs.insert(resource.locator.objectID).inserted else {
                throw LibraryStoreError.invariantViolation("invalid-external-resource-record")
            }
            do {
                try validateOrigin(resource.origin, kind: resource.kind)
            } catch {
                throw LibraryStoreError.invariantViolation("invalid-external-resource-origin")
            }
            externalResources[resource.id] = resource
        }

        let referencedResourceIDs = Set(linkedResourceIDs)
        guard referencedResourceIDs == Set(externalResources.keys) else {
            throw LibraryStoreError.invariantViolation("missing-or-orphan-external-resource")
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
            for node in nodes.values where node.kind == .document {
                guard let payload = node.document?.payload else {
                    throw LibraryStoreError.invariantViolation("document-shape")
                }
                _ = try validateObjectFile(
                    objectID: payload.objectID,
                    byteCount: payload.byteCount,
                    maximumBytes: LibraryStoreIO.maximumPayloadBytes,
                    expectedDigest: nil,
                    paths: paths
                )
            }

            for resource in externalResources.values {
                let data = try validateObjectFile(
                    objectID: resource.locator.objectID,
                    byteCount: resource.locator.byteCount,
                    maximumBytes: LibraryStoreIO.maximumLocatorBytes,
                    expectedDigest: resource.locator.sha256,
                    paths: paths
                )
                try validateLocatorData(data, kind: resource.kind)
            }
        }

        return ValidatedLibraryGraph(
            nodes: nodes,
            parentByNodeID: parentByNodeID,
            trashByRootID: trashByRootID,
            externalResources: externalResources
        )
    }

    static func snapshot(
        manifest: LibraryManifestV2,
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
            let externalResourceMetadata = node.resourceLink.flatMap { link in
                graph.externalResources[link.resourceID].map { resource in
                    LibraryExternalResourceMetadata(
                        resourceID: resource.id,
                        kind: externalResourceKind(resource.kind),
                        lastKnownName: resource.lastKnownName,
                        contentTypeIdentifier: resource.contentTypeIdentifier,
                        locatorByteCount: resource.locator.byteCount,
                        origin: resource.origin.map {
                            LibraryExternalResourceOrigin(
                                importID: $0.importID,
                                relativePathComponents: $0.relativePathComponents
                            )
                        }
                    )
                }
            }
            let entryKind: LibraryEntryKind
            switch node.kind {
            case .folder: entryKind = .folder
            case .document: entryKind = .document
            case .resourceLink: entryKind = .resourceLink
            }
            let resource = node.resourceLink.flatMap { graph.externalResources[$0.resourceID] }
            let effectiveModifiedMilliseconds = max(
                node.modifiedAtUnixMilliseconds,
                resource?.modifiedAtUnixMilliseconds ?? node.modifiedAtUnixMilliseconds
            )
            let effectiveLastModifiedRevision = max(
                node.lastModifiedRevision,
                resource?.lastModifiedRevision ?? node.lastModifiedRevision
            )
            entries[node.id] = LibraryEntry(
                id: node.id,
                parentID: graph.parentByNodeID[node.id],
                kind: entryKind,
                title: node.title,
                childIDs: node.folder?.children ?? [],
                createdAt: LibraryClock.date(fromUnixMilliseconds: node.createdAtUnixMilliseconds),
                modifiedAt: LibraryClock.date(fromUnixMilliseconds: effectiveModifiedMilliseconds),
                lastModifiedRevision: effectiveLastModifiedRevision,
                document: documentMetadata,
                externalResource: externalResourceMetadata,
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

    private static func externalResourceKind(
        _ kind: StoredExternalResourceKind
    ) -> LibraryExternalResourceKind {
        switch kind {
        case .file: .file
        case .directory: .directory
        case .https: .https
        }
    }

    private static func isCanonicalSHA256(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private static func validateObjectFile(
        objectID: ObjectID,
        byteCount: UInt64,
        maximumBytes: Int,
        expectedDigest: String?,
        paths: LibraryPackagePaths
    ) throws -> Data {
        let objectURL = try paths.objectURL(for: objectID, createShard: false)
        guard FileManager.default.fileExists(atPath: objectURL.path) else {
            throw LibraryStoreError.missingObject(objectID)
        }
        try paths.validateObjectFile(objectURL, objectID: objectID)

        let attributes = try FileManager.default.attributesOfItem(atPath: objectURL.path)
        guard let size = attributes[.size] as? NSNumber,
              size.uint64Value == byteCount else {
            throw LibraryStoreError.objectSizeMismatch(objectID)
        }

        guard let expectedDigest else { return Data() }
        let data = try LibraryStoreIO.readData(
            from: objectURL,
            relativePath: paths.relativePath(for: objectURL),
            maximumBytes: maximumBytes
        )
        guard LibraryStoreIO.sha256Hex(data) == expectedDigest else {
            throw LibraryStoreError.objectDigestMismatch(objectID)
        }
        return data
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
