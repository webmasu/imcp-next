import Foundation
import JSONSchema
import MCP
import Ontology

public struct Tool: Sendable {
    let name: String
    let description: String
    let annotations: MCP.Tool.Annotations
    private enum Implementation: Sendable {
        case local(JSONSchema, @Sendable ([String: Value]) async throws -> Value)
        case forwarded(MCP.Tool, @Sendable ([String: Value]) async throws -> CallTool.Result)
    }

    private let implementation: Implementation

    var definition: MCP.Tool {
        get throws {
            switch implementation {
            case .local(let schema, _):
                return try MCP.Tool(
                    name: name,
                    description: description,
                    inputSchema: Value(schema),
                    annotations: annotations
                )
            case .forwarded(let tool, _):
                return MCP.Tool(
                    name: name,
                    title: tool.title,
                    description: tool.description,
                    inputSchema: tool.inputSchema,
                    annotations: tool.annotations,
                    outputSchema: tool.outputSchema,
                    icons: tool.icons,
                    _meta: tool._meta
                )
            }
        }
    }

    init(
        forwarding upstream: MCP.Tool,
        prefix: String,
        call: @escaping @Sendable ([String: Value]) async throws -> CallTool.Result
    ) {
        name = prefix + upstream.name
        description = upstream.description ?? upstream.title ?? upstream.name
        annotations = upstream.annotations
        implementation = .forwarded(upstream, call)
    }

    func forwardedResult(_ input: [String: Value]) async throws -> CallTool.Result? {
        guard case .forwarded(_, let call) = implementation else { return nil }
        return try await call(input)
    }

    public init<T: Encodable>(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        annotations: MCP.Tool.Annotations,
        implementation: @Sendable @escaping ([String: Value]) async throws -> T
    ) {
        self.name = name
        self.description = description
        self.annotations = annotations
        self.implementation = .local(inputSchema) { input in
            let result = try await implementation(input)

            let encoder = JSONEncoder()
            encoder.userInfo[Ontology.DateTime.timeZoneOverrideKey] =
                TimeZone.current
            encoder.userInfo[JSONLD.omitsNestedTypesKey] = true
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

            let data = try encoder.encode(result)

            let decoder = JSONDecoder()
            return try decoder.decode(Value.self, from: data)
        }
    }

    public func callAsFunction(_ input: [String: Value]) async throws -> Value {
        switch implementation {
        case .local(_, let call): return try await call(input)
        case .forwarded(_, let call): return try await Value(call(input))
        }
    }
}

/// A JSON-LD document that lists values in `@graph` under one `@context`.
///
/// Return a list as a graph so that its values keep their Schema.org context
/// without each value repeating it.
public struct JSONLDGraph<Element: Encodable>: Encodable {
    /// The values in the graph.
    public var elements: [Element]

    /// Properties of the document that apply to every value, such as attribution.
    public var properties: [String: Value]

    public init(_ elements: [Element], properties: [String: Value] = [:]) {
        self.elements = elements
        self.properties = properties
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode("https://schema.org", forKey: Key("@context"))
        try container.encode(elements, forKey: Key("@graph"))
        for (key, value) in properties {
            try container.encode(value, forKey: Key(key))
        }
    }
}
