import JSONSchema

final class BusyContactsService: Service {
    static let shared = BusyContactsService()

    var tools: [Tool] {
        Tool(
            name: "busycontacts_list",
            description:
                "Read cards from BusyContacts on this Mac. Search by name, email or phone, or omit query to list every address book's cards. Use nextAfter as after with the same query to continue.",
            inputSchema: .object(
                properties: [
                    "query": .string(description: "Name, email address or phone number"),
                    "limit": .integer(
                        description: "Maximum cards per page",
                        default: .int(50),
                        minimum: 1,
                        maximum: 100
                    ),
                    "after": .integer(description: "Cursor returned by the previous page", minimum: 0),
                ],
                additionalProperties: false
            ),
            annotations: .init(title: "Find BusyContacts Cards", readOnlyHint: true, openWorldHint: false)
        ) { try await LocalScript.call("imcp-busycontacts", request: .object($0)) }
    }
}
