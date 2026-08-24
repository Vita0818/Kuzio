import Foundation

actor LibraryStore {
    let paths: LibraryPackagePaths
    var manifest: LibraryManifestV1
    let coordinator = NSFileCoordinator(filePresenter: nil)

    private init(paths: LibraryPackagePaths, manifest: LibraryManifestV1) {
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
            document: nil
        )
        let manifest = LibraryManifestV1(
            formatIdentifier: LibraryManifestV1.formatIdentifier,
            layoutVersion: LibraryManifestV1.layoutVersion,
            schemaVersion: LibraryManifestV1.schemaVersion,
            libraryID: LibraryID(),
            revision: 1,
            lastTransactionID: nil,
            rootNodeID: rootID,
            createdAtUnixMilliseconds: now,
            modifiedAtUnixMilliseconds: now,
            nodes: [rootNode],
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

        do {
            try paths.validateManifestExists()
            let manifest = try readManifest(paths: paths, url: paths.manifest)
            _ = try LibraryManifestValidator.validate(
                manifest,
                paths: paths,
                validatesPayloadFiles: true
            )
            let store = LibraryStore(paths: paths, manifest: manifest)
            try await store.completePublishedPurgeIntents()
            return store
        } catch let error as LibraryStoreError {
            if FileManager.default.fileExists(atPath: paths.previousManifest.path),
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
               )) != nil {
                throw LibraryStoreError.recoveryRequired
            }
            throw error
        }
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
        let data = try LibraryStoreIO.encoder().encode(previous)
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

    func readDocument(_ nodeID: NodeID) throws -> StoredDocument {
        var coordinationError: NSError?
        var coordinatedResult: Result<(LibraryManifestV1, StoredDocument), Error>?

        coordinator.coordinate(
            readingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readManifest(paths: paths, url: paths.manifest)
                let graph = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: false
                )
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                guard let node = graph.nodes[nodeID] else {
                    throw LibraryStoreError.nodeNotFound(nodeID)
                }
                guard node.kind == .document, let document = node.document else {
                    throw LibraryStoreError.kindMismatch(nodeID)
                }

                let objectURL = try paths.objectURL(
                    for: document.payload.objectID,
                    createShard: false
                )
                guard FileManager.default.fileExists(atPath: objectURL.path) else {
                    throw LibraryStoreError.missingObject(document.payload.objectID)
                }
                try paths.validateObjectFile(
                    objectURL,
                    objectID: document.payload.objectID
                )
                let relativePath = paths.relativePath(for: objectURL)
                let data = try LibraryStoreIO.readData(
                    from: objectURL,
                    relativePath: relativePath,
                    maximumBytes: LibraryStoreIO.maximumPayloadBytes
                )
                guard UInt64(data.count) == document.payload.byteCount else {
                    throw LibraryStoreError.objectSizeMismatch(document.payload.objectID)
                }
                guard LibraryStoreIO.sha256Hex(data) == document.payload.sha256 else {
                    throw LibraryStoreError.objectDigestMismatch(document.payload.objectID)
                }

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

    private func coordinatedReadState(
        validatesPayloadFiles: Bool
    ) throws -> (manifest: LibraryManifestV1, graph: ValidatedLibraryGraph) {
        var coordinationError: NSError?
        var result: Result<(LibraryManifestV1, ValidatedLibraryGraph), Error>?

        coordinator.coordinate(
            readingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            result = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readManifest(paths: paths, url: paths.manifest)
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
        let (current, graph) = try result.get()
        return (current, graph)
    }

    static func readManifest(
        paths: LibraryPackagePaths,
        url: URL
    ) throws -> LibraryManifestV1 {
        let relativePath = paths.relativePath(for: url)
        let data = try LibraryStoreIO.readData(
            from: url,
            relativePath: relativePath,
            maximumBytes: LibraryStoreIO.maximumManifestBytes
        )
        do {
            return try LibraryStoreIO.decoder().decode(LibraryManifestV1.self, from: data)
        } catch {
            throw LibraryStoreError.malformedManifest
        }
    }
}
