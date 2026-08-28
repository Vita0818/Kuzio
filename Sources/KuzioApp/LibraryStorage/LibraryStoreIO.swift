import CryptoKit
import Darwin
import Foundation

enum LibraryStoreIO {
    static let maximumManifestBytes = 64 * 1_024 * 1_024
    static let maximumPayloadBytes = 64 * 1_024 * 1_024
    static let maximumLocatorBytes = 1 * 1_024 * 1_024

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func readData(
        from url: URL,
        relativePath: String,
        maximumBytes: Int
    ) throws -> Data {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber,
                  size.uint64Value <= UInt64(maximumBytes) else {
                throw LibraryStoreError.io(
                    operation: "read",
                    relativePath: relativePath,
                    code: Int(EFBIG)
                )
            }
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch let error as LibraryStoreError {
            throw error
        } catch {
            throw map(error, operation: "read", relativePath: relativePath)
        }
    }

    static func durableWrite(_ data: Data, to url: URL, relativePath: String) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else {
            throw LibraryStoreError.io(
                operation: "create",
                relativePath: relativePath,
                code: Int(EEXIST)
            )
        }

        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            throw LibraryStoreError.io(
                operation: "create",
                relativePath: relativePath,
                code: Int(EIO)
            )
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? fileManager.removeItem(at: url)
            throw map(error, operation: "write", relativePath: relativePath)
        }
    }

    static func atomicReplace(_ data: Data, at destination: URL, relativePath: String) throws {
        let fileManager = FileManager.default
        let temporary = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString.lowercased()).tmp")

        try durableWrite(data, to: temporary, relativePath: "\(relativePath).tmp")

        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(
                    destination,
                    withItemAt: temporary,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw map(error, operation: "replace", relativePath: relativePath)
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func map(_ error: Error, operation: String, relativePath: String) -> LibraryStoreError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           (nsError.code == NSFileReadNoPermissionError
                || nsError.code == NSFileWriteNoPermissionError) {
            return .permissionDenied(relativePath)
        }
        return .io(operation: operation, relativePath: relativePath, code: nsError.code)
    }
}
