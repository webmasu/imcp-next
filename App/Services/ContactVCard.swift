import Contacts
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ContactVCard {
    static let maxPhotoBytes = 5 * 1024 * 1024
    static let fields = [
        CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey,
        CNContactPreviousFamilyNameKey, CNContactNameSuffixKey, CNContactNicknameKey, CNContactTypeKey,
        CNContactOrganizationNameKey, CNContactDepartmentNameKey, CNContactJobTitleKey,
        CNContactPhoneticGivenNameKey, CNContactPhoneticMiddleNameKey, CNContactPhoneticFamilyNameKey,
        CNContactPhoneticOrganizationNameKey, CNContactBirthdayKey, CNContactNonGregorianBirthdayKey,
        CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey,
        CNContactDatesKey, CNContactUrlAddressesKey, CNContactRelationsKey,
        CNContactSocialProfilesKey, CNContactInstantMessageAddressesKey, CNContactImageDataKey,
    ]

    private static func lines(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var result = [String]()
        for line in normalized.components(separatedBy: "\n") {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !result.isEmpty {
                result[result.count - 1] += line.dropFirst()
            } else if !line.isEmpty {
                result.append(line)
            }
        }
        return result
    }

    private static func name(_ line: String) -> String {
        let header = line.prefix { $0 != ";" && $0 != ":" }
        return String(header.split(separator: ".").last ?? header).uppercased()
    }

    static func parse(_ input: Value?) throws -> CNMutableContact {
        guard case let .string(text) = input, text.utf8.count <= 9 * 1024 * 1024 else {
            throw LocalScriptError(message: "Provide one UTF-8 vCard of at most 9 MiB.")
        }
        let properties = lines(text)
        guard properties.first?.uppercased() == "BEGIN:VCARD", properties.last?.uppercased() == "END:VCARD",
            properties.filter({ name($0) == "BEGIN" || name($0) == "END" }).count == 2
        else { throw LocalScriptError(message: "Provide exactly one vCard.") }
        let photos = properties.filter { name($0) == "PHOTO" }
        guard photos.count <= 1 else { throw LocalScriptError(message: "Provide a single embedded photo.") }
        var photo: Data?
        if let line = photos.first, let split = line.firstIndex(of: ":") {
            var value = line[line.index(after: split)...]
            if value.prefix(5).lowercased() == "data:", let comma = value.firstIndex(of: ","),
                value[..<comma].lowercased().hasSuffix(";base64")
            {
                value = value[value.index(after: comma)...]
            }
            photo = try decodePhoto(String(value))
        } else if !photos.isEmpty {
            throw LocalScriptError(message: "Invalid PHOTO property.")
        }
        let body = properties.filter { name($0) != "PHOTO" }.joined(separator: "\r\n") + "\r\n"
        let cards = try CNContactVCardSerialization.contacts(with: Data(body.utf8))
        guard cards.count == 1, let card = cards[0].mutableCopy() as? CNMutableContact else {
            throw LocalScriptError(message: "Cannot decode this vCard.")
        }
        if let photo { card.imageData = photo }
        return card
    }

    static func dataForImport(_ value: Value?) throws -> Data {
        _ = try parse(value)
        guard let text = value?.stringValue else { throw LocalScriptError(message: "Provide one vCard.") }
        // The create tool must import a new identity even when its input came from a card export.
        let properties = lines(text).filter { !["UID", "REV", "X-ABUID"].contains(name($0)) }
        return Data((properties.map(folded).joined(separator: "\r\n") + "\r\n").utf8)
    }

    static func imageType(_ data: Data) throws -> UTType {
        guard !data.isEmpty, data.count <= maxPhotoBytes,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let identifier = CGImageSourceGetType(source), let type = UTType(identifier as String),
            type.conforms(to: .image), CGImageSourceGetStatus(source) == .statusComplete,
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, width <= 40_000_000 / height
        else { throw LocalScriptError(message: "Provide a complete image of at most 5 MiB and 40 megapixels.") }
        return type
    }

    static func decodePhoto(_ encoded: String) throws -> Data {
        guard encoded.utf8.count <= ((maxPhotoBytes + 2) / 3) * 4, let data = Data(base64Encoded: encoded) else {
            throw LocalScriptError(message: "Provide the image as base64 (up to 5 MiB decoded).")
        }
        _ = try imageType(data)
        return data
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    // Each physical line is at most 75 octets. Preserve complete UTF-8 scalars at fold points.
    private static func folded(_ line: String) -> String {
        let bytes = Array(line.utf8)
        var start = 0
        var parts = [String]()
        while start < bytes.count {
            var end = min(start + 74, bytes.count)
            while end < bytes.count && bytes[end] & 0xC0 == 0x80 { end -= 1 }
            parts.append(String(decoding: bytes[start ..< end], as: UTF8.self))
            start = end
        }
        return parts.joined(separator: "\r\n ")
    }

    static func nativeText(_ contact: CNMutableContact) throws -> String {
        // Serialize a new in-memory card. Fetching Apple's aggregate descriptor from the
        // store can include restricted keys, in particular contact notes.
        let copy = CNMutableContact()
        for key in fields where key != CNContactImageDataKey && contact.isKeyAvailable(key) {
            copy.setValue(contact.value(forKey: key), forKey: key)
        }
        let text = String(decoding: try CNContactVCardSerialization.data(with: [copy]), as: UTF8.self)
        return lines(text).filter { !["UID", "REV"].contains(name($0)) }.joined(separator: "\r\n")
    }

    static func export(native: String, link: [String: Value], photo: Data?) throws -> String {
        let extensions = (link["extensions"]?.arrayValue ?? []).compactMap(\.objectValue)
        let replaced = Set(["PHOTO", "UID", "NOTE", "CATEGORIES"]).union(
            extensions.compactMap { $0["name"]?.stringValue?.uppercased() }
        )
        var result = lines(native).filter { name($0) != "END" && !replaced.contains(name($0)) }
        if let uid = link["uid"]?.stringValue { result.append("UID:" + escaped(uid)) }
        if let note = link["note"]?.stringValue, !note.isEmpty { result.append("NOTE:" + escaped(note)) }
        let tags = (link["tags"]?.arrayValue ?? []).compactMap(\.stringValue)
        if !tags.isEmpty { result.append("CATEGORIES:" + tags.map(escaped).joined(separator: ",")) }
        for item in extensions {
            if let key = item["name"]?.stringValue, let value = item["value"]?.stringValue {
                result.append(key + ":" + escaped(value))
            }
        }
        if let photo {
            let type = try imageType(photo)
            let format = type.conforms(to: .jpeg) ? "JPEG" : (type.preferredFilenameExtension ?? "bin").uppercased()
            result.append("PHOTO;ENCODING=b;TYPE=" + format + ":" + photo.base64EncodedString())
        }
        result.append("END:VCARD")
        return result.map(folded).joined(separator: "\r\n") + "\r\n"
    }

    @discardableResult
    static func apply(_ args: [String: Value], to current: CNMutableContact, uid: String) throws -> Set<String> {
        var modified: Set<String> = []
        if args["vcard"] != nil || args["fields"] != nil {
            let edited = try parse(args["vcard"])
            if let text = args["vcard"]?.stringValue {
                for property in lines(text) where name(property) == "UID" {
                    guard let colon = property.firstIndex(of: ":"),
                        property[property.index(after: colon)...].caseInsensitiveCompare(escaped(uid)) == .orderedSame
                    else { throw LocalScriptError(message: "The vCard UID belongs to a different contact.") }
                }
            }
            guard case let .array(selection) = args["fields"], !selection.isEmpty else {
                throw LocalScriptError(message: "List the fields to copy from the vCard.")
            }
            for field in selection {
                guard case let .string(key) = field, fields.contains(key),
                    current.isKeyAvailable(key), edited.isKeyAvailable(key)
                else { throw LocalScriptError(message: "Unknown or unavailable contact field.") }
                if key == CNContactImageDataKey,
                    edited.imageData == nil || args["photoBase64"] != nil || args["removePhoto"] != nil
                {
                    throw LocalScriptError(message: "Select one photo source. To clear the image use removePhoto.")
                }
                current.setValue(edited.value(forKey: key), forKey: key)
                modified.insert(key)
            }
        }
        if let value = args["photoBase64"] {
            guard case let .string(encoded) = value, args["removePhoto"] == nil else {
                throw LocalScriptError(message: "Provide one base64 image or removePhoto.")
            }
            current.imageData = try decodePhoto(encoded)
            modified.insert(CNContactImageDataKey)
        } else if let remove = args["removePhoto"] {
            guard remove == .bool(true) else { throw LocalScriptError(message: "Use removePhoto=true or omit it.") }
            current.imageData = nil
            modified.insert(CNContactImageDataKey)
        } else if args["vcard"] == nil {
            throw LocalScriptError(message: "Provide a vCard and fields, a photo, or removePhoto=true.")
        }
        return modified
    }
}
