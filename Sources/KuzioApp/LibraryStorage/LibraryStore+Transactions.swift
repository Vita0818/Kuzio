import Darwin
import Foundation

extension LibraryStore {
    func commit(
        candidate initialCandidate: LibraryManifestV1,
        newObjects: [ObjectID: Data],
        createdNodeIDs: [NodeID],
        changedNodeIDs: [NodeID],
        deletedNodeIDs: [NodeID],
        invalidatesPreviousManifest: Bool,
        purgeObjectIDs: [ObjectID]
    ) throws -> LibraryCommitReceipt {
        try Task.checkCancellation()

        let transactionID = TransactionID()
        var candidate = initialCandidate
        candidate.lastTransactionID = transactionID
        _ = try LibraryManifestValidator.validate(
            candidate,
            paths: paths,
            validatesPayloadFiles: false
        )

        let transactionDirectory = paths.transactionDirectory(for: transactionID)
        let transactionObjects = transactionDirectory.appendingPathComponent("objects", isDirectory: true)
        let stagedManifest = transactionDirectory.appendingPathComponent("manifest.json", isDirectory: false)
        let stagedIntent = transactionDirectory.appendingPathComponent("intent.json", isDirectory: false)

        do {
            try FileManager.default.createDirectory(
                at: transactionDirectory,
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: transactionObjects,
                withIntermediateDirectories: false
            )
        } catch {
            throw LibraryStoreIO.map(
                error,
                operation: "create",
                relativePath: ".state/transactions/\(transactionID.description)"
            )
        }

        let intent = LibraryTransactionIntent(
            transactionID: transactionID,
            libraryID: manifest.libraryID,
            baseRevision: manifest.revision,
            targetRevision: candidate.revision,
            createdObjectIDs: newObjects.keys.sorted(by: { $0.description < $1.description }),
            invalidatesPreviousManifest: invalidatesPreviousManifest
        )
        let intentData = try LibraryStoreIO.encoder().encode(intent)
        let manifestData = try LibraryStoreIO.encoder().encode(candidate)
        try LibraryStoreIO.durableWrite(
            intentData,
            to: stagedIntent,
            relativePath: ".state/transactions/\(transactionID.description)/intent.json"
        )
        try LibraryStoreIO.durableWrite(
            manifestData,
            to: stagedManifest,
            relativePath: ".state/transactions/\(transactionID.description)/manifest.json"
        )

        for (objectID, data) in newObjects {
            let stagedObject = transactionObjects.appendingPathComponent(
                "\(objectID.description).payload",
                isDirectory: false
            )
            try LibraryStoreIO.durableWrite(
                data,
                to: stagedObject,
                relativePath: ".state/transactions/\(transactionID.description)/objects/\(objectID.description).payload"
            )
            guard LibraryStoreIO.sha256Hex(data) == candidate.nodes
                .compactMap(\.document?.payload)
                .first(where: { $0.objectID == objectID })?.sha256 else {
                throw LibraryStoreError.corruptPayload(objectID)
            }
        }

        let purgeIntentURL = paths.purgeIntentURL(for: transactionID)
        if invalidatesPreviousManifest {
            let purgeIntent = LibraryPurgeIntent(
                transactionID: transactionID,
                targetRevision: candidate.revision,
                objectIDs: purgeObjectIDs.sorted(by: { $0.description < $1.description })
            )
            try LibraryStoreIO.atomicReplace(
                try LibraryStoreIO.encoder().encode(purgeIntent),
                at: purgeIntentURL,
                relativePath: ".state/purge/\(transactionID.description).json"
            )
        }

        try Task.checkCancellation()

        var coordinationError: NSError?
        var coordinatedResult: Result<Void, Error>?
        coordinator.coordinate(
            writingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let diskManifest = try Self.readManifest(paths: paths, url: paths.manifest)
                _ = try LibraryManifestValidator.validate(
                    diskManifest,
                    paths: paths,
                    validatesPayloadFiles: true
                )
                guard diskManifest.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                guard diskManifest.revision == intent.baseRevision else {
                    throw LibraryStoreError.revisionConflict(
                        expected: intent.baseRevision,
                        actual: diskManifest.revision
                    )
                }

                try LibraryStoreIO.atomicReplace(
                    try LibraryStoreIO.encoder().encode(diskManifest),
                    at: paths.previousManifest,
                    relativePath: ".state/previous-manifest.json"
                )

                for objectID in intent.createdObjectIDs {
                    let stagedObject = transactionObjects.appendingPathComponent(
                        "\(objectID.description).payload",
                        isDirectory: false
                    )
                    try LibraryPackagePaths.validateRegularFile(
                        stagedObject,
                        relativePath: ".state/transactions/\(transactionID.description)/objects/\(objectID.description).payload",
                        fileManager: .default
                    )
                    let destination = try paths.objectURL(for: objectID, createShard: true)
                    guard !FileManager.default.fileExists(atPath: destination.path) else {
                        throw LibraryStoreError.io(
                            operation: "promote",
                            relativePath: paths.relativePath(for: destination),
                            code: Int(EEXIST)
                        )
                    }
                    do {
                        try FileManager.default.moveItem(at: stagedObject, to: destination)
                    } catch {
                        throw LibraryStoreIO.map(
                            error,
                            operation: "promote",
                            relativePath: paths.relativePath(for: destination)
                        )
                    }
                    try paths.validateObjectFile(destination, objectID: objectID)
                }

                try LibraryStoreIO.atomicReplace(
                    manifestData,
                    at: paths.manifest,
                    relativePath: "manifest.json"
                )
                let published = try Self.readManifest(paths: paths, url: paths.manifest)
                guard published.revision == candidate.revision,
                      published.lastTransactionID == transactionID else {
                    throw LibraryStoreError.invariantViolation("publish-verification")
                }
                _ = try LibraryManifestValidator.validate(
                    published,
                    paths: paths,
                    validatesPayloadFiles: true
                )

                if invalidatesPreviousManifest {
                    try LibraryStoreIO.atomicReplace(
                        manifestData,
                        at: paths.previousManifest,
                        relativePath: ".state/previous-manifest.json"
                    )
                }
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let coordinatedResult else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        do {
            try coordinatedResult.get()
        } catch {
            try? FileManager.default.removeItem(at: transactionDirectory)
            throw error
        }

        manifest = candidate
        var cleanupPending = false
        do {
            try FileManager.default.removeItem(at: transactionDirectory)
        } catch {
            cleanupPending = true
        }

        do {
            _ = try coordinatedCollectGarbage()
            if invalidatesPreviousManifest,
               FileManager.default.fileExists(atPath: purgeIntentURL.path) {
                try FileManager.default.removeItem(at: purgeIntentURL)
            }
        } catch {
            cleanupPending = true
        }

        return LibraryCommitReceipt(
            revision: candidate.revision,
            transactionID: transactionID,
            createdNodeIDs: createdNodeIDs,
            changedNodeIDs: changedNodeIDs,
            deletedNodeIDs: deletedNodeIDs,
            cleanupPending: cleanupPending
        )
    }

    func completePublishedPurgeIntents() throws {
        var coordinationError: NSError?
        var coordinatedResult: Result<LibraryManifestV1, Error>?

        coordinator.coordinate(
            writingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readManifest(paths: paths, url: paths.manifest)
                _ = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: true
                )
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }

                let fileManager = FileManager.default
                let contents: [URL]
                do {
                    contents = try fileManager.contentsOfDirectory(
                        at: paths.purge,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                } catch {
                    throw LibraryStoreIO.map(
                        error,
                        operation: "list",
                        relativePath: ".state/purge"
                    )
                }

                for url in contents {
                    guard url.pathExtension == "json" else {
                        throw LibraryStoreError.unexpectedFileType(paths.relativePath(for: url))
                    }
                    try LibraryPackagePaths.validateRegularFile(
                        url,
                        relativePath: paths.relativePath(for: url),
                        fileManager: fileManager
                    )
                    let data = try LibraryStoreIO.readData(
                        from: url,
                        relativePath: paths.relativePath(for: url),
                        maximumBytes: 1_024 * 1_024
                    )
                    let intent: LibraryPurgeIntent
                    do {
                        intent = try LibraryStoreIO.decoder().decode(
                            LibraryPurgeIntent.self,
                            from: data
                        )
                    } catch {
                        throw LibraryStoreError.purgeIncomplete
                    }

                    guard url.deletingPathExtension().lastPathComponent == intent.transactionID.description,
                          intent.targetRevision > 0,
                          Set(intent.objectIDs).count == intent.objectIDs.count else {
                        throw LibraryStoreError.purgeIncomplete
                    }

                    if current.revision == intent.targetRevision,
                       current.lastTransactionID == intent.transactionID {
                        try LibraryStoreIO.atomicReplace(
                            try LibraryStoreIO.encoder().encode(current),
                            at: paths.previousManifest,
                            relativePath: ".state/previous-manifest.json"
                        )
                    }

                    _ = try collectUnreferencedObjects(current: current)
                    do {
                        try fileManager.removeItem(at: url)
                    } catch {
                        throw LibraryStoreError.purgeIncomplete
                    }
                }

                return current
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let coordinatedResult else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        manifest = try coordinatedResult.get()
    }

    func coordinatedCollectGarbage() throws -> Int {
        var coordinationError: NSError?
        var coordinatedResult: Result<(LibraryManifestV1, Int), Error>?

        coordinator.coordinate(
            writingItemAt: paths.root,
            options: [],
            error: &coordinationError
        ) { _ in
            coordinatedResult = Result {
                try paths.validateManagedDirectories()
                try paths.validateManifestExists()
                let current = try Self.readManifest(paths: paths, url: paths.manifest)
                _ = try LibraryManifestValidator.validate(
                    current,
                    paths: paths,
                    validatesPayloadFiles: true
                )
                guard current.libraryID == manifest.libraryID else {
                    throw LibraryStoreError.invariantViolation("library-id-changed")
                }
                return (current, try collectUnreferencedObjects(current: current))
            }
        }

        if let coordinationError {
            throw LibraryStoreError.coordinationFailed(coordinationError.code)
        }
        guard let coordinatedResult else {
            throw LibraryStoreError.coordinationFailed(-1)
        }
        let (current, removed) = try coordinatedResult.get()
        manifest = current
        return removed
    }

    func collectUnreferencedObjects(current: LibraryManifestV1) throws -> Int {
        var referenced = referencedObjectIDs(in: current)

        if FileManager.default.fileExists(atPath: paths.previousManifest.path) {
            try LibraryPackagePaths.validateRegularFile(
                paths.previousManifest,
                relativePath: ".state/previous-manifest.json",
                fileManager: .default
            )
            let previous = try Self.readManifest(paths: paths, url: paths.previousManifest)
            _ = try LibraryManifestValidator.validate(
                previous,
                paths: paths,
                validatesPayloadFiles: false
            )
            referenced.formUnion(referencedObjectIDs(in: previous))
        }

        guard let enumerator = FileManager.default.enumerator(
            at: paths.objects,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryStoreError.io(operation: "list", relativePath: "objects", code: Int(EIO))
        }

        var removed = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            if values.isSymbolicLink == true {
                throw LibraryStoreError.symbolicLinkDetected(paths.relativePath(for: url))
            }
            guard values.isRegularFile == true, url.pathExtension == "payload" else {
                continue
            }

            let identifier = url.deletingPathExtension().lastPathComponent
            guard let uuid = UUID(uuidString: identifier),
                  uuid.uuidString.lowercased() == identifier else {
                throw LibraryStoreError.unsafePath(paths.relativePath(for: url))
            }
            let objectID = ObjectID(uuid)
            if !referenced.contains(objectID) {
                do {
                    try FileManager.default.removeItem(at: url)
                    removed += 1
                } catch {
                    throw LibraryStoreIO.map(
                        error,
                        operation: "remove",
                        relativePath: paths.relativePath(for: url)
                    )
                }
            }
        }
        return removed
    }

    private func referencedObjectIDs(in manifest: LibraryManifestV1) -> Set<ObjectID> {
        Set(manifest.nodes.compactMap { $0.document?.payload.objectID })
    }
}
