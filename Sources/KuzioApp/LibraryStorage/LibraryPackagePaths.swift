import Foundation

struct LibraryPackagePaths: Sendable {
    let root: URL
    let manifest: URL
    let objects: URL
    let state: URL
    let previousManifest: URL
    let transactions: URL
    let purge: URL

    private var fileManager: FileManager { .default }

    init(existingRoot rootURL: URL) throws {
        guard rootURL.isFileURL else {
            throw LibraryStoreError.invalidRootURL
        }

        let standardizedRoot = rootURL.standardizedFileURL
        try Self.validateDirectory(
            standardizedRoot,
            relativePath: ".",
            fileManager: .default
        )

        root = standardizedRoot
        manifest = standardizedRoot.appendingPathComponent("manifest.json", isDirectory: false)
        objects = standardizedRoot.appendingPathComponent("objects", isDirectory: true)
        state = standardizedRoot.appendingPathComponent(".state", isDirectory: true)
        previousManifest = state.appendingPathComponent("previous-manifest.json", isDirectory: false)
        transactions = state.appendingPathComponent("transactions", isDirectory: true)
        purge = state.appendingPathComponent("purge", isDirectory: true)

        try validateManagedDirectories()
    }

    static func create(at rootURL: URL) throws -> LibraryPackagePaths {
        guard rootURL.isFileURL else {
            throw LibraryStoreError.invalidRootURL
        }

        let fileManager = FileManager.default
        let standardizedRoot = rootURL.standardizedFileURL
        guard !fileManager.fileExists(atPath: standardizedRoot.path) else {
            throw LibraryStoreError.storeAlreadyExists
        }

        do {
            try fileManager.createDirectory(
                at: standardizedRoot,
                withIntermediateDirectories: false
            )
            try fileManager.createDirectory(
                at: standardizedRoot.appendingPathComponent("objects", isDirectory: true),
                withIntermediateDirectories: false
            )
            let state = standardizedRoot.appendingPathComponent(".state", isDirectory: true)
            try fileManager.createDirectory(at: state, withIntermediateDirectories: false)
            try fileManager.createDirectory(
                at: state.appendingPathComponent("transactions", isDirectory: true),
                withIntermediateDirectories: false
            )
            try fileManager.createDirectory(
                at: state.appendingPathComponent("purge", isDirectory: true),
                withIntermediateDirectories: false
            )
        } catch {
            throw LibraryStoreIO.map(error, operation: "create", relativePath: ".")
        }

        return try LibraryPackagePaths(existingRoot: standardizedRoot)
    }

    func validateManagedDirectories() throws {
        try Self.validateDirectory(objects, relativePath: "objects", fileManager: fileManager)
        try Self.validateDirectory(state, relativePath: ".state", fileManager: fileManager)
        try Self.validateDirectory(transactions, relativePath: ".state/transactions", fileManager: fileManager)
        try Self.validateDirectory(purge, relativePath: ".state/purge", fileManager: fileManager)
    }

    func validateManifestExists() throws {
        guard fileManager.fileExists(atPath: manifest.path) else {
            throw LibraryStoreError.storeNotFound
        }
        try Self.validateRegularFile(
            manifest,
            relativePath: "manifest.json",
            fileManager: fileManager
        )
    }

    func objectURL(for objectID: ObjectID, createShard: Bool) throws -> URL {
        let name = objectID.description
        let shardName = String(name.prefix(2))
        let shard = objects.appendingPathComponent(shardName, isDirectory: true)

        if !fileManager.fileExists(atPath: shard.path) {
            guard createShard else {
                throw LibraryStoreError.missingObject(objectID)
            }
            do {
                try fileManager.createDirectory(at: shard, withIntermediateDirectories: false)
            } catch {
                throw LibraryStoreIO.map(
                    error,
                    operation: "create",
                    relativePath: "objects/\(shardName)"
                )
            }
        }

        try Self.validateDirectory(
            shard,
            relativePath: "objects/\(shardName)",
            fileManager: fileManager
        )

        let result = shard.appendingPathComponent("\(name).payload", isDirectory: false)
        try validateContainment(result)
        return result
    }

    func transactionDirectory(for transactionID: TransactionID) -> URL {
        transactions.appendingPathComponent(transactionID.description, isDirectory: true)
    }

    func purgeIntentURL(for transactionID: TransactionID) -> URL {
        purge.appendingPathComponent("\(transactionID.description).json", isDirectory: false)
    }

    func relativePath(for url: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.starts(with: rootComponents) else {
            return "<outside-library>"
        }
        let suffix = components.dropFirst(rootComponents.count)
        return suffix.isEmpty ? "." : suffix.joined(separator: "/")
    }

    func validateContainment(_ url: URL) throws {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.starts(with: rootComponents) else {
            throw LibraryStoreError.unsafePath("<outside-library>")
        }
    }

    func validateObjectFile(_ url: URL, objectID: ObjectID) throws {
        try validateContainment(url)
        try Self.validateRegularFile(
            url,
            relativePath: "objects/\(String(objectID.description.prefix(2)))/\(objectID.description).payload",
            fileManager: fileManager
        )
    }

    private static func validateDirectory(
        _ url: URL,
        relativePath: String,
        fileManager: FileManager
    ) throws {
        do {
            let values = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .isAliasFileKey,
            ])
            if values.isSymbolicLink == true || values.isAliasFile == true {
                throw LibraryStoreError.symbolicLinkDetected(relativePath)
            }
            guard values.isDirectory == true else {
                throw LibraryStoreError.unexpectedFileType(relativePath)
            }
        } catch let error as LibraryStoreError {
            throw error
        } catch {
            throw LibraryStoreIO.map(error, operation: "inspect", relativePath: relativePath)
        }
    }

    static func validateRegularFile(
        _ url: URL,
        relativePath: String,
        fileManager: FileManager
    ) throws {
        do {
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .isAliasFileKey,
            ])
            if values.isSymbolicLink == true || values.isAliasFile == true {
                throw LibraryStoreError.symbolicLinkDetected(relativePath)
            }
            guard values.isRegularFile == true else {
                throw LibraryStoreError.unexpectedFileType(relativePath)
            }

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let referenceCount = attributes[.referenceCount] as? NSNumber,
               referenceCount.intValue > 1 {
                throw LibraryStoreError.unsafePath(relativePath)
            }
        } catch let error as LibraryStoreError {
            throw error
        } catch {
            throw LibraryStoreIO.map(error, operation: "inspect", relativePath: relativePath)
        }
    }
}
