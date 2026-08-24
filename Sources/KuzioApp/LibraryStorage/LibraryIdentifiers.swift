import Foundation

private func decodeCanonicalUUID(from decoder: Decoder) throws -> UUID {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    guard let uuid = UUID(uuidString: value),
          uuid.uuidString.lowercased() == value else {
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected a canonical lowercase UUID."
        )
    }
    return uuid
}

private func encodeCanonicalUUID(_ uuid: UUID, to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(uuid.uuidString.lowercased())
}

struct LibraryID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decodeCanonicalUUID(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try encodeCanonicalUUID(rawValue, to: encoder)
    }

    var description: String { rawValue.uuidString.lowercased() }
}

struct NodeID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decodeCanonicalUUID(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try encodeCanonicalUUID(rawValue, to: encoder)
    }

    var description: String { rawValue.uuidString.lowercased() }
}

struct ObjectID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decodeCanonicalUUID(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try encodeCanonicalUUID(rawValue, to: encoder)
    }

    var description: String { rawValue.uuidString.lowercased() }
}

struct TransactionID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decodeCanonicalUUID(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try encodeCanonicalUUID(rawValue, to: encoder)
    }

    var description: String { rawValue.uuidString.lowercased() }
}
