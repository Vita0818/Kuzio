import Foundation

struct LibraryToolDefinition: Equatable, Sendable {
    let name: LibraryToolName
    let description: String
    let inputSchema: LibraryToolInputSchema
    let requiredCapability: LibraryToolCapability

    func encodedInputSchema() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(inputSchema)
    }
}

struct LibraryToolInputSchema: Encodable, Equatable, Sendable {
    let type = "object"
    let properties: [String: LibraryToolInputProperty]
    let required: [String]
    let additionalProperties = false
}

struct LibraryToolInputProperty: Encodable, Equatable, Sendable {
    let type: LibraryToolInputType
    let description: String
    let pattern: String?
    let minimum: Int?
    let maximum: Int?
    let defaultValue: Int?
    let minLength: Int?

    init(
        type: LibraryToolInputType,
        description: String,
        pattern: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        defaultValue: Int? = nil,
        minLength: Int? = nil
    ) {
        self.type = type
        self.description = description
        self.pattern = pattern
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
        self.minLength = minLength
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case pattern
        case minimum
        case maximum
        case defaultValue = "default"
        case minLength
    }
}

struct LibraryToolInputType: Encodable, Equatable, Sendable {
    private let values: [String]

    static let string = Self(values: ["string"])
    static let integer = Self(values: ["integer"])
    static let nullableString = Self(values: ["string", "null"])
    static let nullableInteger = Self(values: ["integer", "null"])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if values.count == 1, let value = values.first {
            try container.encode(value)
        } else {
            try container.encode(values)
        }
    }
}

struct LibraryToolInvocation: Equatable, Sendable {
    let name: String
    let argumentsJSON: Data

    init(name: String, argumentsJSON: Data = Data("{}".utf8)) {
        self.name = name
        self.argumentsJSON = argumentsJSON
    }
}

enum LibraryToolProviderResult: Encodable, Sendable {
    case success(tool: LibraryToolName, output: LibraryToolOutput)
    case failure(tool: String, error: LibraryToolFailure)

    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case ok
        case tool
        case result
        case error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let tool, let output):
            try container.encode(true, forKey: .ok)
            try container.encode(tool.rawValue, forKey: .tool)
            let resultEncoder = container.superEncoder(forKey: .result)
            switch output {
            case .state(let value):
                try value.encode(to: resultEncoder)
            case .children(let value):
                try value.encode(to: resultEncoder)
            case .content(let value):
                try value.encode(to: resultEncoder)
            case .mutation(let value):
                try value.encode(to: resultEncoder)
            }

        case .failure(let tool, let error):
            try container.encode(false, forKey: .ok)
            try container.encode(tool, forKey: .tool)
            try container.encode(error, forKey: .error)
        }
    }
}

struct LibraryToolProvider: Sendable {
    static let providerID = "com.vitemis.kuzio.library-tools.v1"
    static let maximumArgumentsJSONBytes = 65_536

    let definitions: [LibraryToolDefinition]

    private let authorization: LibraryToolAuthorization
    private let controlPlane: LibraryToolControlPlane

    init(store: LibraryStore, authorization: LibraryToolAuthorization) {
        self.authorization = authorization
        self.controlPlane = LibraryToolControlPlane(
            store: store,
            authorization: authorization
        )
        self.definitions = Self.allDefinitions.filter {
            authorization.allows($0.requiredCapability)
        }
    }

    func execute(_ invocation: LibraryToolInvocation) async -> LibraryToolProviderResult {
        let responseToolName = Self.safeResponseToolName(invocation.name)
        guard let name = LibraryToolName(rawValue: invocation.name),
              let definition = Self.definitionsByName[name] else {
            return .failure(
                tool: responseToolName,
                error: LibraryToolFailure(code: .invalidArguments, argument: "name")
            )
        }
        guard authorization.allows(definition.requiredCapability) else {
            return .failure(
                tool: name.rawValue,
                error: LibraryToolFailure(code: .permissionDenied)
            )
        }

        let call: LibraryToolCall
        do {
            call = try Self.decodeCall(
                name: name,
                argumentsJSON: invocation.argumentsJSON
            )
        } catch let failure as LibraryToolFailure {
            return .failure(tool: name.rawValue, error: failure)
        } catch {
            return .failure(
                tool: name.rawValue,
                error: LibraryToolFailure(code: .invalidArguments)
            )
        }

        switch await controlPlane.execute(call) {
        case .success(let output):
            return .success(tool: name, output: output)
        case .failure(let error):
            return .failure(tool: name.rawValue, error: error)
        }
    }

    private static let canonicalUUIDPattern =
        "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

    private static let allDefinitions: [LibraryToolDefinition] = [
        LibraryToolDefinition(
            name: .getState,
            description: "Read the current Kuzio library identity, revision, root node, and trash roots.",
            inputSchema: objectSchema(),
            requiredCapability: .readStructure
        ),
        LibraryToolDefinition(
            name: .listChildren,
            description: "List the direct children of one virtual Kuzio folder in library order.",
            inputSchema: objectSchema(
                properties: [
                    "parent_node_id": nodeIDProperty(
                        "Canonical virtual folder node ID."
                    ),
                ],
                required: ["parent_node_id"]
            ),
            requiredCapability: .readStructure
        ),
        LibraryToolDefinition(
            name: .readContent,
            description: "Read a bounded UTF-8 content chunk from a Kuzio document or linked file.",
            inputSchema: objectSchema(
                properties: [
                    "node_id": nodeIDProperty(
                        "Canonical document or resource-link node ID."
                    ),
                    "byte_offset": LibraryToolInputProperty(
                        type: .integer,
                        description: "UTF-8 byte offset returned by the preceding chunk.",
                        minimum: 0,
                        defaultValue: 0
                    ),
                    "maximum_bytes": LibraryToolInputProperty(
                        type: .integer,
                        description: "Maximum bytes to read in this chunk.",
                        minimum: 4,
                        maximum: LibraryToolControlPlane.maximumContentReadBytes,
                        defaultValue: LibraryToolControlPlane.defaultContentReadBytes
                    ),
                ],
                required: ["node_id"]
            ),
            requiredCapability: .readContent
        ),
        LibraryToolDefinition(
            name: .createFolder,
            description: "Create an empty virtual folder under a virtual Kuzio folder.",
            inputSchema: objectSchema(
                properties: [
                    "parent_node_id": nodeIDProperty(
                        "Canonical destination virtual folder node ID."
                    ),
                    "title": titleProperty,
                    "index": optionalIndexProperty,
                    "expected_revision": expectedRevisionProperty,
                ],
                required: ["parent_node_id", "title", "expected_revision"]
            ),
            requiredCapability: .mutateStructure
        ),
        LibraryToolDefinition(
            name: .renameNode,
            description: "Rename a virtual Kuzio node without changing its identity or external target.",
            inputSchema: objectSchema(
                properties: [
                    "node_id": nodeIDProperty("Canonical virtual node ID."),
                    "title": titleProperty,
                    "expected_revision": expectedRevisionProperty,
                ],
                required: ["node_id", "title", "expected_revision"]
            ),
            requiredCapability: .mutateStructure
        ),
        LibraryToolDefinition(
            name: .moveNode,
            description: "Move a virtual Kuzio subtree under another virtual folder.",
            inputSchema: objectSchema(
                properties: [
                    "node_id": nodeIDProperty("Canonical virtual subtree root node ID."),
                    "destination_parent_node_id": nodeIDProperty(
                        "Canonical destination virtual folder node ID."
                    ),
                    "index": optionalIndexProperty,
                    "expected_revision": expectedRevisionProperty,
                ],
                required: [
                    "node_id",
                    "destination_parent_node_id",
                    "expected_revision",
                ]
            ),
            requiredCapability: .mutateStructure
        ),
        LibraryToolDefinition(
            name: .trashNode,
            description: "Move a virtual Kuzio subtree to the Kuzio trash without touching external targets.",
            inputSchema: objectSchema(
                properties: [
                    "node_id": nodeIDProperty("Canonical active virtual subtree root node ID."),
                    "expected_revision": expectedRevisionProperty,
                ],
                required: ["node_id", "expected_revision"]
            ),
            requiredCapability: .mutateStructure
        ),
        LibraryToolDefinition(
            name: .restoreNode,
            description: "Restore one Kuzio trash root to its original or an explicit virtual folder.",
            inputSchema: objectSchema(
                properties: [
                    "node_id": nodeIDProperty("Canonical trash-root node ID."),
                    "destination_parent_node_id": LibraryToolInputProperty(
                        type: .nullableString,
                        description: "Optional canonical destination virtual folder node ID.",
                        pattern: canonicalUUIDPattern
                    ),
                    "index": optionalIndexProperty,
                    "expected_revision": expectedRevisionProperty,
                ],
                required: ["node_id", "expected_revision"]
            ),
            requiredCapability: .mutateStructure
        ),
    ]

    private static let definitionsByName = Dictionary(
        uniqueKeysWithValues: allDefinitions.map { ($0.name, $0) }
    )

    private static let titleProperty = LibraryToolInputProperty(
        type: .string,
        description: "Virtual display title.",
        minLength: 1
    )

    private static let optionalIndexProperty = LibraryToolInputProperty(
        type: .nullableInteger,
        description: "Optional zero-based child index; omit or use null to append.",
        minimum: 0
    )

    private static let expectedRevisionProperty = LibraryToolInputProperty(
        type: .integer,
        description: "Most recently confirmed Kuzio library revision.",
        minimum: 0
    )

    private static func nodeIDProperty(_ description: String) -> LibraryToolInputProperty {
        LibraryToolInputProperty(
            type: .string,
            description: description,
            pattern: canonicalUUIDPattern
        )
    }

    private static func objectSchema(
        properties: [String: LibraryToolInputProperty] = [:],
        required: [String] = []
    ) -> LibraryToolInputSchema {
        LibraryToolInputSchema(
            properties: properties,
            required: required
        )
    }

    private static func decodeCall(
        name: LibraryToolName,
        argumentsJSON: Data
    ) throws -> LibraryToolCall {
        switch name {
        case .getState:
            _ = try decodeArguments(
                EmptyArguments.self,
                from: argumentsJSON,
                allowedKeys: [],
                requiredKeys: []
            )
            return .getState

        case .listChildren:
            let arguments = try decodeArguments(
                ListChildrenArguments.self,
                from: argumentsJSON,
                allowedKeys: ["parent_node_id"],
                requiredKeys: ["parent_node_id"]
            )
            return .listChildren(parentNodeID: arguments.parentNodeID)

        case .readContent:
            let arguments = try decodeArguments(
                ReadContentArguments.self,
                from: argumentsJSON,
                allowedKeys: ["node_id", "byte_offset", "maximum_bytes"],
                requiredKeys: ["node_id"]
            )
            return .readContent(
                nodeID: arguments.nodeID,
                byteOffset: arguments.byteOffset ?? 0,
                maximumBytes: arguments.maximumBytes
                    ?? LibraryToolControlPlane.defaultContentReadBytes
            )

        case .createFolder:
            let arguments = try decodeArguments(
                CreateFolderArguments.self,
                from: argumentsJSON,
                allowedKeys: ["parent_node_id", "title", "index", "expected_revision"],
                requiredKeys: ["parent_node_id", "title", "expected_revision"]
            )
            try validate(index: arguments.index)
            return .createFolder(
                parentNodeID: arguments.parentNodeID,
                title: arguments.title,
                index: arguments.index,
                expectedRevision: arguments.expectedRevision
            )

        case .renameNode:
            let arguments = try decodeArguments(
                RenameNodeArguments.self,
                from: argumentsJSON,
                allowedKeys: ["node_id", "title", "expected_revision"],
                requiredKeys: ["node_id", "title", "expected_revision"]
            )
            return .renameNode(
                nodeID: arguments.nodeID,
                title: arguments.title,
                expectedRevision: arguments.expectedRevision
            )

        case .moveNode:
            let arguments = try decodeArguments(
                MoveNodeArguments.self,
                from: argumentsJSON,
                allowedKeys: [
                    "node_id",
                    "destination_parent_node_id",
                    "index",
                    "expected_revision",
                ],
                requiredKeys: [
                    "node_id",
                    "destination_parent_node_id",
                    "expected_revision",
                ]
            )
            try validate(index: arguments.index)
            return .moveNode(
                nodeID: arguments.nodeID,
                destinationParentNodeID: arguments.destinationParentNodeID,
                index: arguments.index,
                expectedRevision: arguments.expectedRevision
            )

        case .trashNode:
            let arguments = try decodeArguments(
                TrashNodeArguments.self,
                from: argumentsJSON,
                allowedKeys: ["node_id", "expected_revision"],
                requiredKeys: ["node_id", "expected_revision"]
            )
            return .trashNode(
                nodeID: arguments.nodeID,
                expectedRevision: arguments.expectedRevision
            )

        case .restoreNode:
            let arguments = try decodeArguments(
                RestoreNodeArguments.self,
                from: argumentsJSON,
                allowedKeys: [
                    "node_id",
                    "destination_parent_node_id",
                    "index",
                    "expected_revision",
                ],
                requiredKeys: ["node_id", "expected_revision"]
            )
            try validate(index: arguments.index)
            return .restoreNode(
                nodeID: arguments.nodeID,
                destinationParentNodeID: arguments.destinationParentNodeID,
                index: arguments.index,
                expectedRevision: arguments.expectedRevision
            )
        }
    }

    private static func decodeArguments<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        allowedKeys: Set<String>,
        requiredKeys: Set<String>
    ) throws -> Value {
        guard data.count <= maximumArgumentsJSONBytes else {
            throw LibraryToolFailure(code: .invalidArguments, argument: "arguments")
        }

        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LibraryToolFailure(code: .invalidArguments, argument: "arguments")
            }
            object = decoded
        } catch let failure as LibraryToolFailure {
            throw failure
        } catch {
            throw LibraryToolFailure(code: .invalidArguments, argument: "arguments")
        }

        if let unknownKey = object.keys
            .filter({ !allowedKeys.contains($0) })
            .sorted()
            .first {
            throw LibraryToolFailure(code: .invalidArguments, argument: unknownKey)
        }
        if let missingKey = requiredKeys
            .filter({ object[$0] == nil })
            .sorted()
            .first {
            throw LibraryToolFailure(code: .invalidArguments, argument: missingKey)
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw LibraryToolFailure(
                code: .invalidArguments,
                argument: decodingArgument(from: error)
            )
        } catch {
            throw LibraryToolFailure(code: .invalidArguments)
        }
    }

    private static func decodingArgument(from error: DecodingError) -> String? {
        let codingPath: [CodingKey]
        switch error {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .dataCorrupted(let context):
            codingPath = context.codingPath
        case .keyNotFound(let key, let context):
            return key.stringValue.isEmpty
                ? context.codingPath.last?.stringValue
                : key.stringValue
        @unknown default:
            return nil
        }
        return codingPath.last?.stringValue
    }

    private static func validate(index: Int?) throws {
        guard index.map({ $0 >= 0 }) ?? true else {
            throw LibraryToolFailure(code: .invalidArguments, argument: "index")
        }
    }

    private static func safeResponseToolName(_ value: String) -> String {
        guard !value.isEmpty,
              value.utf8.count <= 128,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return "invalid_tool"
        }
        return value
    }
}

private struct EmptyArguments: Decodable {}

private struct ListChildrenArguments: Decodable {
    let parentNodeID: NodeID

    private enum CodingKeys: String, CodingKey {
        case parentNodeID = "parent_node_id"
    }
}

private struct ReadContentArguments: Decodable {
    let nodeID: NodeID
    let byteOffset: UInt64?
    let maximumBytes: Int?

    private enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case byteOffset = "byte_offset"
        case maximumBytes = "maximum_bytes"
    }
}

private struct CreateFolderArguments: Decodable {
    let parentNodeID: NodeID
    let title: String
    let index: Int?
    let expectedRevision: UInt64

    private enum CodingKeys: String, CodingKey {
        case parentNodeID = "parent_node_id"
        case title
        case index
        case expectedRevision = "expected_revision"
    }
}

private struct RenameNodeArguments: Decodable {
    let nodeID: NodeID
    let title: String
    let expectedRevision: UInt64

    private enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case title
        case expectedRevision = "expected_revision"
    }
}

private struct MoveNodeArguments: Decodable {
    let nodeID: NodeID
    let destinationParentNodeID: NodeID
    let index: Int?
    let expectedRevision: UInt64

    private enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case destinationParentNodeID = "destination_parent_node_id"
        case index
        case expectedRevision = "expected_revision"
    }
}

private struct TrashNodeArguments: Decodable {
    let nodeID: NodeID
    let expectedRevision: UInt64

    private enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case expectedRevision = "expected_revision"
    }
}

private struct RestoreNodeArguments: Decodable {
    let nodeID: NodeID
    let destinationParentNodeID: NodeID?
    let index: Int?
    let expectedRevision: UInt64

    private enum CodingKeys: String, CodingKey {
        case nodeID = "node_id"
        case destinationParentNodeID = "destination_parent_node_id"
        case index
        case expectedRevision = "expected_revision"
    }
}
