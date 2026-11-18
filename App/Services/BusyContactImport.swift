import AppKit

enum BusyContactImport {
    private static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BusyContacts-Imports", isDirectory: true)
    }

    static func prune() {
        let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for file in files ?? [] where file.pathExtension == "vcf" {
            if let stamp = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                stamp.timeIntervalSinceNow < -86400
            {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    @MainActor
    static func open(_ value: Value) async throws -> Value {
        guard UserDefaults.standard.bool(forKey: BusyContactsService.createEnabledKey) else {
            throw LocalScriptError(message: "Enable Create Contacts in Settings > BusyContacts.")
        }
        let data = try ContactVCard.dataForImport(value)
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.busymac.busycontacts") else {
            throw LocalScriptError(message: "BusyContacts is not installed on this Mac.")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        prune()
        let file = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("vcf")
        guard fm.createFile(atPath: file.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw LocalScriptError(message: "Could not stage the vCard for import.")
        }
        do {
            _ = try await NSWorkspace.shared.open([file], withApplicationAt: app, configuration: .init())
        } catch {
            try? fm.removeItem(at: file)
            throw error
        }
        // Launch Services returns before BusyContacts necessarily reads the file or opens its import dialog.
        Task {
            try? await Task.sleep(for: .seconds(86400))
            try? fm.removeItem(at: file)
        }
        return .object([
            "status": .string("awaitingImport"),
            "action": .string("Choose the destination address book in BusyContacts and confirm the import."),
        ])
    }
}
