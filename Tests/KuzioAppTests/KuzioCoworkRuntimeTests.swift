import Foundation
import IntatisCodexRuntime
import IntatisCore
import IntatisProtocol
import XCTest
@testable import KuzioApp

final class KuzioCoworkRuntimeTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        let identity = try IntatisHostApplication.configure(name: "Kuzio")
        XCTAssertEqual(identity.name, "Kuzio")
        XCTAssertEqual(identity.storageName, "Kuzio")
        XCTAssertEqual(identity.environmentVariable("CONFIG"), "KUZIO_CONFIG")
        XCTAssertEqual(
            IntatisHostApplicationIdentity.intatis.environmentVariable("CONFIG"),
            "INTATIS_CONFIG"
        )
    }

    func testLibraryToolsExposeCompleteMinimalSurfaceAndExecuteThroughProvider()
        async throws
    {
        let root = temporaryRoot("tools")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try await LibraryStore.create(at: root, title: "资料库")
        let snapshot = try await store.snapshot()
        let document = try await store.createDocument(
            in: snapshot.rootNodeID,
            title: "Notes.md",
            data: Data("selected content".utf8),
            expectedRevision: snapshot.revision
        )
        let bridge = KuzioCodexLibraryTools(store: store)

        XCTAssertEqual(bridge.toolNames, [
            "library_get_state",
            "library_list_children",
            "library_read_content",
            "library_create_folder",
            "library_rename_node",
            "library_move_node",
            "library_trash_node",
            "library_restore_node",
        ])
        let dynamicTools = try bridge.dynamicTools()
        XCTAssertEqual(dynamicTools.toolsetID, KuzioCodexLibraryTools.toolsetID)
        XCTAssertEqual(dynamicTools.specs.map(\.name), bridge.toolNames)

        let result = await bridge.execute(
            name: "library_read_content",
            arguments: .object([
                "node_id": .string(document.id.description),
            ])
        )
        XCTAssertTrue(result.success)
        guard case .inputText(let text)? = result.contentItems.first,
              let data = text.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              object["ok"] as? Bool == true,
              let content = object["result"] as? [String: Any] else {
            return XCTFail("Expected a stable JSON success envelope.")
        }
        XCTAssertEqual(content["text"] as? String, "selected content")

        let creation = await bridge.execute(
            name: "library_create_folder",
            arguments: .object([
                "parent_node_id": .string(snapshot.rootNodeID.description),
                "title": .string("Organized"),
                "expected_revision": .number(Double(document.receipt.revision)),
            ])
        )
        XCTAssertTrue(creation.success)
        let mutated = try await store.snapshot()
        XCTAssertEqual(mutated.revision, document.receipt.revision + 1)
        XCTAssertEqual(
            mutated.children(of: snapshot.rootNodeID).map(\.title),
            ["Notes.md", "Organized"]
        )
    }

    func testRuntimeProfileResolvesSharedIntatisConfigurationWithoutLoggingCredential()
        async throws
    {
        let sourceURL = URL(fileURLWithPath: "/tmp/intatis-fixture.json")
        let route = try await KuzioCoworkRuntimeProfile.resolveRoute(
            configurationData: fixtureConfiguration,
            sourceURL: sourceURL,
            environment: [:]
        )

        XCTAssertEqual(route.endpointID, "fixture")
        XCTAssertEqual(route.model.rawValue, "fixture-model")
        XCTAssertEqual(route.baseURL.absoluteString, "https://example.invalid/v1")
        XCTAssertEqual(route.bearerToken, "fixture-token")
        XCTAssertFalse(route.description.contains("fixture-token"))
        XCTAssertFalse(route.debugDescription.contains("fixture-token"))
    }

    func testPreparedConversationUsesCoworkAndIndependentSelectedContext()
        async throws
    {
        let root = temporaryRoot("profile")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let configURL = root.appendingPathComponent("intatis.json")
        try fixtureConfiguration.write(to: configURL, options: .atomic)

        let libraryURL = root.appendingPathComponent("Library.kuzio")
        let store = try await LibraryStore.create(
            at: libraryURL,
            title: "资料库"
        )
        let tools = try KuzioCodexLibraryTools(store: store).dynamicTools()
        let nodeID = NodeID()
        let target = KuzioCoworkConversationTarget(
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            nodeID: nodeID,
            title: "Selected Folder",
            kind: .folder,
            virtualPath: ["资料库", "Selected Folder"]
        )
        let appSupport = root.appendingPathComponent(
            "Application Support",
            isDirectory: true
        )

        let first = try await KuzioCoworkRuntimeProfile.prepare(
            target: target,
            dynamicTools: tools,
            environment: ["INTATIS_CONFIG": configURL.path],
            homeDirectory: root,
            applicationSupportOverride: appSupport
        )
        let second = try await KuzioCoworkRuntimeProfile.prepare(
            target: target,
            dynamicTools: tools,
            environment: ["INTATIS_CONFIG": configURL.path],
            homeDirectory: root,
            applicationSupportOverride: appSupport
        )

        XCTAssertEqual(first.configuration.mode, .cowork)
        XCTAssertEqual(first.configuration.rootPermissionProfile, .reviewed)
        XCTAssertNotNil(first.configuration.dynamicTools)
        XCTAssertTrue(first.configuration.pauseActiveGoalBeforeResume)
        XCTAssertEqual(
            first.configuration.hostApplicationIdentity,
            KuzioCodexRuntimeIntegration.applicationIdentity
        )
        XCTAssertEqual(first.sessionID, second.sessionID)
        XCTAssertEqual(
            first.inferenceProfiles.map(\.modelID),
            ["fixture-model", "fixture-model-2"]
        )
        XCTAssertEqual(
            first.selectedInferenceBinding.modelID.rawValue,
            "fixture-model"
        )
        let alternate = try XCTUnwrap(
            first.inferenceProfiles.first {
                $0.modelID == "fixture-model-2"
            }
        )
        let alternateConfiguration = try first.configuration(
            for: alternate.binding
        )
        XCTAssertEqual(
            alternateConfiguration.route.model.rawValue,
            "fixture-model-2"
        )
        XCTAssertEqual(
            alternateConfiguration.dynamicTools?.toolsetID,
            KuzioCodexLibraryTools.toolsetID
        )
        XCTAssertEqual(
            alternateConfiguration.workspaceURL,
            first.configuration.workspaceURL
        )
        XCTAssertEqual(
            alternateConfiguration.runtimeRootURL,
            first.configuration.runtimeRootURL
        )
        XCTAssertEqual(
            first.configuration.runtimeRootURL,
            second.configuration.runtimeRootURL
        )
        XCTAssertTrue(first.configuration.workspaceURL.path.hasPrefix(
            appSupport.path
        ))
        XCTAssertTrue(first.configuration.workspaceURL.path.contains(
            "/Kuzio/CoworkSessions/"
        ))

        let instructionsURL = first.configuration.workspaceURL
            .appendingPathComponent("AGENTS.md")
        let instructions = try String(
            contentsOf: instructionsURL,
            encoding: .utf8
        )
        XCTAssertTrue(instructions.contains(nodeID.description))
        XCTAssertTrue(instructions.contains("Selected Folder"))
        XCTAssertTrue(instructions.contains("one minimal operation"))
        XCTAssertTrue(instructions.contains("revision_conflict"))
        XCTAssertFalse(instructions.contains("fixture-token"))
        XCTAssertFalse(instructions.contains(configURL.path))
    }

    func testConversationTargetRoundTripsVirtualIdentity() throws {
        let target = KuzioCoworkConversationTarget(
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            nodeID: NodeID(
                UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
            ),
            title: "Syllabus.md",
            kind: .resourceLink,
            virtualPath: ["资料库", "课程", "Syllabus.md"]
        )
        let data = try JSONEncoder().encode(target)
        let decoded = try JSONDecoder().decode(
            KuzioCoworkConversationTarget.self,
            from: data
        )
        XCTAssertEqual(decoded, target)
    }

    func testMainSceneUsesSingleLibrarySplitAndIntatisCoworkUI() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let app = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/KuzioApp.swift"
            ),
            encoding: .utf8
        )
        let root = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/LibraryRootView.swift"
            ),
            encoding: .utf8
        )
        let browser = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/LibraryBrowserView.swift"
            ),
            encoding: .utf8
        )
        let reader = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/LibraryReaderView.swift"
            ),
            encoding: .utf8
        )
        let harness = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/KuzioCoworkConversationView.swift"
            ),
            encoding: .utf8
        )
        let hostModel = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/KuzioCoworkConversationModel.swift"
            ),
            encoding: .utf8
        )
        let package = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Package.swift"
            ),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "project.yml"
            ),
            encoding: .utf8
        )
        let integration = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/KuzioCodexRuntimeIntegration.swift"
            ),
            encoding: .utf8
        )
        let profile = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/KuzioApp/KuzioCoworkRuntimeProfile.swift"
            ),
            encoding: .utf8
        )

        XCTAssertEqual(
            app.components(separatedBy: "WindowGroup").count - 1,
            1
        )
        XCTAssertTrue(app.contains("configureHost()"))
        XCTAssertFalse(app.contains("WindowGroup(\"AI 对话\""))
        XCTAssertTrue(root.contains("HSplitView"))
        XCTAssertTrue(root.contains("minWidth: 480"))
        XCTAssertTrue(root.contains("idealWidth: 720"))
        XCTAssertTrue(root.contains("minWidth: 440"))
        XCTAssertTrue(root.contains("idealWidth: 620"))
        XCTAssertTrue(root.contains("KuzioCoworkHarnessHost("))
        XCTAssertTrue(root.contains("cowork.harness.empty"))
        XCTAssertFalse(browser.contains("@Environment(\\.openWindow)"))
        XCTAssertFalse(reader.contains("@Environment(\\.openWindow)"))
        XCTAssertTrue(browser.contains("let onOpenCowork:"))
        XCTAssertTrue(reader.contains("let onOpenCowork:"))
        XCTAssertTrue(harness.contains("import IntatisCoworkUI"))
        XCTAssertTrue(harness.contains("struct KuzioCoworkHarnessHost"))
        XCTAssertTrue(harness.contains("IntatisCoworkContentView("))
        XCTAssertTrue(harness.contains("IntatisCoworkContentState("))
        XCTAssertTrue(harness.contains("IntatisCoworkContentActions("))
        XCTAssertTrue(harness.contains("cowork.harness.intatis-cowork-ui"))
        XCTAssertFalse(harness.contains("CoworkShell("))
        XCTAssertFalse(harness.contains("IntatisThreadHeaderAction("))
        XCTAssertFalse(harness.contains("closeAction"))
        XCTAssertFalse(harness.contains("systemImage: \"xmark\""))
        XCTAssertFalse(harness.contains("TextEditor("))
        XCTAssertFalse(harness.contains("ScrollView"))
        XCTAssertFalse(harness.contains("confirmationDialog("))
        XCTAssertFalse(harness.contains("KuzioCircleIconButton("))
        XCTAssertTrue(hostModel.contains("KuzioCoworkHarnessHostModel"))
        XCTAssertTrue(hostModel.contains("CoworkAgentThreadSnapshot"))
        XCTAssertTrue(hostModel.contains("IntatisCoworkThreadSource"))
        XCTAssertTrue(hostModel.contains("selectInferenceProfile"))
        XCTAssertTrue(hostModel.contains("CodeItem("))
        XCTAssertTrue(hostModel.contains("permissionProfile: \"reviewed\""))
        XCTAssertTrue(hostModel.contains("access: \"read_write\""))
        XCTAssertFalse(hostModel.contains("permissionProfile: \"read-only\""))
        XCTAssertFalse(hostModel.contains("struct KuzioCoworkMessage"))
        XCTAssertFalse(hostModel.contains("struct KuzioCoworkActivity"))
        XCTAssertTrue(package.contains("IntatisConversation"))
        XCTAssertTrue(package.contains("IntatisCoworkUI"))
        XCTAssertTrue(package.contains("IntatisSharedUI"))
        XCTAssertTrue(project.contains("product: IntatisConversation"))
        XCTAssertTrue(project.contains("product: IntatisCoworkUI"))
        XCTAssertTrue(project.contains("product: IntatisSharedUI"))
        XCTAssertTrue(integration.contains(
            "IntatisHostApplication.configure(name: \"Kuzio\")"
        ))
        XCTAssertTrue(integration.contains(
            "IntatisCoworkUIContract.publicAPIMajorVersion"
        ))
        XCTAssertTrue(profile.contains("hostApplicationIdentity:"))
        XCTAssertTrue(profile.contains("IntatisHostApplicationIdentity.intatis"))
        XCTAssertTrue(profile.contains("environmentVariable(\"CONFIG\")"))
        XCTAssertFalse(profile.contains("environment[\"INTATIS_CONFIG\"]"))
        XCTAssertTrue(app.contains(
            "IntatisTypography.prepareJetBrainsMonoTypography()"
        ))
    }

    private var fixtureConfiguration: Data {
        Data(
            #"{"model":"fixture/fixture-model","provider":{"fixture":{"name":"Fixture","options":{"baseURL":"https://example.invalid/v1","apiKey":"fixture-token"},"models":{"fixture-model":{"name":"Fixture Model"},"fixture-model-2":{"name":"Fixture Model 2"}}}}}"#
                .utf8
        )
    }

    private func temporaryRoot(_ suffix: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "Kuzio-Cowork-\(suffix)-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
    }
}
