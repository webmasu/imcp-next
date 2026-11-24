import Foundation
import OSLog
import SQLite3

/// Each transition commits before the corresponding Mail event. A terminated sender
/// leaves an indeterminate record that a second process cannot claim again.
actor MailSchedule {
    static let shared = MailSchedule()
    private let directory: URL
    private let changes = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
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
        changes.continuation.yield(())
        return id
    }

    static let statuses = ["pending", "cancelled", "accepted", "unconfirmed"]

    func list(status: String? = nil) throws -> [[String: String]] {
        if let status, !Self.statuses.contains(status) { throw ToolInputError("Unknown schedule status.") }
        let filter = status == nil ? "" : " WHERE status=?"
        return try query(
            "SELECT id, due, status, subject, detail FROM schedule" + filter + " ORDER BY due, id",
            status.map { [$0] } ?? []
        ).map { row in
            [
                "id": row[0], "scheduledTime": Date(timeIntervalSince1970: Double(row[1]) ?? 0).formatted(.iso8601),
                "status": row[2], "subject": row[3], "detail": row[4],
            ]
        }
    }

    func cancel(_ id: String) throws {
        _ = try change(["id": .string(id)], delete: false)
    }

    /// A single SQLite statement selects and changes only eligible records, even if delivery races it.
    func change(_ args: [String: Value], delete: Bool) throws -> [String] {
        let filter: String
        let parameters: [String]
        if let status = try args.optionalText("status") {
            guard args["id"] == nil, args["ids"] == nil,
                (delete ? ["cancelled", "accepted", "unconfirmed"].contains(status) : status == "pending")
            else { throw ToolInputError("Choose one eligible status or explicit ids.") }
            filter = "status=?"
            parameters = [status]
        } else {
            parameters = try args.selectedIDs()
            filter = "id IN (" + Array(repeating: "?", count: parameters.count).joined(separator: ",") + ")"
        }
        let operation =
            delete
            ? "DELETE FROM schedule WHERE status!='pending' AND payload IS NULL"
            : "UPDATE schedule SET status='cancelled', payload=NULL WHERE status='pending'"
        let rows = try query(operation + " AND " + filter + " RETURNING id", parameters)
        if args["id"] != nil, rows.isEmpty { throw ToolInputError("No eligible scheduled message with this id.") }
        if !rows.isEmpty { changes.continuation.yield(()) }
        return rows.map { $0[0] }
    }

    func run() async {
        let signal = changes.continuation
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in signal.yield(()) }
        let timer = DispatchSource.makeTimerSource()
        timer.setEventHandler { signal.yield(()) }
        timer.activate()
        defer {
            timer.cancel()
            NotificationCenter.default.removeObserver(observer)
        }
        signal.yield(())
        for await _ in changes.stream {
            timer.schedule(wallDeadline: .distantFuture)
            guard Self.deliveryEnabled() else { continue }
            do {
                while Self.deliveryEnabled(), try await deliverNext() { try Task.checkCancellation() }
                if let due = try query("SELECT MIN(due) FROM schedule WHERE status='pending'").first?.first.flatMap(
                    Double.init
                ),
                    Self.deliveryEnabled()
                {
                    // A wall-clock deadline also fires for overdue mail after system sleep.
                    let deadline = timespec(tv_sec: Int(due.rounded(.up)), tv_nsec: 0)
                    timer.schedule(wallDeadline: DispatchWallTime(timespec: deadline))
                }
            } catch is CancellationError { return } catch {
                log.error("Scheduled mail processing failed: \(error.localizedDescription)")
                timer.schedule(wallDeadline: .now() + .seconds(15))
            }
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
            guard time.count > 10, time.dropFirst(10).contains(where: { "Zz+-".contains($0) }),
                let date = ISO8601DateFormatter.lenientDate(fromISO8601String: time)
            else {
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
            inputSchema: .object(
                properties: ["status": .string(enum: MailSchedule.statuses.map { .string($0) })],
                additionalProperties: false
            ),
            annotations: .init(title: "List Scheduled Mail", readOnlyHint: true, openWorldHint: false)
        ) { args in
            try await MailSchedule.shared.list(status: args.optionalText("status"))
        }
    }

    var cancelScheduledMail: Tool {
        scheduledChange(delete: false)
    }

    var deleteScheduledMail: Tool {
        scheduledChange(delete: true)
    }

    private func scheduledChange(delete: Bool) -> Tool {
        let statuses = delete ? ["cancelled", "accepted", "unconfirmed"] : ["pending"]
        return Tool(
            name: delete ? "mail_scheduled_delete" : "mail_scheduled_cancel",
            description: delete
                ? "Delete finished schedule history by id, ids or status. Pending and in-flight records are protected."
                : "Cancel pending mail by id, ids or explicit pending status. A batch returns affected ids.",
            inputSchema: .object(
                properties: [
                    "id": .string(), "ids": .array(items: .string()),
                    "status": .string(enum: statuses.map { .string($0) }),
                ],
                additionalProperties: false
            ),
            annotations: .init(
                title: delete ? "Delete Mail Schedule History" : "Cancel Scheduled Mail",
                destructiveHint: true,
                openWorldHint: false
            )
        ) { args in
            let ids = try await MailSchedule.shared.change(args, delete: delete)
            return !delete && args["id"] != nil ? Value.bool(true) : .array(ids.map(Value.string))
        }
    }
}
