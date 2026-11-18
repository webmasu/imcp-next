import Contacts
import CryptoKit
import Foundation

actor BusyContactStore {
    static let shared = BusyContactStore()
    private let store = CNContactStore()

    private func authorize() async throws {
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            _ = try await store.requestAccess(for: .contacts)
        }
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: break
        default:
            throw LocalScriptError(
                message: "Allow iMCP Next to access Contacts in System Settings > Privacy & Security."
            )
        }
    }

    private func resolve(_ id: Value?, includePhoto: Bool = false) async throws -> [String: Value] {
        guard case let .int(number) = id, number > 0 else {
            throw LocalScriptError(message: "Provide a positive id from busycontacts_list.")
        }
        let link = try await LocalScript.call(
            "imcp-contact-link",
            request: .object([
                "id": .int(number), "includePhoto": .bool(includePhoto),
            ])
        )
        guard let fields = link.objectValue, fields["identifier"]?.stringValue != nil,
            fields["revision"]?.stringValue != nil, fields["uid"]?.stringValue != nil
        else { throw LocalScriptError(message: "Invalid contact mapping.") }
        return fields
    }

    private func fetch(_ link: [String: Value]) throws -> CNMutableContact {
        let identifier = link["identifier"]!.stringValue!
        let keys: [CNKeyDescriptor] =
            [CNContactImageDataAvailableKey as CNKeyDescriptor]
            + (ContactVCard.fields as [CNKeyDescriptor])
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = false
        request.mutableObjects = true
        request.predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        var result: CNMutableContact?
        try store.enumerateContacts(with: request) { card, _ in
            if card.identifier == identifier { result = card as? CNMutableContact }
        }
        guard let result else {
            throw LocalScriptError(message: "The exact account contact is no longer available to iMCP Next.")
        }
        return result
    }

    private func revision(_ link: [String: Value], native: String, image: Data?) -> String {
        var hash = SHA256()
        hash.update(data: Data(link["revision"]!.stringValue!.utf8))
        hash.update(data: Data(native.utf8))
        if let image { hash.update(data: image) }
        return Data(hash.finalize()).base64EncodedString()
    }

    private func photo(_ link: [String: Value], contact: CNContact) throws -> Data? {
        if let encoded = link["photo"]?.stringValue { return try ContactVCard.decodePhoto(encoded) }
        if let photo = contact.imageData { return photo }
        if link["hasBusyPhoto"] == .bool(true) || contact.imageDataAvailable {
            throw LocalScriptError(
                message:
                    "The contact photo is not available locally. Let the account download it or use includePhoto=false."
            )
        }
        return nil
    }

    func get(_ args: [String: Value], photoOnly: Bool = false) async throws -> Value {
        try await authorize()
        let includePhoto = photoOnly || args["includePhoto"]?.boolValue != false
        let link = try await resolve(args["id"], includePhoto: includePhoto)
        let current = try fetch(link)
        let bytes = includePhoto ? try photo(link, contact: current) : nil
        if photoOnly {
            guard let bytes else { throw LocalScriptError(message: "This contact has no photo.") }
            let type = try ContactVCard.imageType(bytes)
            return .data(mimeType: type.preferredMIMEType ?? "application/octet-stream", bytes)
        }
        let native = try ContactVCard.nativeText(current)
        return .object([
            "id": args["id"]!,
            "revision": .string(revision(link, native: native, image: current.imageData)),
            "hasPhoto": .bool(bytes != nil || current.imageDataAvailable || link["hasBusyPhoto"] == .bool(true)),
            "vcard": .string(try ContactVCard.export(native: native, link: link, photo: bytes)),
            "busyContactsFields": .array((link["busyFields"]?.arrayValue ?? []).map(Self.fieldDetails)),
        ])
    }

    // BusyContacts also keeps provider-specific data that Apple's vCard exporter cannot represent.
    private static func fieldDetails(_ entry: Value) -> Value {
        guard var field = entry.objectValue, let attributes = field["attributes"]?.stringValue else { return entry }
        if let properties = try? PropertyListSerialization.propertyList(
            from: Data(("{\n" + attributes + "\n}").utf8),
            format: nil
        ) as? [String: String] {
            field["attributes"] = .object(properties.mapValues { .string($0) })
        }
        return .object(field)
    }

    func update(_ args: [String: Value]) async throws -> Value {
        let disabled = LocalScriptError(message: "Enable Update Contacts in Settings > BusyContacts.")
        guard UserDefaults.standard.bool(forKey: BusyContactsService.updateEnabledKey) else { throw disabled }
        guard let expected = args["revision"]?.stringValue, !expected.isEmpty else {
            throw LocalScriptError(message: "Read the card with busycontacts_get and supply its revision.")
        }
        try await authorize()
        let link = try await resolve(args["id"])
        let current = try fetch(link)
        let conflict = LocalScriptError(message: "The card changed. Read it again and review the edit.")
        guard revision(link, native: try ContactVCard.nativeText(current), image: current.imageData) == expected else {
            throw conflict
        }
        if args["removePhoto"] == .bool(true), link["hasBusyPhoto"] == .bool(true),
            !current.imageDataAvailable && current.imageData == nil
        {
            throw LocalScriptError(
                message: "The account has not loaded this BusyContacts photo. Sync before removing it."
            )
        }
        let modified = try ContactVCard.apply(args, to: current, uid: link["uid"]!.stringValue!)

        // Check both sync clients again after decoding a potentially large vCard or photo.
        // From the final fetch through execute there is no suspension between writes by this actor.
        let latest = try await resolve(args["id"])
        let fresh = try fetch(latest)
        guard revision(latest, native: try ContactVCard.nativeText(fresh), image: fresh.imageData) == expected else {
            throw conflict
        }
        guard UserDefaults.standard.bool(forKey: BusyContactsService.updateEnabledKey) else { throw disabled }
        let save = CNSaveRequest()
        save.transactionAuthor = "io.webmasu.iMCP.BusyContacts"
        for key in modified { fresh.setValue(current.value(forKey: key), forKey: key) }
        save.update(fresh)
        try store.execute(save)
        return .object(["id": args["id"]!, "status": .string("savedLocally"), "sync": .string("unconfirmed")])
    }
}
