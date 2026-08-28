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

    func testLibraryToolsExposeOnlyReadSurfaceAndExecuteThroughProvider()
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
        ])
        XCTAssertFalse(bridge.toolNames.contains("library_create_folder"))

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
        XCTAssertNotNil(first.configuration.dynamicTools)
        XCTAssertTrue(first.configuration.pauseActiveGoalBeforeResume)
        XCTAssertEqual(
            first.configuration.hostApplicationIdentity,
            KuzioCodexRuntimeIntegration.applicationIdentity
        )
        XCTAssertEqual(first.sessionID, second.sessionID)
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
        XCTAssertTrue(instructions.contains("read-only"))
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

    func testMainSceneUsesSingleLibrarySplitAndIntatisSharedHarness() throws {
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
        XCTAssertTrue(harness.contains("import IntatisSharedUI"))
        XCTAssertTrue(harness.contains("struct KuzioCoworkHarnessHost"))
        XCTAssertTrue(harness.contains("CoworkShell("))
        XCTAssertTrue(harness.contains("IntatisThreadHeaderAction("))
        XCTAssertTrue(harness.contains("cowork.harness.intatis-shared-ui"))
        XCTAssertFalse(harness.contains("TextEditor("))
        XCTAssertFalse(harness.contains("ScrollView"))
        XCTAssertFalse(harness.contains("confirmationDialog("))
        XCTAssertFalse(harness.contains("KuzioCircleIconButton("))
        XCTAssertTrue(hostModel.contains("KuzioCoworkHarnessHostModel"))
        XCTAssertTrue(hostModel.contains("CoworkAgentThreadSnapshot"))
        XCTAssertTrue(hostModel.contains("CodeItem("))
        XCTAssertFalse(hostModel.contains("struct KuzioCoworkMessage"))
        XCTAssertFalse(hostModel.contains("struct KuzioCoworkActivity"))
        XCTAssertTrue(package.contains("IntatisConversation"))
        XCTAssertTrue(package.contains("IntatisSharedUI"))
        XCTAssertTrue(project.contains("product: IntatisConversation"))
        XCTAssertTrue(project.contains("product: IntatisSharedUI"))
        XCTAssertTrue(integration.contains(
            "IntatisHostApplication.configure(name: \"Kuzio\")"
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
            #"{"model":"fixture/fixture-model","provider":{"fixture":{"name":"Fixture","options":{"baseURL":"https://example.invalid/v1","apiKey":"fixture-token"},"models":{"fixture-model":{"name":"Fixture Model"}}}}}"#
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
