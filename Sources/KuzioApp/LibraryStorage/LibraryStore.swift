import Foundation

actor LibraryStore {
    let paths: LibraryPackagePaths
    var manifest: LibraryManifestV2
    let coordinator = NSFileCoordinator(filePresenter: nil)

    private init(paths: LibraryPackagePaths, manifest: LibraryManifestV2) {
        self.paths = paths
        self.manifest = manifest
    }

    static func create(at rootURL: URL, title: String) async throws -> LibraryStore {
        let normalizedTitle = try LibraryManifestValidator.normalizeTitle(title)
        let paths = try LibraryPackagePaths.create(at: rootURL)
        let now = LibraryClock.nowUnixMilliseconds()
        let rootID = NodeID()
        let rootNode = StoredNodeRecord(
            id: rootID,
            kind: .folder,
            title: normalizedTitle,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            lastModifiedRevision: 1,
            folder: StoredFolderRecord(children: []),
            document: nil,
            resourceLink: nil
        )
        let manifest = LibraryManifestV2(
            formatIdentifier: LibraryManifestV2.formatIdentifier,
            layoutVersion: LibraryManifestV2.layoutVersion,
            schemaVersion: LibraryManifestV2.schemaVersion,
            libraryID: LibraryID(),
            revision: 1,
            lastTransactionID: nil,
            rootNodeID: rootID,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            nodes: [rootNode],
            externalResources: [],
            trash: []
        )

        _ = try LibraryManifestValidator.validate(
            manifest,
            paths: paths,
            validatesPayloadFiles: true
        )
        let data = try LibraryStoreIO.encoder().encode(manifest)
        try LibraryStoreIO.atomicReplace(
            data,
            at: paths.manifest,
            relativePath: "manifest.json"
        )
        try paths.validateManifestExists()
        return LibraryStore(paths: paths, manifest: manifest)
    }

    static func open(at rootURL: URL) async throws -> LibraryStore {
        let paths = try LibraryPackagePaths(existingRoot: rootURL)
        let decoded: DecodedLibraryManifest

        do {
            try paths.validateManifestExists()
            decoded = try readManifest(paths: paths, url: paths.manifest)
            _ = try LibraryManifestValidator.validate(
                decoded,
                paths: paths,
                validatesPayloadFiles: true
            )
        } catch let error as LibraryStoreError {
            if hasValidPreviousManifest(paths: paths) {
                throw LibraryStoreError.recoveryRequired
            }
            throw error
        }

        let store: LibraryStore
        switch decoded {
        case .v2(let manifest):
            store = LibraryStore(paths: paths, manifest: manifest)
        case .v1(let legacy):
            store = try await migrateLegacyManifest(legacy, paths: paths)
        }

        try await store.completePublishedPurgeIntents()
        return store
    }

    static func recoverPreviousManifest(at rootURL: URL) async throws -> LibraryStore {
        let paths = try LibraryPackagePaths(existingRoot: rootURL)
        guard FileManager.default.fileExists(atPath: paths.previousManifest.path) else {
            throw LibraryStoreError.recoveryFailed
        }
        try LibraryPackagePaths.validateRegularFile(
            paths.previousManifest,
            relativePath: ".state/previous-manifest.json",
            fileManager: .default
        )
        let previous = try readManifest(paths: paths, url: paths.previousManifest)
        _ = try LibraryManifestValidator.validate(
            previous,
            paths: paths,
            validatesPayloadFiles: true
        )
        let data = try encodedManifest(previous)
        try LibraryStoreIO.atomicReplace(
            data,
            at: paths.manifest,
            relativePath: "manifest.json"
        )
        return try await open(at: rootURL)
    }

    func snapshot() throws -> LibrarySnapshot {
        let graph = try LibraryManifestValidator.validate(
            manifest,
            paths: paths,
            validatesPayloadFiles: false
        )
        return LibraryManifestValidator.snapshot(manifest: manifest, graph: graph)
    }

    func refresh() throws -> LibrarySnapshot {
        let state = try coordinatedReadState(validatesPayloadFiles: true)
        manifest = state.manifest
        return LibraryManifestValidator.snapshot(
            manifest: state.manifest,
            graph: state.graph
        )
    }

    func readDocument(
        _ nodeID: NodeID,
        expectedRevision: UInt64? = nil
    ) throws -> StoredDocument {
        var coordinationError: NSError?
        var coordinatedResult: Result<(LibraryManifestV2, StoredDocument), Error>?

        coordinator.coordinate(
            readingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readCurrentManifest(paths: paths)
                let graph = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: false
                )
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                if let expectedRevision, current.revision != expectedRevision {
                    throw LibraryStoreError.revisionConflict(
                        expected: expectedRevision,
                        actual: current.revision
                    )
                }
                guard let node = graph.nodes[nodeID] else {
                    throw LibraryStoreError.nodeNotFound(nodeID)
                }
                guard node.kind == .document, let document = node.document else {
                    throw LibraryStoreError.kindMismatch(nodeID)
                }

                let data = try Self.readObject(
                    document.payload.objectID,
                    byteCount: document.payload.byteCount,
                    expectedDigest: document.payload.sha256,
                    maximumBytes: LibraryStoreIO.maximumPayloadBytes,
                    paths: paths
                )

                return (
                    current,
                    StoredDocument(
                        nodeID: nodeID,
                        title: node.title,
                        data: data,
                        mediaType: document.payload.mediaType,
                        contentRevision: document.contentRevision,
                        modifiedAt: LibraryClock.date(
                            fromUnixMilliseconds: node.modifiedAtUnixMilliseconds
                        )
                    )
                )
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let coordinatedResult else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        let (current, document) = try coordinatedResult.get()
        manifest = current
        return document
    }

    func readExternalResource(
        _ resourceID: ResourceID,
        expectedRevision: UInt64? = nil
    ) throws -> StoredExternalResource {
        var coordinationError: NSError?
        var coordinatedResult: Result<(LibraryManifestV2, StoredExternalResource), Error>?

        coordinator.coordinate(
            readingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readCurrentManifest(paths: paths)
                let graph = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: false
                )
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                if let expectedRevision, current.revision != expectedRevision {
                    throw LibraryStoreError.revisionConflict(
                        expected: expectedRevision,
                        actual: current.revision
                    )
                }
                guard let resource = graph.externalResources[resourceID] else {
                    throw LibraryStoreError.resourceNotFound(resourceID)
                }

                let data = try Self.readObject(
                    resource.locator.objectID,
                    byteCount: resource.locator.byteCount,
                    expectedDigest: resource.locator.sha256,
                    maximumBytes: LibraryStoreIO.maximumLocatorBytes,
                    paths: paths
                )
                try LibraryManifestValidator.validateLocatorData(data, kind: resource.kind)

                return (
                    current,
                    StoredExternalResource(
                        resourceID: resource.id,
                        kind: Self.externalResourceKind(resource.kind),
                        locatorData: data,
                        lastKnownName: resource.lastKnownName,
                        contentTypeIdentifier: resource.contentTypeIdentifier,
                        origin: resource.origin.map {
                            LibraryExternalResourceOrigin(
                                importID: $0.importID,
                                relativePathComponents: $0.relativePathComponents
                            )
                        },
                        modifiedAt: LibraryClock.date(
                            fromUnixMilliseconds: resource.modifiedAtUnixMilliseconds
                        )
                    )
                )
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let coordinatedResult else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        let (current, resource) = try coordinatedResult.get()
        manifest = current
        return resource
    }

    private func coordinatedReadState(
        validatesPayloadFiles: Bool
    ) throws -> (manifest: LibraryManifestV2, graph: ValidatedLibraryGraph) {
        var coordinationError: NSError?
        var result: Result<(LibraryManifestV2, ValidatedLibraryGraph), Error>?

        coordinator.coordinate(
            readingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            result = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readCurrentManifest(paths: paths)
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                let graph = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: validatesPayloadFiles
                )
                return (current, graph)
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let result else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        return try result.get()
    }

    static func readManifest(
        paths: LibraryPackagePaths,
        url: URL
    ) throws -> DecodedLibraryManifest {
        let relativePath = paths.relativePath(for: url)
        let data = try LibraryStoreIO.readData(
            from: url,
            relativePath: relativePath,
            maximumBytes: LibraryStoreIO.maximumManifestBytes
        )

        let header: LibraryManifestHeader
        do {
            header = try LibraryStoreIO.decoder().decode(LibraryManifestHeader.self, from: data)
        } catch {
            throw LibraryStoreError.malformedManifest
        }
        guard header.formatIdentifier == LibraryManifestV2.formatIdentifier else {
            throw LibraryStoreError.unsupportedFormat
        }
        guard header.layoutVersion == LibraryManifestV2.layoutVersion else {
            throw LibraryStoreError.unsupportedLayoutVersion(header.layoutVersion)
        }

        do {
            switch header.schemaVersion {
            case LibraryManifestV1.schemaVersion:
                return .v1(try LibraryStoreIO.decoder().decode(LibraryManifestV1.self, from: data))
            case LibraryManifestV2.schemaVersion:
                return .v2(try LibraryStoreIO.decoder().decode(LibraryManifestV2.self, from: data))
            default:
                throw LibraryStoreError.unsupportedSchema(header.schemaVersion)
            }
        } catch let error as LibraryStoreError {
            throw error
        } catch {
            throw LibraryStoreError.malformedManifest
        }
    }

    static func readCurrentManifest(paths: LibraryPackagePaths) throws -> LibraryManifestV2 {
        switch try readManifest(paths: paths, url: paths.manifest) {
        case .v2(let manifest):
            return manifest
        case .v1:
            throw LibraryStoreError.unsupportedSchema(LibraryManifestV1.schemaVersion)
        }
    }

    static func encodedManifest(_ decoded: DecodedLibraryManifest) throws -> Data {
        switch decoded {
        case .v1(let manifest):
            return try LibraryStoreIO.encoder().encode(manifest)
        case .v2(let manifest):
            return try LibraryStoreIO.encoder().encode(manifest)
        }
    }

    private static func migrateLegacyManifest(
        _ legacy: LibraryManifestV1,
        paths: LibraryPackagePaths
    ) async throws -> LibraryStore {
        let base = LibraryManifestV2(projecting: legacy)
        let store = LibraryStore(paths: paths, manifest: base)
        var candidate = base
        candidate.revision += 1
        candidate.modifiedAtUnixMilliseconds = max(
            LibraryClock.nowUnixMilliseconds(),
            legacy.modifiedAtUnixMilliseconds
        )

        do {
            _ = try await store.commit(
                candidate: candidate,
                newObjects: [:],
                createdNodeIDs: [],
                changedNodeIDs: [],
                deletedNodeIDs: [],
                invalidatesPreviousManifest: false,
                purgeObjectIDs: []
            )
            return store
        } catch let error as LibraryStoreError {
            guard case .revisionConflict = error else { throw error }
            let latest = try readManifest(paths: paths, url: paths.manifest)
            guard case .v2(let current) = latest else { throw error }
            _ = try LibraryManifestValidator.validate(
                current,
                paths: paths,
                validatesPayloadFiles: true
            )
            return LibraryStore(paths: paths, manifest: current)
        }
    }

    private static func hasValidPreviousManifest(paths: LibraryPackagePaths) -> Bool {
        guard FileManager.default.fileExists(atPath: paths.previousManifest.path),
              (try? LibraryPackagePaths.validateRegularFile(
                  paths.previousManifest,
                  relativePath: ".state/previous-manifest.json",
                  fileManager: .default
              )) != nil,
              let previous = try? readManifest(paths: paths, url: paths.previousManifest),
              (try? LibraryManifestValidator.validate(
                  previous,
                  paths: paths,
                  validatesPayloadFiles: true
              )) != nil else {
            return false
        }
        return true
    }

    private static func readObject(
        _ objectID: ObjectID,
        byteCount: UInt64,
        expectedDigest: String,
        maximumBytes: Int,
        paths: LibraryPackagePaths
    ) throws -> Data {
        let objectURL = try paths.objectURL(for: objectID, createShard: false)
        guard FileManager.default.fileExists(atPath: objectURL.path) else {
            throw LibraryStoreError.missingObject(objectID)
        }
        try paths.validateObjectFile(objectURL, objectID: objectID)
        let data = try LibraryStoreIO.readData(
            from: objectURL,
            relativePath: paths.relativePath(for: objectURL),
            maximumBytes: maximumBytes
        )
        guard UInt64(data.count) == byteCount else {
            throw LibraryStoreError.objectSizeMismatch(objectID)
        }
        guard LibraryStoreIO.sha256Hex(data) == expectedDigest else {
            throw LibraryStoreError.objectDigestMismatch(objectID)
        }
        return data
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
}
