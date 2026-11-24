import Foundation
import OSLog
import SQLite3

/// Each transition commits before the corresponding Mail event. A terminated sender
/// leaves an indeterminate record that a second process cannot claim again.
actor MailSchedule {
    static let shared = MailSchedule()
    private let directory: URL
    private let log = Logger.service("mail-schedule")

    init(directory: URL? = nil) {
        self.directory =
            directory
            ?? URL.applicationSupportDirectory.appendingPathComponent("iMCP Next/Mail Schedule", isDirectory: true)
    }

    func enqueue(_ mail: OutgoingMail, at date: Date) throws -> String {
        guard date > .now else { throw ToolInputError("Schedule time must be in the future.") }
        let id = UUID().uuidString
        let payload = String(decoding: try JSONEncoder().encode(mail), as: UTF8.self)
        _ = try query(
            """
            INSERT INTO schedule (id, due, status, payload, subject) VALUES (?, ?, 'pending', ?, ?)
            """,
            [id, String(date.timeIntervalSince1970), payload, mail.subject],
            create: true
        )
        return id
    }

    func list() throws -> [[String: String]] {
        try query("SELECT id, due, status, subject, detail FROM schedule ORDER BY due, id").map { row in
            [
                "id": row[0], "scheduledTime": Date(timeIntervalSince1970: Double(row[1]) ?? 0).formatted(.iso8601),
                "status": row[2], "subject": row[3], "detail": row[4],
            ]
        }
    }

    func cancel(_ id: String) throws {
        let rows = try query(
            "UPDATE schedule SET status='cancelled', payload=NULL WHERE id=? AND status='pending' RETURNING id",
            [id]
        )
        guard rows.count == 1 else { throw ToolInputError("No pending message with this id.") }
    }

    func run() async {
        while !Task.isCancelled {
            do {
                while Self.deliveryEnabled(), try await deliverNext() { try Task.checkCancellation() }
            } catch is CancellationError { return } catch {
                log.error("Scheduled mail processing failed: \(error.localizedDescription)")
            }
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
        }
    }

    private static func deliveryEnabled() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "isEnabled") as? Bool != false, defaults.bool(forKey: "mailEnabled") else {
            return false
        }
        guard let data = defaults.data(forKey: "disabledTools") else { return true }
        guard let disabled = try? JSONDecoder().decode(Set<String>.self, from: data) else { return false }
        return disabled.isDisjoint(with: ["mail_send", "mail_schedule"])
    }

    func deliverNext(now: Date = .now, send: @Sendable (OutgoingMail) async throws -> Void = { try await $0.send() })
        async throws -> Bool
    {
        // Claim exactly once, including across app launches and concurrent processes.
        let rows = try query(
            """
            UPDATE schedule SET status='unconfirmed', detail='Delivery was started. Check Mail before resending.'
            WHERE id=(SELECT id FROM schedule WHERE status='pending' AND due<=?
                      ORDER BY due, id LIMIT 1) AND status='pending'
            RETURNING id, payload
            """,
            [String(now.timeIntervalSince1970)]
        )
        guard let row = rows.first else { return false }
        let id = row[0]
        do {
            let mail = try JSONDecoder().decode(OutgoingMail.self, from: Data(row[1].utf8))
            try await send(mail)
        } catch {
            _ = try query("UPDATE schedule SET payload=NULL, detail=? WHERE id=?", [String(describing: error), id])
            return true
        }
        _ = try query("UPDATE schedule SET status='accepted', payload=NULL, detail='' WHERE id=?", [id])
        return true
    }

    private func query(_ sql: String, _ arguments: [String] = [], create: Bool = false) throws -> [[String]] {
        let url = directory.appendingPathComponent("queue.sqlite")
        if create {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else if !FileManager.default.fileExists(atPath: url.path) {
            return []
        }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | (create ? SQLITE_OPEN_CREATE : 0)
        let status = sqlite3_open_v2(url.path, &db, flags, nil)
        defer { sqlite3_close(db) }
        guard status == SQLITE_OK else { throw ToolInputError("Could not open the mail schedule.") }
        sqlite3_busy_timeout(db, 1500)
        if create {
            _ = try ReadOnlyIndex.query(
                db,
                """
                CREATE TABLE IF NOT EXISTS schedule (id TEXT PRIMARY KEY, due REAL NOT NULL, status TEXT NOT NULL,
                    payload TEXT, subject TEXT NOT NULL, detail TEXT NOT NULL DEFAULT '')
                """
            )
        }
        return try ReadOnlyIndex.query(db, sql, parameters: arguments)
    }
}

extension MailService {
    var scheduleMail: Tool {
        var fields = OutgoingMail.fields
        fields["scheduledTime"] = .string(
            description: "ISO 8601 timestamp with explicit UTC offset or Z.",
            format: .dateTime
        )
        return Tool(
            name: "mail_schedule",
            description:
                "Queue mail for delivery while iMCP, Mail tools and sending are enabled. Overdue messages run on wake or next launch.",
            inputSchema: .object(
                properties: fields,
                required: ["to", "subject", "body", "scheduledTime"],
                additionalProperties: false
            ),
            annotations: .init(title: "Schedule Mail", destructiveHint: true, openWorldHint: true)
        ) { args in
            let time = try args.requiredText("scheduledTime")
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: time) ?? ISO8601DateFormatter().date(from: time) else {
                throw ToolInputError("Use an ISO 8601 timestamp with an explicit offset.")
            }
            let id = try await MailSchedule.shared.enqueue(OutgoingMail(args), at: date)
            return ["id": id, "status": "pending"]
        }
    }

    var listScheduledMail: Tool {
        Tool(
            name: "mail_scheduled_list",
            description: "List pending, cancelled, accepted and unconfirmed scheduled messages.",
            inputSchema: .object(properties: [:], additionalProperties: false),
            annotations: .init(title: "List Scheduled Mail", readOnlyHint: true, openWorldHint: false)
        ) { _ in
            try await MailSchedule.shared.list()
        }
    }

    var cancelScheduledMail: Tool {
        Tool(
            name: "mail_scheduled_cancel",
            description: "Cancel one pending message by its schedule id.",
            inputSchema: .object(properties: ["id": .string()], required: ["id"], additionalProperties: false),
            annotations: .init(title: "Cancel Scheduled Mail", destructiveHint: true, openWorldHint: false)
        ) { args in
            try await MailSchedule.shared.cancel(args.requiredText("id"))
            return true
        }
    }
}
