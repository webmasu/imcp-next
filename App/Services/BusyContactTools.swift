import JSONSchema

enum BusyContactTools {
    static let get = Tool(
        name: "busycontacts_get",
        description:
            "Read a full vCard and its revision from a BusyContacts card in a shared macOS address book. Includes an embedded contact photo by default.",
        inputSchema: .object(
            properties: [
                "id": .integer(description: "Card ID from busycontacts_list", minimum: 1),
                "includePhoto": .boolean(description: "Include the original photo in the vCard", default: .bool(true)),
            ],
            required: ["id"],
            additionalProperties: false
        ),
        annotations: .init(title: "Read Contact Card", readOnlyHint: true, openWorldHint: false)
    ) { try await BusyContactStore.shared.get($0) }

    static let photo = Tool(
        name: "busycontacts_photo",
        description: "Read the image of a BusyContacts card in a shared macOS address book.",
        inputSchema: .object(
            properties: [
                "id": .integer(description: "Card ID from busycontacts_list", minimum: 1)
            ],
            required: ["id"],
            additionalProperties: false
        ),
        annotations: .init(title: "Read Contact Photo", readOnlyHint: true, openWorldHint: false)
    ) { try await BusyContactStore.shared.get($0, photoOnly: true) }

    static let update = Tool(
        name: BusyContactsService.updateToolName,
        description:
            "Edit one existing account-specific contact using the revision from busycontacts_get. Copy only the named fields from vcard. Supply the whole desired list for a multi-value field. A selected missing field clears it. For a photo-only edit use photoBase64 or removePhoto. A local save syncs through the account.",
        inputSchema: .object(
            properties: [
                "id": .integer(description: "Card ID from busycontacts_list", minimum: 1),
                "revision": .string(description: "Revision from the most recent busycontacts_get"),
                "vcard": .string(description: "One UTF-8 vCard with the desired values for fields"),
                "fields": .array(
                    description: "Fields to copy from vcard",
                    items: .string(enum: ContactVCard.fields.map { .string($0) })
                ),
                "photoBase64": .string(description: "A replacement image as raw base64, up to 5 MiB decoded"),
                "removePhoto": .boolean(description: "Set true to explicitly remove the photo"),
            ],
            required: ["id", "revision"],
            additionalProperties: false
        ),
        annotations: .init(
            title: "Update Contacts",
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: false,
            openWorldHint: true
        )
    ) { try await BusyContactStore.shared.update($0) }
}
