import Foundation
import JSONSchema
import OrderedCollections

enum ImsgToolCatalog {
    static let changesKey = "imsgAllowAdvancedChanges"

    private struct Operation: Decodable {
        let read: Bool
        let description: String
        let fields: [String]
        let required: [String]?
        let rpc: String?
    }

    private struct Catalog: Decodable {
        let fields: [String: [String]]
        let tools: [String: Operation]
    }

    private static let catalog: Catalog? = {
        guard let url = Bundle.main.url(forResource: "imsg-tools", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }()

    static var tools: [Tool] {
        guard let catalog else { return [] }
        let changes = UserDefaults.standard.bool(forKey: changesKey)
        return catalog.tools.keys.sorted().compactMap { key -> Tool? in
            guard let operation = catalog.tools[key], operation.read || changes else { return nil }
            var properties = OrderedDictionary<String, JSONSchema>()
            for field in operation.fields {
                guard let info = catalog.fields[field], info.count == 2 else { return nil }
                let description = info[1]
                switch info[0] {
                case "string": properties[field] = .string(description: description)
                case "boolean": properties[field] = .boolean(description: description)
                case "integer": properties[field] = .integer(description: description)
                case "number": properties[field] = .number(description: description)
                case "array": properties[field] = .array(description: description, items: .string())
                default: return nil
                }
            }
            if let method = operation.rpc {
                properties["native_params"] = .object(
                    description: "Use the native imsg RPC parameters for \(method) instead of CLI fields.",
                    properties: [:],
                    additionalProperties: true
                )
            }
            return Tool(
                name: "messages_" + key,
                description: operation.description,
                inputSchema: .object(
                    properties: properties,
                    required: operation.rpc == nil ? operation.required ?? [] : [],
                    additionalProperties: false
                ),
                annotations: .init(
                    title: "imsg " + key.replacingOccurrences(of: "_", with: " "),
                    readOnlyHint: operation.read,
                    destructiveHint: operation.read ? false : nil,
                    openWorldHint: !operation.read
                )
            ) { args in
                guard operation.read || UserDefaults.standard.bool(forKey: changesKey) else {
                    throw LocalScriptError(message: "Enable Advanced Sends and Changes in Settings > Messages.")
                }
                return try await ImsgConnection.current.call("catalog." + key, args)
            }
        }
    }
}
