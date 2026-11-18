import AppKit
import JSONSchema

final class BusyContactsService: Service {
    static let shared = BusyContactsService()
    static let createToolName = "busycontacts_create"
    static let createEnabledKey = "busyContactsCreateEnabled"

    static let updateToolName = "busycontacts_update"
    static let updateEnabledKey = "busyContactsUpdateEnabled"

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

        BusyContactTools.get
        BusyContactTools.photo
        BusyContactTools.update

        Tool(
            name: Self.createToolName,
            description:
                "Create a new BusyContacts card. Supply Quick Entry details and an optional addressBook, or one full vcard with an optional embedded photo. vCard import opens BusyContacts for the user to choose the destination and confirm. Check busycontacts_list before retrying.",
            inputSchema: .object(
                properties: [
                    "details": .string(
                        description: "Quick Entry text, for example a name followed by a phone number or email address"
                    ),
                    "vcard": .string(description: "One complete vCard to import in BusyContacts"),
                    "addressBook": .string(description: "Optional address book name hint for BusyContacts"),
                ],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Create Contacts",
                readOnlyHint: false,
                destructiveHint: false,
                idempotentHint: false,
                openWorldHint: true
            )
        ) { arguments in
            if let card = arguments["vcard"] {
                guard arguments["details"] == nil, arguments["addressBook"] == nil else {
                    throw LocalScriptError(message: "Use vcard alone, or details with an optional addressBook.")
                }
                return try await BusyContactImport.open(card)
            }
            guard case let .string(rawDetails) = arguments["details"] else {
                throw LocalScriptError(message: "Provide the contact details.")
            }
            var input = rawDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { throw LocalScriptError(message: "Provide the contact details.") }
            if let book = arguments["addressBook"] {
                guard case let .string(name) = book, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    throw LocalScriptError(message: "Provide an address book name or omit addressBook.")
                }
                input += " /" + name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return try await Self.createContact(input)
        }
    }

    @MainActor
    private static func createContact(_ input: String) async throws -> Value {
        guard UserDefaults.standard.bool(forKey: createEnabledKey) else {
            throw LocalScriptError(message: "Enable Create Contacts in Settings > BusyContacts.")
        }
        let unreserved = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        )
        guard let encoded = input.addingPercentEncoding(withAllowedCharacters: unreserved),
            let url = URL(string: "busycontacts://new/" + encoded)
        else { throw LocalScriptError(message: "Could not encode the contact details.") }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.busymac.busycontacts") else {
            throw LocalScriptError(message: "BusyContacts is not installed on this Mac.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        _ = try await NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
        return .object(["status": .string("submitted")])
    }
}
