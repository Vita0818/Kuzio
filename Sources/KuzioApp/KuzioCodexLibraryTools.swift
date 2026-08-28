import Foundation
import IntatisCodexRuntime
import IntatisProtocol

struct KuzioCodexLibraryTools: Sendable {
    private let provider: LibraryToolProvider

    init(store: LibraryStore) {
        provider = LibraryToolProvider(
            store: store,
            authorization: LibraryToolAuthorization(capabilities: [
                .readStructure,
                .readContent,
            ])
        )
    }

    var toolNames: [String] {
        provider.definitions.map(\.name.rawValue)
    }

    func dynamicTools() throws -> CodexRuntimeDynamicTools {
        let specs = try provider.definitions.map { definition in
            CodexRuntimeDynamicToolSpec(
                name: definition.name.rawValue,
                description: definition.description,
                inputSchema: try JSONDecoder().decode(
                    JSONValue.self,
                    from: definition.encodedInputSchema()
                )
            )
        }
        let bridge = self
        return CodexRuntimeDynamicTools(
            toolsetID: LibraryToolProvider.providerID,
            specs: specs,
            handler: { call in
                await bridge.execute(
                    name: call.tool,
                    arguments: call.arguments
                )
            }
        )
    }

    func execute(
        name: String,
        arguments: JSONValue
    ) async -> CodexRuntimeDynamicToolResult {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let argumentsJSON = try encoder.encode(arguments)
            let result = await provider.execute(
                LibraryToolInvocation(
                    name: name,
                    argumentsJSON: argumentsJSON
                )
            )
            let resultJSON = try result.encodedJSON()
            guard let text = String(data: resultJSON, encoding: .utf8) else {
                return .text(
                    #"{"ok":false,"error":{"code":"encoding_failed"}}"#,
                    success: false
                )
            }
            return .text(text, success: result.isSuccess)
        } catch {
            return .text(
                #"{"ok":false,"error":{"code":"encoding_failed"}}"#,
                success: false
            )
        }
    }
}
