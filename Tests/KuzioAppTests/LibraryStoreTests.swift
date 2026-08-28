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
            let corruptedObjectID = try payloadObjectID(payload)
            XCTAssertTrue(
                error == .objectDigestMismatch(corruptedObjectID)
                    || error == .objectSizeMismatch(corruptedObjectID)
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

    func testExternalResourceLinkKeepsVirtualTreeIndependentFromTarget() async throws {
        let root = libraryURL("ExternalIndependence")
        let target = testDirectory.appendingPathComponent("actual-source.pdf")
        let targetData = Data("external bytes".utf8)
        try targetData.write(to: target)

        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let firstFolder = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "虚拟位置 A",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let secondFolder = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "虚拟位置 B",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let locatorData = Data(target.path.utf8)
        let created = try await store.createExternalResourceLink(
            in: firstFolder.id,
            title: "库内别名",
            kind: .file,
            locatorData: locatorData,
            lastKnownName: target.lastPathComponent,
            contentTypeIdentifier: "com.adobe.pdf",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let linkedEntry = try XCTUnwrap(snapshot.entry(created.nodeID))
        XCTAssertEqual(linkedEntry.parentID, firstFolder.id)
        XCTAssertEqual(linkedEntry.kind, .resourceLink)
        XCTAssertEqual(linkedEntry.externalResource?.resourceID, created.resourceID)
        XCTAssertEqual(linkedEntry.externalResource?.lastKnownName, "actual-source.pdf")
        let manifestText = try String(
            contentsOf: root.appendingPathComponent("manifest.json"),
            encoding: .utf8
        )
        XCTAssertFalse(manifestText.contains(target.path))

        _ = try await store.rename(
            created.nodeID,
            to: "完全独立的显示名",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        _ = try await store.move(
            created.nodeID,
            to: secondFolder.id,
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertEqual(snapshot.entry(created.nodeID)?.parentID, secondFolder.id)
        XCTAssertEqual(snapshot.entry(created.nodeID)?.title, "完全独立的显示名")
        XCTAssertEqual(try Data(contentsOf: target), targetData)
        let resource = try await store.readExternalResource(created.resourceID)
        XCTAssertEqual(resource.locatorData, locatorData)

        _ = try await store.trash(created.nodeID, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.permanentlyDeleteTrashItem(
            created.nodeID,
            expectedRevision: snapshot.revision
        )

        XCTAssertEqual(try Data(contentsOf: target), targetData)
        XCTAssertTrue(payloadFiles(in: root).isEmpty)
    }

    func testExternalLinkedTreeCreatesRecursiveVirtualStructureInOneRevision() async throws {
        let root = libraryURL("RecursiveExternalTree")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let initial = try await store.snapshot()
        let drafts = [
            LibraryLinkedItemDraft(
                parentDraftIndex: nil,
                title: "UCB-CS61A",
                kind: .folder
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 0,
                title: "Notes",
                kind: .folder
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 1,
                title: "Syllabus.md",
                kind: .file(
                    LibraryLinkedFileDraft(
                        locatorData: Data("bookmark-syllabus".utf8),
                        lastKnownName: "Syllabus.md",
                        contentTypeIdentifier: "net.daringfireball.markdown"
                    )
                )
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 0,
                title: "Empty",
                kind: .folder
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 0,
                title: "lecture01.pdf",
                kind: .file(
                    LibraryLinkedFileDraft(
                        locatorData: Data("bookmark-lecture".utf8),
                        lastKnownName: "lecture01.pdf",
                        contentTypeIdentifier: "com.adobe.pdf"
                    )
                )
            ),
        ]

        let created = try await store.createExternalLinkedTree(
            in: initial.rootNodeID,
            drafts: drafts,
            expectedRevision: initial.revision
        )
        let snapshot = try await store.snapshot()

        XCTAssertEqual(snapshot.revision, initial.revision + 1)
        XCTAssertEqual(created.receipt.createdNodeIDs.count, drafts.count)
        XCTAssertEqual(created.receipt.createdResourceIDs.count, 2)
        XCTAssertEqual(created.rootNodeIDs, [created.receipt.createdNodeIDs[0]])

        let courseID = try XCTUnwrap(created.rootNodeIDs.first)
        let notesID = created.receipt.createdNodeIDs[1]
        let syllabusID = created.receipt.createdNodeIDs[2]
        let emptyID = created.receipt.createdNodeIDs[3]
        let lectureID = created.receipt.createdNodeIDs[4]
        XCTAssertEqual(snapshot.entry(courseID)?.parentID, snapshot.rootNodeID)
        XCTAssertEqual(snapshot.entry(courseID)?.childIDs, [notesID, emptyID, lectureID])
        XCTAssertEqual(snapshot.entry(notesID)?.childIDs, [syllabusID])
        XCTAssertEqual(snapshot.entry(emptyID)?.childIDs, [])
        XCTAssertEqual(snapshot.entry(syllabusID)?.kind, .resourceLink)
        XCTAssertEqual(snapshot.entry(lectureID)?.kind, .resourceLink)
        XCTAssertEqual(payloadFiles(in: root).count, 2)

        var locatorValues: [Data] = []
        for resourceID in created.receipt.createdResourceIDs {
            locatorValues.append(try await store.readExternalResource(resourceID).locatorData)
        }
        XCTAssertEqual(Set(locatorValues), Set([
            Data("bookmark-syllabus".utf8),
            Data("bookmark-lecture".utf8),
        ]))

        let reopened = try await LibraryStore.open(at: root)
        let reopenedSnapshot = try await reopened.snapshot()
        XCTAssertEqual(reopenedSnapshot.entry(courseID)?.childIDs, [notesID, emptyID, lectureID])
        XCTAssertEqual(reopenedSnapshot.path(to: syllabusID).map(\.title), [
            "资料库",
            "UCB-CS61A",
            "Notes",
            "Syllabus.md",
        ])
    }

    func testExternalLinkedTreeFailureDoesNotPartiallyCommit() async throws {
        let root = libraryURL("RecursiveExternalTreeFailure")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let initial = try await store.snapshot()
        let drafts = [
            LibraryLinkedItemDraft(
                parentDraftIndex: nil,
                title: "Course",
                kind: .folder
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 0,
                title: "valid.pdf",
                kind: .file(
                    LibraryLinkedFileDraft(
                        locatorData: Data("valid-bookmark".utf8),
                        lastKnownName: "valid.pdf",
                        contentTypeIdentifier: "com.adobe.pdf"
                    )
                )
            ),
            LibraryLinkedItemDraft(
                parentDraftIndex: 0,
                title: "invalid.pdf",
                kind: .file(
                    LibraryLinkedFileDraft(
                        locatorData: Data(),
                        lastKnownName: "invalid.pdf",
                        contentTypeIdentifier: "com.adobe.pdf"
                    )
                )
            ),
        ]

        do {
            _ = try await store.createExternalLinkedTree(
                in: initial.rootNodeID,
                drafts: drafts,
                expectedRevision: initial.revision
            )
            XCTFail("Expected the invalid locator to reject the entire linked tree")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .invalidResourceLocator)
        }

        let unchanged = try await store.snapshot()
        XCTAssertEqual(unchanged.revision, initial.revision)
        XCTAssertTrue(unchanged.children(of: unchanged.rootNodeID).isEmpty)
        XCTAssertTrue(payloadFiles(in: root).isEmpty)
    }

    func testResourceAliasesShareIdentityUntilLastAliasIsDeleted() async throws {
        let root = libraryURL("ResourceAliases")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let created = try await store.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "主链接",
            kind: .file,
            locatorData: Data("opaque-bookmark".utf8),
            lastKnownName: "source.pdf",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let alias = try await store.createResourceAlias(
            to: created.resourceID,
            in: snapshot.rootNodeID,
            title: "另一个位置",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertEqual(
            snapshot.entry(alias.id)?.externalResource?.resourceID,
            created.resourceID
        )
        XCTAssertEqual(payloadFiles(in: root).count, 1)

        _ = try await store.trash(created.nodeID, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.permanentlyDeleteTrashItem(
            created.nodeID,
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertNotNil(snapshot.entry(alias.id))
        let remainingResource = try await store.readExternalResource(created.resourceID)
        XCTAssertEqual(
            remainingResource.locatorData,
            Data("opaque-bookmark".utf8)
        )
        XCTAssertEqual(payloadFiles(in: root).count, 1)

        _ = try await store.trash(alias.id, expectedRevision: snapshot.revision)
        snapshot = try await store.snapshot()
        _ = try await store.permanentlyDeleteTrashItem(
            alias.id,
            expectedRevision: snapshot.revision
        )

        do {
            _ = try await store.readExternalResource(created.resourceID)
            XCTFail("Expected the unreferenced resource record to be removed")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .resourceNotFound(created.resourceID))
        }
        XCTAssertTrue(payloadFiles(in: root).isEmpty)
    }

    func testReplacingLocatorPreservesResourceIdentityAcrossAliases() async throws {
        let root = libraryURL("Relink")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let created = try await store.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "原链接",
            kind: .file,
            locatorData: Data("bookmark-one".utf8),
            lastKnownName: "one.pdf",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let alias = try await store.createResourceAlias(
            to: created.resourceID,
            in: snapshot.rootNodeID,
            title: "别名",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let receipt = try await store.replaceExternalResourceLocator(
            for: created.nodeID,
            locatorData: Data("bookmark-two".utf8),
            lastKnownName: "two.pdf",
            contentTypeIdentifier: "com.adobe.pdf",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertEqual(receipt.changedResourceIDs, [created.resourceID])
        XCTAssertEqual(
            snapshot.entry(created.nodeID)?.externalResource?.resourceID,
            created.resourceID
        )
        XCTAssertEqual(
            snapshot.entry(alias.id)?.externalResource?.resourceID,
            created.resourceID
        )
        XCTAssertEqual(
            snapshot.entry(alias.id)?.externalResource?.lastKnownName,
            "two.pdf"
        )
        let replacedResource = try await store.readExternalResource(created.resourceID)
        XCTAssertEqual(
            replacedResource.locatorData,
            Data("bookmark-two".utf8)
        )

        _ = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "触发下一次提交",
            expectedRevision: snapshot.revision
        )
        XCTAssertEqual(payloadFiles(in: root).count, 1)
    }

    func testBatchRelinkPreservesVirtualStructureAndResourceIdentity() async throws {
        let root = libraryURL("BatchRelink")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let importID = ImportID()
        let created = try await store.createExternalLinkedTree(
            in: snapshot.rootNodeID,
            drafts: [
                LibraryLinkedItemDraft(
                    parentDraftIndex: nil,
                    title: "Course",
                    kind: .folder
                ),
                LibraryLinkedItemDraft(
                    parentDraftIndex: 0,
                    title: "Notes",
                    kind: .folder
                ),
                LibraryLinkedItemDraft(
                    parentDraftIndex: 1,
                    title: "Syllabus.md",
                    kind: .file(
                        LibraryLinkedFileDraft(
                            locatorData: Data("old-syllabus".utf8),
                            lastKnownName: "Syllabus.md",
                            contentTypeIdentifier: "net.daringfireball.markdown",
                            origin: LibraryExternalResourceOrigin(
                                importID: importID,
                                relativePathComponents: ["Notes", "Syllabus.md"]
                            )
                        )
                    )
                ),
                LibraryLinkedItemDraft(
                    parentDraftIndex: 0,
                    title: "lecture.pdf",
                    kind: .file(
                        LibraryLinkedFileDraft(
                            locatorData: Data("old-lecture".utf8),
                            lastKnownName: "lecture.pdf",
                            contentTypeIdentifier: "com.adobe.pdf",
                            origin: LibraryExternalResourceOrigin(
                                importID: importID,
                                relativePathComponents: ["lecture.pdf"]
                            )
                        )
                    )
                ),
            ],
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let courseID = created.receipt.createdNodeIDs[0]
        let syllabusID = created.receipt.createdNodeIDs[2]
        let lectureID = created.receipt.createdNodeIDs[3]
        let syllabusResourceID = try XCTUnwrap(
            snapshot.entry(syllabusID)?.externalResource?.resourceID
        )
        let lectureResourceID = try XCTUnwrap(
            snapshot.entry(lectureID)?.externalResource?.resourceID
        )

        _ = try await store.rename(
            courseID,
            to: "Renamed Course",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let destination = try await store.createFolder(
            in: snapshot.rootNodeID,
            title: "Elsewhere",
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        _ = try await store.move(
            lectureID,
            to: destination.id,
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()
        let revisionBeforeRelink = snapshot.revision

        let receipt = try await store.replaceExternalResourceLocators(
            [
                LibraryExternalResourceRelinkDraft(
                    resourceID: syllabusResourceID,
                    locatorData: Data("new-syllabus".utf8),
                    lastKnownName: "Syllabus.md",
                    contentTypeIdentifier: "net.daringfireball.markdown",
                    origin: LibraryExternalResourceOrigin(
                        importID: importID,
                        relativePathComponents: ["Notes", "Syllabus.md"]
                    )
                ),
                LibraryExternalResourceRelinkDraft(
                    resourceID: lectureResourceID,
                    locatorData: Data("new-lecture".utf8),
                    lastKnownName: "lecture.pdf",
                    contentTypeIdentifier: "com.adobe.pdf",
                    origin: LibraryExternalResourceOrigin(
                        importID: importID,
                        relativePathComponents: ["lecture.pdf"]
                    )
                ),
            ],
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        XCTAssertEqual(snapshot.revision, revisionBeforeRelink + 1)
        XCTAssertEqual(Set(receipt.changedResourceIDs), Set([
            syllabusResourceID,
            lectureResourceID,
        ]))
        XCTAssertEqual(snapshot.entry(courseID)?.title, "Renamed Course")
        XCTAssertEqual(snapshot.entry(lectureID)?.parentID, destination.id)
        XCTAssertEqual(
            snapshot.entry(syllabusID)?.externalResource?.resourceID,
            syllabusResourceID
        )
        XCTAssertEqual(
            snapshot.entry(lectureID)?.externalResource?.resourceID,
            lectureResourceID
        )
        XCTAssertEqual(
            snapshot.entry(syllabusID)?.externalResource?.origin,
            LibraryExternalResourceOrigin(
                importID: importID,
                relativePathComponents: ["Notes", "Syllabus.md"]
            )
        )
        let relinkedSyllabus = try await store.readExternalResource(syllabusResourceID)
        let relinkedLecture = try await store.readExternalResource(lectureResourceID)
        XCTAssertEqual(
            relinkedSyllabus.locatorData,
            Data("new-syllabus".utf8)
        )
        XCTAssertEqual(
            relinkedLecture.locatorData,
            Data("new-lecture".utf8)
        )
    }

    func testBatchRelinkRejectsPartialReplacementWithoutMutation() async throws {
        let root = libraryURL("BatchRelinkFailure")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let initial = try await store.snapshot()
        let importID = ImportID()
        let created = try await store.createExternalLinkedTree(
            in: initial.rootNodeID,
            drafts: [
                LibraryLinkedItemDraft(
                    parentDraftIndex: nil,
                    title: "Course",
                    kind: .folder
                ),
                LibraryLinkedItemDraft(
                    parentDraftIndex: 0,
                    title: "one.pdf",
                    kind: .file(
                        LibraryLinkedFileDraft(
                            locatorData: Data("old-one".utf8),
                            lastKnownName: "one.pdf",
                            contentTypeIdentifier: "com.adobe.pdf",
                            origin: LibraryExternalResourceOrigin(
                                importID: importID,
                                relativePathComponents: ["one.pdf"]
                            )
                        )
                    )
                ),
                LibraryLinkedItemDraft(
                    parentDraftIndex: 0,
                    title: "two.pdf",
                    kind: .file(
                        LibraryLinkedFileDraft(
                            locatorData: Data("old-two".utf8),
                            lastKnownName: "two.pdf",
                            contentTypeIdentifier: "com.adobe.pdf",
                            origin: LibraryExternalResourceOrigin(
                                importID: importID,
                                relativePathComponents: ["two.pdf"]
                            )
                        )
                    )
                ),
            ],
            expectedRevision: initial.revision
        )
        let before = try await store.snapshot()
        let firstResourceID = try XCTUnwrap(
            before.entry(created.receipt.createdNodeIDs[1])?.externalResource?.resourceID
        )

        do {
            _ = try await store.replaceExternalResourceLocators(
                [
                    LibraryExternalResourceRelinkDraft(
                        resourceID: firstResourceID,
                        locatorData: Data("new-one".utf8),
                        lastKnownName: "one.pdf",
                        contentTypeIdentifier: "com.adobe.pdf",
                        origin: LibraryExternalResourceOrigin(
                            importID: importID,
                            relativePathComponents: ["one.pdf"]
                        )
                    ),
                ],
                expectedRevision: before.revision
            )
            XCTFail("Expected partial batch relink to fail")
        } catch let error as LibraryStoreError {
            XCTAssertEqual(error, .invalidLinkedTree)
        }

        let unchanged = try await store.snapshot()
        let unchangedResource = try await store.readExternalResource(firstResourceID)
        XCTAssertEqual(unchanged.revision, before.revision)
        XCTAssertEqual(
            unchangedResource.locatorData,
            Data("old-one".utf8)
        )
        XCTAssertEqual(payloadFiles(in: root).count, 2)
    }

    func testStaleStoreGarbageCollectionKeepsNewerWriterLocator() async throws {
        let root = libraryURL("ExternalGarbageCollectionConcurrency")
        let staleStore = try await LibraryStore.create(at: root, title: "资料库")
        let writer = try await LibraryStore.open(at: root)
        let snapshot = try await writer.snapshot()
        let created = try await writer.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "新链接",
            kind: .file,
            locatorData: Data("newer-bookmark".utf8),
            lastKnownName: "source.pdf",
            expectedRevision: snapshot.revision
        )

        let removed = try await staleStore.collectGarbage()
        XCTAssertEqual(removed, 0)

        let reopened = try await LibraryStore.open(at: root)
        let resource = try await reopened.readExternalResource(created.resourceID)
        XCTAssertEqual(resource.locatorData, Data("newer-bookmark".utf8))
    }

    func testExternalResourceReadUsesLatestCoordinatedManifest() async throws {
        let root = libraryURL("ExternalCoordinatedRead")
        let first = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await first.snapshot()
        let created = try await first.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "链接",
            kind: .file,
            locatorData: Data("first-bookmark".utf8),
            lastKnownName: "first.pdf",
            expectedRevision: snapshot.revision
        )

        let second = try await LibraryStore.open(at: root)
        snapshot = try await second.snapshot()
        _ = try await second.replaceExternalResourceLocator(
            for: created.nodeID,
            locatorData: Data("second-bookmark".utf8),
            lastKnownName: "second.pdf",
            expectedRevision: snapshot.revision
        )

        let latest = try await first.readExternalResource(created.resourceID)
        XCTAssertEqual(latest.locatorData, Data("second-bookmark".utf8))
        XCTAssertEqual(latest.lastKnownName, "second.pdf")
    }

    func testSchemaV1MigratesTransactionallyToV2() async throws {
        let root = libraryURL("Migration")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "旧版文档",
            data: Data("legacy content".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let manifestURL = root.appendingPathComponent("manifest.json")
        let current = try LibraryStoreIO.decoder().decode(
            LibraryManifestV2.self,
            from: Data(contentsOf: manifestURL)
        )
        let legacy = LibraryManifestV1(
            formatIdentifier: LibraryManifestV1.formatIdentifier,
            layoutVersion: LibraryManifestV1.layoutVersion,
            schemaVersion: LibraryManifestV1.schemaVersion,
            libraryID: current.libraryID,
            revision: current.revision,
            lastTransactionID: current.lastTransactionID,
            rootNodeID: current.rootNodeID,
            createdAtUnixMilliseconds: current.createdAtUnixMilliseconds,
            modifiedAtUnixMilliseconds: current.modifiedAtUnixMilliseconds,
            nodes: current.nodes,
            trash: current.trash
        )
        try LibraryStoreIO.encoder().encode(legacy).write(to: manifestURL, options: .atomic)

        let migrated = try await LibraryStore.open(at: root)
        let migratedSnapshot = try await migrated.snapshot()
        let migratedHeader = try LibraryStoreIO.decoder().decode(
            LibraryManifestHeader.self,
            from: Data(contentsOf: manifestURL)
        )

        XCTAssertEqual(migratedHeader.schemaVersion, LibraryManifestV2.schemaVersion)
        XCTAssertEqual(migratedSnapshot.libraryID, snapshot.libraryID)
        XCTAssertEqual(migratedSnapshot.revision, snapshot.revision + 1)
        XCTAssertEqual(migratedSnapshot.entry(document.id)?.title, "旧版文档")
        let migratedDocument = try await migrated.readDocument(document.id)
        XCTAssertEqual(migratedDocument.text, "legacy content")

        let previousHeader = try LibraryStoreIO.decoder().decode(
            LibraryManifestHeader.self,
            from: Data(contentsOf: root.appendingPathComponent(".state/previous-manifest.json"))
        )
        XCTAssertEqual(previousHeader.schemaVersion, LibraryManifestV1.schemaVersion)
    }

    func testExternalLocatorCorruptionIsDetected() async throws {
        let root = libraryURL("ExternalCorruption")
        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        let created = try await store.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "链接",
            kind: .file,
            locatorData: Data("correct-bookmark".utf8),
            lastKnownName: "source.pdf",
            expectedRevision: snapshot.revision
        )
        let locator = try XCTUnwrap(payloadFiles(in: root).first)
        try Data("corrupt-bookmark".utf8).write(to: locator)

        do {
            _ = try await store.readExternalResource(created.resourceID)
            XCTFail("Expected locator integrity validation")
        } catch let error as LibraryStoreError {
            let objectID = try payloadObjectID(locator)
            XCTAssertTrue(
                error == .objectDigestMismatch(objectID)
                    || error == .objectSizeMismatch(objectID)
            )
        }
    }

    func testHTTPSLocatorMustBeCredentialFreeHTTPS() async throws {
        let store = try await LibraryStore.create(at: libraryURL("HTTPSValidation"), title: "资料库")
        let snapshot = try await store.snapshot()

        for invalid in [
            "http://example.com/resource",
            "https://user:password@example.com/resource",
            "not a URL",
        ] {
            do {
                _ = try await store.createExternalResourceLink(
                    in: snapshot.rootNodeID,
                    title: "非法链接",
                    kind: .https,
                    locatorData: Data(invalid.utf8),
                    lastKnownName: "example.com",
                    expectedRevision: snapshot.revision
                )
                XCTFail("Expected HTTPS locator validation for \(invalid)")
            } catch let error as LibraryStoreError {
                XCTAssertEqual(error, .invalidResourceLocator)
            }
        }
        let unchangedSnapshot = try await store.snapshot()
        XCTAssertEqual(unchangedSnapshot.revision, snapshot.revision)

        let valid = "https://example.com/resource?id=42"
        let created = try await store.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "有效链接",
            kind: .https,
            locatorData: Data(valid.utf8),
            lastKnownName: "example.com",
            expectedRevision: snapshot.revision
        )
        let storedResource = try await store.readExternalResource(created.resourceID)
        XCTAssertEqual(
            storedResource.locatorData,
            Data(valid.utf8)
        )
    }

    func testLibraryToolProviderPublishesCapabilityScopedDefinitionsAndSchemas() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolProviderCatalog"),
            title: "资料库"
        )
        let provider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(
                capabilities: [.readStructure, .readContent, .mutateStructure]
            )
        )

        XCTAssertEqual(LibraryToolProvider.providerID, "com.vitemis.kuzio.library-tools.v1")
        XCTAssertEqual(provider.definitions.map(\.name), LibraryToolName.allCases)
        XCTAssertTrue(provider.definitions.allSatisfy { !$0.description.isEmpty })

        for definition in provider.definitions {
            let schema = try XCTUnwrap(
                try JSONSerialization.jsonObject(
                    with: definition.encodedInputSchema()
                ) as? [String: Any]
            )
            XCTAssertEqual(schema["type"] as? String, "object")
            XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
            XCTAssertNotNil(schema["properties"] as? [String: Any])
            XCTAssertNotNil(schema["required"] as? [String])
        }

        let createDefinition = try XCTUnwrap(
            provider.definitions.first(where: { $0.name == .createFolder })
        )
        let createSchema = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: createDefinition.encodedInputSchema()
            ) as? [String: Any]
        )
        XCTAssertEqual(
            Set(try XCTUnwrap(createSchema["required"] as? [String])),
            ["parent_node_id", "title", "expected_revision"]
        )
        let createProperties = try XCTUnwrap(
            createSchema["properties"] as? [String: Any]
        )
        let indexSchema = try XCTUnwrap(
            createProperties["index"] as? [String: Any]
        )
        XCTAssertEqual(indexSchema["type"] as? [String], ["integer", "null"])
        XCTAssertEqual(indexSchema["minimum"] as? Int, 0)

        let readOnlyProvider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readStructure])
        )
        XCTAssertEqual(
            readOnlyProvider.definitions.map(\.name),
            [.getState, .listChildren]
        )
    }

    func testLibraryToolProviderExecutesCompleteStructureWireSurface() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolProviderStructure"),
            title: "资料库"
        )
        let provider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(
                capabilities: [.readStructure, .mutateStructure]
            )
        )

        let initialResult = try await invoke(provider, .getState)
        guard case .success(let initialTool, .state(let initial)) = initialResult else {
            XCTFail("Expected provider state result")
            return
        }
        XCTAssertEqual(initialTool, .getState)

        let stateEnvelope = try jsonObject(initialResult.encodedJSON())
        XCTAssertEqual(stateEnvelope["ok"] as? Bool, true)
        XCTAssertEqual(stateEnvelope["tool"] as? String, LibraryToolName.getState.rawValue)
        let statePayload = try XCTUnwrap(stateEnvelope["result"] as? [String: Any])
        XCTAssertEqual(statePayload["library_id"] as? String, initial.libraryID.description)
        let rootPayload = try XCTUnwrap(statePayload["root"] as? [String: Any])
        XCTAssertEqual(rootPayload["node_id"] as? String, initial.root.nodeID.description)
        XCTAssertTrue(rootPayload["parent_node_id"] is NSNull)
        XCTAssertTrue(rootPayload["resource_id"] is NSNull)

        let firstCreationResult = try await invoke(
            provider,
            .createFolder,
            arguments: [
                "parent_node_id": initial.root.nodeID.description,
                "title": "待整理",
                "index": NSNull(),
                "expected_revision": initial.revision,
            ]
        )
        guard case .success(_, .mutation(let firstCreation)) = firstCreationResult else {
            XCTFail("Expected first provider folder creation")
            return
        }
        let firstFolderID = try XCTUnwrap(firstCreation.primaryNodeID)

        let secondCreationResult = try await invoke(
            provider,
            .createFolder,
            arguments: [
                "parent_node_id": initial.root.nodeID.description,
                "title": "目标",
                "expected_revision": firstCreation.revision,
            ]
        )
        guard case .success(_, .mutation(let secondCreation)) = secondCreationResult else {
            XCTFail("Expected second provider folder creation")
            return
        }
        let secondFolderID = try XCTUnwrap(secondCreation.primaryNodeID)

        let renameResult = try await invoke(
            provider,
            .renameNode,
            arguments: [
                "node_id": firstFolderID.description,
                "title": "已整理",
                "expected_revision": secondCreation.revision,
            ]
        )
        guard case .success(_, .mutation(let renamed)) = renameResult else {
            XCTFail("Expected provider rename")
            return
        }

        let moveResult = try await invoke(
            provider,
            .moveNode,
            arguments: [
                "node_id": firstFolderID.description,
                "destination_parent_node_id": secondFolderID.description,
                "expected_revision": renamed.revision,
            ]
        )
        guard case .success(_, .mutation(let moved)) = moveResult else {
            XCTFail("Expected provider move")
            return
        }

        let childrenResult = try await invoke(
            provider,
            .listChildren,
            arguments: ["parent_node_id": secondFolderID.description]
        )
        guard case .success(_, .children(let destinationChildren)) = childrenResult else {
            XCTFail("Expected provider children result")
            return
        }
        XCTAssertEqual(destinationChildren.revision, moved.revision)
        XCTAssertEqual(destinationChildren.children.map(\.nodeID), [firstFolderID])
        XCTAssertEqual(destinationChildren.children.first?.title, "已整理")

        let trashResult = try await invoke(
            provider,
            .trashNode,
            arguments: [
                "node_id": firstFolderID.description,
                "expected_revision": moved.revision,
            ]
        )
        guard case .success(_, .mutation(let trashed)) = trashResult else {
            XCTFail("Expected provider trash")
            return
        }

        let trashedStateResult = try await invoke(provider, .getState)
        guard case .success(_, .state(let trashedState)) = trashedStateResult else {
            XCTFail("Expected provider state after trash")
            return
        }
        XCTAssertEqual(trashedState.trash.map(\.nodeID), [firstFolderID])

        let restoreResult = try await invoke(
            provider,
            .restoreNode,
            arguments: [
                "node_id": firstFolderID.description,
                "destination_parent_node_id": initial.root.nodeID.description,
                "index": NSNull(),
                "expected_revision": trashed.revision,
            ]
        )
        guard case .success(_, .mutation(let restored)) = restoreResult else {
            XCTFail("Expected provider restore")
            return
        }

        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.revision, restored.revision)
        XCTAssertEqual(snapshot.entry(firstFolderID)?.parentID, initial.root.nodeID)
        XCTAssertEqual(snapshot.entry(firstFolderID)?.title, "已整理")

        let mutationEnvelope = try jsonObject(restoreResult.encodedJSON())
        let mutationPayload = try XCTUnwrap(
            mutationEnvelope["result"] as? [String: Any]
        )
        XCTAssertTrue(mutationPayload["primary_node_id"] is NSNull)
        XCTAssertEqual(
            (mutationPayload["revision"] as? NSNumber)?.uint64Value,
            restored.revision
        )
    }

    func testLibraryToolProviderReadsContentWithWireDefaults() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolProviderContent"),
            title: "资料库"
        )
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "正文",
            data: Data("Hello 世界".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let provider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readContent])
        )
        let result = try await invoke(
            provider,
            .readContent,
            arguments: ["node_id": document.id.description]
        )
        guard case .success(let tool, .content(let content)) = result else {
            XCTFail("Expected provider content result")
            return
        }
        XCTAssertEqual(tool, .readContent)
        XCTAssertEqual(content.revision, snapshot.revision)
        XCTAssertEqual(content.byteOffset, 0)
        XCTAssertEqual(content.text, "Hello 世界")
        XCTAssertNil(content.nextByteOffset)

        let envelope = try jsonObject(result.encodedJSON())
        let payload = try XCTUnwrap(envelope["result"] as? [String: Any])
        XCTAssertEqual(payload["node_id"] as? String, document.id.description)
        XCTAssertEqual((payload["byte_offset"] as? NSNumber)?.uint64Value, 0)
        XCTAssertTrue(payload["content_type_identifier"] is NSNull)
        XCTAssertTrue(payload["next_byte_offset"] is NSNull)
    }

    func testLibraryToolProviderRejectsUnknownExtraMalformedAndUnauthorizedCalls() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolProviderValidation"),
            title: "资料库"
        )
        let initial = try await store.snapshot()
        let provider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readStructure])
        )

        let unknown = await provider.execute(
            LibraryToolInvocation(name: "library_missing")
        )
        guard case .failure(let unknownTool, let unknownError) = unknown else {
            XCTFail("Expected unknown-tool failure")
            return
        }
        XCTAssertEqual(unknownTool, "library_missing")
        XCTAssertEqual(unknownError.code, .invalidArguments)
        XCTAssertEqual(unknownError.argument, "name")

        let extra = try await invoke(
            provider,
            .getState,
            arguments: ["unexpected": true]
        )
        guard case .failure(_, let extraError) = extra else {
            XCTFail("Expected extra-argument failure")
            return
        }
        XCTAssertEqual(extraError.code, .invalidArguments)
        XCTAssertEqual(extraError.argument, "unexpected")

        let malformedID = try await invoke(
            provider,
            .listChildren,
            arguments: [
                "parent_node_id": initial.rootNodeID.description.uppercased(),
            ]
        )
        guard case .failure(_, let malformedIDError) = malformedID else {
            XCTFail("Expected canonical-ID failure")
            return
        }
        XCTAssertEqual(malformedIDError.code, .invalidArguments)
        XCTAssertEqual(malformedIDError.argument, "parent_node_id")

        let unauthorized = await provider.execute(
            LibraryToolInvocation(
                name: LibraryToolName.createFolder.rawValue,
                argumentsJSON: Data("{}".utf8)
            )
        )
        guard case .failure(_, let unauthorizedError) = unauthorized else {
            XCTFail("Expected capability failure")
            return
        }
        XCTAssertEqual(unauthorizedError.code, .permissionDenied)

        let oversized = await provider.execute(
            LibraryToolInvocation(
                name: LibraryToolName.getState.rawValue,
                argumentsJSON: Data(
                    repeating: 0x20,
                    count: LibraryToolProvider.maximumArgumentsJSONBytes + 1
                )
            )
        )
        guard case .failure(_, let oversizedError) = oversized else {
            XCTFail("Expected oversized-argument failure")
            return
        }
        XCTAssertEqual(oversizedError.code, .invalidArguments)
        XCTAssertEqual(oversizedError.argument, "arguments")

        let failureEnvelope = try jsonObject(unauthorized.encodedJSON())
        XCTAssertEqual(failureEnvelope["ok"] as? Bool, false)
        XCTAssertNil(failureEnvelope["result"])
        let errorPayload = try XCTUnwrap(
            failureEnvelope["error"] as? [String: Any]
        )
        XCTAssertEqual(errorPayload["code"] as? String, "permission_denied")

        let unchanged = try await store.snapshot()
        XCTAssertEqual(unchanged.revision, initial.revision)
        XCTAssertTrue(unchanged.children(of: initial.rootNodeID).isEmpty)
    }

    func testToolControlPlaneReadsAndMutatesVirtualStructure() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolControlPlaneStructure"),
            title: "资料库"
        )
        let controlPlane = LibraryToolControlPlane(
            store: store,
            authorization: LibraryToolAuthorization(
                capabilities: [.readStructure, .mutateStructure]
            )
        )

        guard case .success(.state(let initial)) = await controlPlane.execute(.getState) else {
            XCTFail("Expected library state")
            return
        }

        guard case .success(.mutation(let firstCreation)) = await controlPlane.execute(
            .createFolder(
                parentNodeID: initial.root.nodeID,
                title: "待整理",
                index: nil,
                expectedRevision: initial.revision
            )
        ) else {
            XCTFail("Expected first folder creation")
            return
        }
        let firstFolderID = try XCTUnwrap(firstCreation.primaryNodeID)

        guard case .success(.mutation(let secondCreation)) = await controlPlane.execute(
            .createFolder(
                parentNodeID: initial.root.nodeID,
                title: "目标",
                index: nil,
                expectedRevision: firstCreation.revision
            )
        ) else {
            XCTFail("Expected second folder creation")
            return
        }
        let secondFolderID = try XCTUnwrap(secondCreation.primaryNodeID)

        guard case .success(.mutation(let renamed)) = await controlPlane.execute(
            .renameNode(
                nodeID: firstFolderID,
                title: "已整理",
                expectedRevision: secondCreation.revision
            )
        ) else {
            XCTFail("Expected rename")
            return
        }

        guard case .success(.mutation(let moved)) = await controlPlane.execute(
            .moveNode(
                nodeID: firstFolderID,
                destinationParentNodeID: secondFolderID,
                index: nil,
                expectedRevision: renamed.revision
            )
        ) else {
            XCTFail("Expected move")
            return
        }

        guard case .success(.children(let destinationChildren)) = await controlPlane.execute(
            .listChildren(parentNodeID: secondFolderID)
        ) else {
            XCTFail("Expected destination children")
            return
        }
        XCTAssertEqual(destinationChildren.revision, moved.revision)
        XCTAssertEqual(destinationChildren.children.map(\.nodeID), [firstFolderID])
        XCTAssertEqual(destinationChildren.children.first?.title, "已整理")

        guard case .success(.mutation(let trashed)) = await controlPlane.execute(
            .trashNode(nodeID: firstFolderID, expectedRevision: moved.revision)
        ) else {
            XCTFail("Expected trash")
            return
        }
        guard case .success(.state(let trashedState)) = await controlPlane.execute(.getState) else {
            XCTFail("Expected state after trash")
            return
        }
        XCTAssertEqual(trashedState.revision, trashed.revision)
        XCTAssertEqual(trashedState.trash.map(\.nodeID), [firstFolderID])

        guard case .success(.mutation(let restored)) = await controlPlane.execute(
            .restoreNode(
                nodeID: firstFolderID,
                destinationParentNodeID: initial.root.nodeID,
                index: nil,
                expectedRevision: trashed.revision
            )
        ) else {
            XCTFail("Expected restore")
            return
        }
        guard case .success(.children(let rootChildren)) = await controlPlane.execute(
            .listChildren(parentNodeID: initial.root.nodeID)
        ) else {
            XCTFail("Expected root children")
            return
        }
        XCTAssertEqual(rootChildren.revision, restored.revision)
        XCTAssertEqual(Set(rootChildren.children.map(\.nodeID)), [firstFolderID, secondFolderID])
    }

    func testToolControlPlaneEnforcesCapabilitiesAndRevision() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolControlPlaneAuthorization"),
            title: "资料库"
        )
        let readOnly = LibraryToolControlPlane(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readStructure])
        )
        guard case .success(.state(let state)) = await readOnly.execute(.getState) else {
            XCTFail("Expected library state")
            return
        }

        guard case .failure(let denied) = await readOnly.execute(
            .createFolder(
                parentNodeID: state.root.nodeID,
                title: "不得创建",
                index: nil,
                expectedRevision: state.revision
            )
        ) else {
            XCTFail("Expected permission denial")
            return
        }
        XCTAssertEqual(denied.code, .permissionDenied)

        let mutating = LibraryToolControlPlane(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.mutateStructure])
        )
        guard case .failure(let conflict) = await mutating.execute(
            .createFolder(
                parentNodeID: state.root.nodeID,
                title: "过期调用",
                index: nil,
                expectedRevision: state.revision - 1
            )
        ) else {
            XCTFail("Expected revision conflict")
            return
        }
        XCTAssertEqual(conflict.code, .revisionConflict)
        XCTAssertEqual(conflict.expectedRevision, state.revision - 1)
        XCTAssertEqual(conflict.actualRevision, state.revision)

        guard case .failure(let invalidIndex) = await mutating.execute(
            .createFolder(
                parentNodeID: state.root.nodeID,
                title: "越界位置",
                index: 1,
                expectedRevision: state.revision
            )
        ) else {
            XCTFail("Expected invalid index")
            return
        }
        XCTAssertEqual(invalidIndex.code, .invalidArguments)
        XCTAssertEqual(invalidIndex.argument, "index")

        let unchanged = try await store.snapshot()
        XCTAssertEqual(unchanged.revision, state.revision)
        XCTAssertTrue(unchanged.children(of: state.root.nodeID).isEmpty)
    }

    func testToolControlPlaneReadsDocumentContentInUTF8Chunks() async throws {
        let store = try await LibraryStore.create(
            at: libraryURL("ToolControlPlaneDocumentRead"),
            title: "资料库"
        )
        var snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "正文",
            data: Data("Hello 世界".utf8),
            expectedRevision: snapshot.revision
        )
        snapshot = try await store.snapshot()

        let controlPlane = LibraryToolControlPlane(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readContent])
        )
        guard case .success(.content(let first)) = await controlPlane.execute(
            .readContent(nodeID: document.id, byteOffset: 0, maximumBytes: 8)
        ) else {
            XCTFail("Expected first content chunk")
            return
        }
        XCTAssertEqual(first.revision, snapshot.revision)
        XCTAssertEqual(first.text, "Hello ")
        XCTAssertEqual(first.nextByteOffset, 6)
        XCTAssertTrue(first.truncated)

        guard case .success(.content(let second)) = await controlPlane.execute(
            .readContent(
                nodeID: document.id,
                byteOffset: try XCTUnwrap(first.nextByteOffset),
                maximumBytes: 8
            )
        ) else {
            XCTFail("Expected second content chunk")
            return
        }
        XCTAssertEqual(second.text, "世界")
        XCTAssertNil(second.nextByteOffset)
        XCTAssertFalse(second.truncated)
    }

    func testToolControlPlaneReadsLinkedExternalTextThroughBookmark() async throws {
        let target = testDirectory.appendingPathComponent("linked-note.txt")
        try Data("linked content".utf8).write(to: target)
        let bookmark = try target.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.contentTypeKey, .nameKey],
            relativeTo: nil
        )

        let store = try await LibraryStore.create(
            at: libraryURL("ToolControlPlaneExternalRead"),
            title: "资料库"
        )
        let snapshot = try await store.snapshot()
        let link = try await store.createExternalResourceLink(
            in: snapshot.rootNodeID,
            title: "链接正文",
            kind: .file,
            locatorData: bookmark,
            lastKnownName: target.lastPathComponent,
            contentTypeIdentifier: "public.plain-text",
            expectedRevision: snapshot.revision
        )

        let controlPlane = LibraryToolControlPlane(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [.readContent])
        )
        guard case .success(.content(let content)) = await controlPlane.execute(
            .readContent(nodeID: link.nodeID, byteOffset: 0, maximumBytes: 64)
        ) else {
            XCTFail("Expected linked content")
            return
        }
        XCTAssertEqual(content.source, .resourceLink)
        XCTAssertEqual(content.contentTypeIdentifier, "public.plain-text")
        XCTAssertEqual(content.text, "linked content")
        XCTAssertEqual(content.totalByteCount, 14)
        XCTAssertFalse(content.truncated)

        try FileManager.default.removeItem(at: target)
        guard case .failure(let unavailable) = await controlPlane.execute(
            .readContent(nodeID: link.nodeID, byteOffset: 0, maximumBytes: 64)
        ) else {
            XCTFail("Expected unavailable external resource")
            return
        }
        XCTAssertEqual(unavailable.code, .resourceUnavailable)
    }

    private func libraryURL(_ name: String) -> URL {
        testDirectory.appendingPathComponent("\(name).kuzio", isDirectory: true)
    }

    private func invoke(
        _ provider: LibraryToolProvider,
        _ name: LibraryToolName,
        arguments: [String: Any] = [:]
    ) async throws -> LibraryToolProviderResult {
        let argumentsJSON = try JSONSerialization.data(
            withJSONObject: arguments,
            options: [.sortedKeys]
        )
        return await provider.execute(
            LibraryToolInvocation(
                name: name.rawValue,
                argumentsJSON: argumentsJSON
            )
        )
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
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
