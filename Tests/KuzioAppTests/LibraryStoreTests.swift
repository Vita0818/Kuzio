import Foundation
import XCTest
@testable import KuzioApp

final class LibraryStoreTests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KuzioTests-\(UUID().uuidString.lowercased())", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        if let testDirectory, FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
        }
    }

    func testCreateReopenAndCopyPackagePreservesIdentityAndContent() async throws {
        let root = libraryURL("Original")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let folder = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "任意层级",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let text = "# 可移植文档\n\n正文"
        let document = try await store.createDocument(
            in: folder.id,
            title: "文档",
            data: Data(text.utf8),
            expectedRevision: snapshot.revision
        )
        let originalSnapshot = try await store.snapshot()

        let reopened = try await LibraryStore.open(at: root)
        let reopenedSnapshot = try await reopened.snapshot()
        let reopenedDocument = try await reopened.readDocument(document.id)
        XCTAssertEqual(reopenedSnapshot.libraryID, originalSnapshot.libraryID)
        XCTAssertEqual(reopenedSnapshot.entry(document.id)?.parentID, folder.id)
        XCTAssertEqual(reopenedDocument.text, text)

        let copy = libraryURL("Copied")
        try FileManager.default.copyItem(at: root, to: copy)
        let copied = try await LibraryStore.open(at: copy)
        let copiedSnapshot = try await copied.snapshot()
        let copiedDocument = try await copied.readDocument(document.id)
        XCTAssertEqual(copiedSnapshot.libraryID, reopenedSnapshot.libraryID)
        XCTAssertEqual(copiedSnapshot.revision, reopenedSnapshot.revision)
        XCTAssertEqual(copiedSnapshot.entry(document.id)?.title, "文档")
        XCTAssertEqual(copiedDocument.text, text)
    }

    func testArbitraryDepthIsNotLimitedToFourLevels() async throws {
        let store = try await LibraryStore.create(at: libraryURL("Deep"), title: "资料库")
        var snapshot = try await store.snapshot()
        var parentID = snapshot.rootNodeID
        var createdIDs: [NodeID] = []

        for index in 0..<32 {
            let created = try await store.createFolder(
                in: parentID,
                title: "层级 \(index)",
                expectedRevision: snapshot.revision
            )
            createdIDs.append(created.id)
            parentID = created.id
            snapshot = try await store.snapshot()
        }

        XCTAssertEqual(snapshot.path(to: parentID).count, 33)
        XCTAssertEqual(Set(createdIDs).count, 32)
    }

    func testRenameAndMoveKeepStableNodeAndContentRevision() async throws {
        let store = try await LibraryStore.create(at: libraryURL("Stable"), title: "资料库")
        var snapshot = try await store.snapshot()
        let first = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "A",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let second = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "B",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: first.id,
            title: "原名",
            data: Data("content".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let originalContentRevision = snapshot.entry(document.id)?.document?.contentRevision

        _ = try await store.rename(document.id, to: "新名", expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.move(document.id, to: second.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()

        XCTAssertEqual(snapshot.entry(document.id)?.title, "新名")
        XCTAssertEqual(snapshot.entry(document.id)?.parentID, second.id)
        XCTAssertEqual(snapshot.entry(document.id)?.document?.contentRevision, originalContentRevision)
        let storedDocument = try await store.readDocument(document.id)
        XCTAssertEqual(storedDocument.text, "content")
    }

    func testFolderCannotMoveIntoOwnDescendant() async throws {
        let store = try await LibraryStore.create(at: libraryURL("Cycle"), title: "资料库")
        var snapshot = try await store.snapshot()
        let parent = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "父",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let child = try await store.createFolder(
            in: parent.id,
            title: "子",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        do {
            _ = try await store.move(parent.id, to: child.id, expectedRevision: snapshot.revision)
            XCTFail("Expected cycle detection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .cycleDetected)
        }
    }

    func testTrashAndRestorePreserveSubtreeAndIDs() async throws {
        let store = try await LibraryStore.create(at: libraryURL("Trash"), title: "资料库")
        var snapshot = try await store.snapshot()
        let folder = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "文件夹",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: folder.id,
            title: "文档",
            data: Data("text".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        _ = try await store.trash(folder.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()

        XCTAssertNil(snapshot.root.childIDs.first(where: { $0 == folder.id }))
        XCTAssertEqual(snapshot.trashItems.map(\.id), [folder.id])
        XCTAssertEqual(snapshot.entry(document.id)?.parentID, folder.id)

        _ = try await store.restore(folder.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        XCTAssertTrue(snapshot.root.childIDs.contains(folder.id))
        XCTAssertTrue(snapshot.trashItems.isEmpty)
        let restoredDocument = try await store.readDocument(document.id)
        XCTAssertEqual(restoredDocument.text, "text")
    }

    func testPermanentDeleteOnlyAcceptsTrashRootAndRemovesPayload() async throws {
        let root = libraryURL("Purge")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data("text".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        do {
            _ = try await store.permanentlyDeleteTrashItem(
                document.id,
                expectedRevision: snapshot.revision
            )
            XCTFail("Expected trash-only deletion")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .notInTrash(document.id))
        }

        _ = try await store.trash(document.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.permanentlyDeleteTrashItem(
            document.id,
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertNil(snapshot.entry(document.id))
        XCTAssertTrue(payloadFiles(in: root).isEmpty)
    }

    func testStaleRevisionFailsClosed() async throws {
        let root = libraryURL("Conflict")
        let first = try await LibraryStore.create(at: root, title: "资料库")
        let second = try await LibraryStore.open(at: root)
        let firstSnapshot = try await first.snapshot()
        let secondSnapshot = try await second.snapshot()
        let revision = firstSnapshot.revision

        _ = try await first.createFolder(
            in: firstSnapshot.rootNodeID,
            title: "A",
            expectedRevision: revision
        )

        do {
            _ = try await second.createFolder(
                in: secondSnapshot.rootNodeID,
                title: "B",
                expectedRevision: revision
            )
            XCTFail("Expected revision conflict")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .revisionConflict(expected: revision, actual: revision + 1))
        }
    }

    func testConcurrentWritersDoNotLoseUpdates() async throws {
        let root = libraryURL("Concurrent")
        let first = try await LibraryStore.create(at: root, title: "资料库")
        let second = try await LibraryStore.open(at: root)
        let firstSnapshot = try await first.snapshot()
        let secondSnapshot = try await second.snapshot()

        let firstTask = Task {
            try await first.createFolder(
                in: firstSnapshot.rootNodeID,
                title: "A",
                expectedRevision: firstSnapshot.revision
            )
        }
        let secondTask = Task {
            try await second.createFolder(
                in: secondSnapshot.rootNodeID,
                title: "B",
                expectedRevision: secondSnapshot.revision
            )
        }

        let results = [await firstTask.result, await secondTask.result]
        let successCount = results.reduce(into: 0) { count, result in
            if case .success = result { count += 1 }
        }
        let conflictCount = results.reduce(into: 0) { count, result in
            if case .failure(let error as LibraryStoreError) = result,
               case .revisionConflict = error {
                count += 1
            }
        }

        XCTAssertEqual(successCount, 1)
        XCTAssertEqual(conflictCount, 1)
        let reopened = try await LibraryStore.open(at: root)
        let reopenedSnapshot = try await reopened.snapshot()
        XCTAssertEqual(reopenedSnapshot.root.childIDs.count, 1)
    }

    func testStaleStoreGarbageCollectionKeepsNewerWriterPayload() async throws {
        let root = libraryURL("GarbageCollectionConcurrency")
        let staleStore = try await LibraryStore.create(at: root, title: "资料库")
        let writer = try await LibraryStore.open(at: root)
        let snapshot = try await writer.snapshot()
        let document = try await writer.createDocument(
            in: snapshot.rootNodeID,
            title: "新文档",
            data: Data("newer payload".utf8),
            expectedRevision: snapshot.revision
        )

        let removed = try await staleStore.collectGarbage()
        XCTAssertEqual(removed, 0)

        let reopened = try await LibraryStore.open(at: root)
        let storedDocument = try await reopened.readDocument(document.id)
        XCTAssertEqual(storedDocument.text, "newer payload")
    }

    func testDocumentReadUsesLatestCoordinatedManifest() async throws {
        let root = libraryURL("CoordinatedRead")
        let first = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await first.snapshot()
        let document = try await first.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data("first".utf8),
            expectedRevision: snapshot.revision
        )

        let second = try await LibraryStore.open(at: root)
        snapshot = try await second.snapshot()
        _ = try await second.updateDocument(
            document.id,
            data: Data("second".utf8),
            expectedRevision: snapshot.revision
        )

        let latest = try await first.readDocument(document.id)
        XCTAssertEqual(latest.text, "second")
        XCTAssertEqual(latest.contentRevision, 2)
    }

    func testCorruptCurrentManifestRequiresExplicitRecovery() async throws {
        let root = libraryURL("Recovery")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        _ = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "提交后节点",
            expectedRevision: snapshot.revision
        )

        try Data("{".utf8).write(to: root.appendingPathComponent("manifest.json"))

        do {
            _ = try await LibraryStore.open(at: root)
            XCTFail("Expected explicit recovery requirement")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .recoveryRequired)
        }

        let recovered = try await LibraryStore.recoverPreviousManifest(at: root)
        let recoveredSnapshot = try await recovered.snapshot()
        XCTAssertEqual(recoveredSnapshot.revision, 1)
        XCTAssertEqual(recoveredSnapshot.root.childIDs, [])
    }

    func testPayloadCorruptionIsDetected() async throws {
        let root = libraryURL("CorruptPayload")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data("correct".utf8),
            expectedRevision: snapshot.revision
        )
        let payload = try XCTUnwrap(payloadFiles(in: root).first)
        try Data("wrong!!".utf8).write(to: payload)

        do {
            _ = try await store.readDocument(document.id)
            XCTFail("Expected digest mismatch")
        } catch let error as LibraryStoreError {
            XCTAssertTrue(
                error == .objectDigestMismatch(try payloadObjectID(payload))
                    || error == .objectSizeMismatch(try payloadObjectID(payload))
            )
        }
    }

    func testTrashedDocumentCannotBeRenamedOrEdited() async throws {
        let store = try await LibraryStore.create(at: libraryURL("TrashMutation"), title: "资料库")
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data("text".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        _ = try await store.trash(document.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()

        do {
            _ = try await store.rename(
                document.id,
                to: "新名称",
                expectedRevision: snapshot.revision
            )
            XCTFail("Expected trashed-node mutation rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .alreadyTrashed(document.id))
        }

        do {
            _ = try await store.updateDocument(
                document.id,
                data: Data("changed".utf8),
                expectedRevision: snapshot.revision
            )
            XCTFail("Expected trashed-document mutation rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .alreadyTrashed(document.id))
        }
    }

    func testManifestSymlinkIsRejectedWithoutFollowingIt() async throws {
        let root = libraryURL("Symlink")
        _ = try await LibraryStore.create(at: root, title: "资料库")
        let manifest = root.appendingPathComponent("manifest.json")
        let sentinel = testDirectory.appendingPathComponent("sentinel.json")
        try Data("outside".utf8).write(to: sentinel)
        try FileManager.default.removeItem(at: manifest)
        try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: sentinel)

        do {
            _ = try await LibraryStore.open(at: root)
            XCTFail("Expected symbolic link rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .symbolicLinkDetected("manifest.json"))
        }
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "outside")
    }

    func testPayloadSymlinkIsRejectedWithoutReadingOutsideLibrary() async throws {
        let root = libraryURL("PayloadSymlink")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data("inside".utf8),
            expectedRevision: snapshot.revision
        )
        let payload = try XCTUnwrap(payloadFiles(in: root).first)
        let objectID = try payloadObjectID(payload)
        let sentinel = testDirectory.appendingPathComponent("outside.payload")
        try Data("outside".utf8).write(to: sentinel)
        try FileManager.default.removeItem(at: payload)
        try FileManager.default.createSymbolicLink(at: payload, withDestinationURL: sentinel)

        do {
            _ = try await store.readDocument(document.id)
            XCTFail("Expected payload symbolic link rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .symbolicLinkDetected(
                "objects/\(String(objectID.description.prefix(2)))/\(objectID.description).payload"
            ))
        }
        XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "outside")
    }

    func testRestoreRequiresExplicitDestinationWhenOriginalParentWasDeleted() async throws {
        let store = try await LibraryStore.create(at: libraryURL("RestoreDestination"), title: "资料库")
        var snapshot = try await store.snapshot()
        let parent = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "父",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let child = try await store.createDocument(
            in: parent.id,
            title: "子",
            data: Data(),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        _ = try await store.trash(child.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.trash(parent.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.permanentlyDeleteTrashItem(parent.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()

        do {
            _ = try await store.restore(child.id, expectedRevision: snapshot.revision)
            XCTFail("Expected explicit destination requirement")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .invalidRestoreDestination(parent.id))
        }

        _ = try await store.restore(
            child.id,
            to: snapshot.rootNodeID,
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.entry(child.id)?.parentID, snapshot.rootNodeID)
    }

    func testTitlesNeverBecomeFilesystemPaths() async throws {
        let root = libraryURL("Titles")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        let title = "../绝对/路径\\组合字符e\u{301}"
        let created = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: title,
            data: Data("text".utf8),
            expectedRevision: snapshot.revision
        )
        let reopened = try await LibraryStore.open(at: root)
        let reopenedSnapshot = try await reopened.snapshot()
        let entry = try XCTUnwrap(reopenedSnapshot.entry(created.id))

        XCTAssertEqual(entry.title, title.precomposedStringWithCanonicalMapping)
        XCTAssertEqual(payloadFiles(in: root).count, 1)
        XCTAssertFalse(
            FileManager.default.enumerator(atPath: root.path)?.allObjects
                .compactMap { $0 as? String }
                .contains(where: { $0.contains("绝对") }) ?? true
        )
    }

    func testRootAndDocumentCannotBeUsedAsFolderMutationTargets() async throws {
        let store = try await LibraryStore.create(at: libraryURL("Kinds"), title: "资料库")
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "文档",
            data: Data(),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        do {
            _ = try await store.rename(snapshot.rootNodeID, to: "根", expectedRevision: snapshot.revision)
            XCTFail("Expected root mutation rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .rootMutationForbidden)
        }

        do {
            _ = try await store.createFolder(
                in: document.id,
                title: "非法",
                expectedRevision: snapshot.revision
            )
            XCTFail("Expected parent kind rejection")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .parentNotFolder(document.id))
        }
    }

    private func libraryURL(_ name: String) -> URL {
        testDirectory.appendingPathComponent("\(name).kuzio", isDirectory: true)
    }

    private func payloadFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root.appendingPathComponent("objects"),
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "payload",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            results.append(url)
        }
        return results
    }

    private func payloadObjectID(_ url: URL) throws -> ObjectID {
        let value = url.deletingPathExtension().lastPathComponent
        return ObjectID(try XCTUnwrap(UUID(uuidString: value)))
    }
}
