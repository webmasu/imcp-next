import Foundation
import JSONSchema
import OrderedCollections

final class ContactsJournalService: Service {
    static let shared = ContactsJournalService()

    var tools: [Tool] {
        tool("contacts", "Find Contacts Journal contacts by name or company. Returns local CRM contact IDs.")
        tool("logs", "Read this contact’s journal entries, newest first, including shared entries.")
        tool("todos", "Read this contact’s follow-ups, including shared tasks and completion dates.")
    }

    private func tool(_ action: String, _ description: String) -> Tool {
        var properties: OrderedDictionary<String, JSONSchema> = [
            "limit": .integer(minimum: 1, maximum: 100),
            "offset": .integer(description: "Previous nextOffset", minimum: 0),
        ]
        if action == "contacts" {
            properties["query"] = .string()
        } else {
            properties["contact_id"] = .integer(minimum: 1)
        }
        if action == "todos" { properties["open_only"] = .boolean(description: "Only return pending follow-ups.") }
        return Tool(
            name: "contactsjournal_" + action,
            description: description,
            inputSchema: .object(
                properties: properties,
                required: action == "contacts" ? [] : ["contact_id"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Contacts Journal " + action.capitalized,
                readOnlyHint: true,
                openWorldHint: false
            )
        ) { try await LocalScript.call("imcp-contactsjournal", arguments: [action], request: .object($0)) }
    }
}
