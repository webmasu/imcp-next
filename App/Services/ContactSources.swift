import Contacts
import Foundation
import Security

extension ContactsService {
    static let canWriteNote: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return (SecTaskCopyValueForEntitlement(task, "com.apple.developer.contacts.notes" as CFString, nil) as? Bool)
            == true
    }()

    var sourceCards: Tool {
        Tool(
            name: "contacts_source_cards",
            description:
                "List the individual account cards linked to an Apple contact. Use a returned pair of identifiers for contacts_delete.",
            inputSchema: .object(
                properties: ["identifier": .string()],
                required: ["identifier"],
                additionalProperties: false
            ),
            annotations: .init(title: "List Linked Contact Cards", readOnlyHint: true, openWorldHint: false)
        ) { args in
            let id = try args.requiredText("identifier")
            return try await self.runContactStore {
                let unified = try self.contactStore.unifiedContact(
                    withIdentifier: id,
                    keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
                )
                var cards: [[String: String]] = []
                for container in try self.contactStore.containers(matching: nil) {
                    let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                    request.predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                    request.unifyResults = false
                    try self.contactStore.enumerateContacts(with: request) { card, _ in
                        if unified.identifier == card.identifier
                            || unified.isUnifiedWithContact(withIdentifier: card.identifier)
                        {
                            cards.append([
                                "identifier": card.identifier, "containerIdentifier": container.identifier,
                                "container": container.name,
                            ])
                        }
                    }
                }
                return cards
            }
        }
    }

    var deleteCard: Tool {
        Tool(
            name: "contacts_delete",
            description:
                "Delete one Apple contact card in the specified account container. Obtain both identifiers from contacts_source_cards.",
            inputSchema: .object(
                properties: ["identifier": .string(), "containerIdentifier": .string()],
                required: ["identifier", "containerIdentifier"],
                additionalProperties: false
            ),
            annotations: .init(title: "Delete Contact Card", destructiveHint: true, openWorldHint: false)
        ) { args in
            let id = try args.requiredText("identifier")
            let container = try args.requiredText("containerIdentifier")
            return try await self.runContactStore {
                let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                request.predicate = CNContact.predicateForContactsInContainer(withIdentifier: container)
                request.mutableObjects = true
                request.unifyResults = false
                var target: CNMutableContact?
                try self.contactStore.enumerateContacts(with: request) { card, stop in
                    if card.identifier == id {
                        target = card as? CNMutableContact
                        stop.pointee = true
                    }
                }
                guard let target else { throw ToolInputError("No matching source card in that container.") }
                let save = CNSaveRequest()
                save.delete(target)
                try self.contactStore.execute(save)
                return true
            }
        }
    }

    static func populate(_ contact: CNMutableContact, from args: [String: Value]) throws {
        if let note = try args.optionalText("note") {
            guard canWriteNote else { throw ToolInputError("This build lacks Apple's Contacts notes entitlement.") }
            contact.note = note
        }
        contact.populate(from: args)
    }
}
