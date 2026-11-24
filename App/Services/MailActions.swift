import Envelope
import Foundation

extension MailService {
    var sendMail: Tool {
        Tool(
            name: "mail_send",
            description: "Send an email immediately through Apple Mail.",
            inputSchema: .object(
                properties: OutgoingMail.fields,
                required: ["to", "subject", "body"],
                additionalProperties: false
            ),
            annotations: .init(title: "Send Mail", destructiveHint: true, openWorldHint: true)
        ) { args in
            try await OutgoingMail(args).send()
            return ["acceptedByMail": true]
        }
    }

    var mailAccounts: Tool {
        Tool(
            name: "mail_accounts",
            description: "List Mail account identifiers, names, enabled status and sender addresses.",
            inputSchema: .object(properties: [:], additionalProperties: false),
            annotations: .init(title: "List Mail Accounts", readOnlyHint: true, openWorldHint: false)
        ) { _ in
            let list = try await NSAppleScript.execute(
                """
                tell application id "com.apple.mail"
                    set rows to {}
                    repeat with acct in accounts
                        set end of rows to {id of acct, name of acct, enabled of acct, email addresses of acct}
                    end repeat
                    return rows
                end tell
                """
            )
            return (0 ..< list.numberOfItems).compactMap { i -> Value? in
                guard let row = list.atIndex(i + 1), let id = row.atIndex(1)?.stringValue,
                    let addresses = row.atIndex(4)
                else { return nil }
                return [
                    "id": .string(id), "name": .string(row.atIndex(2)?.stringValue ?? ""),
                    "enabled": .bool(row.atIndex(3)?.booleanValue ?? false),
                    "addresses": .array(
                        (0 ..< addresses.numberOfItems).compactMap {
                            addresses.atIndex($0 + 1)?.stringValue.map(Value.string)
                        }
                    ),
                ]
            }
        }
    }

    var refreshMail: Tool {
        Tool(
            name: "mail_refresh",
            description:
                "Ask Mail to check for new messages, optionally for a particular account ID from mail_mailboxes_list.",
            inputSchema: .object(properties: ["account": .string()], additionalProperties: false),
            annotations: .init(title: "Refresh Mail", destructiveHint: false, openWorldHint: true)
        ) { args in
            _ = try await NSAppleScript.execute(
                """
                on performtask(accountID)
                    tell application id "com.apple.mail"
                        if accountID is "" then
                            check for new mail
                        else
                            set targetAccount to account id accountID
                            if account type of targetAccount is imap account then synchronize with targetAccount
                            check for new mail for targetAccount
                        end if
                    end tell
                end performtask
                """,
                arguments: [try args.optionalText("account") ?? ""]
            )
            return true
        }
    }

    var markMail: Tool {
        Tool(
            name: "mail_mark",
            description:
                "Set read status by id or ids from mail_messages_search. A batch reports the outcome per message.",
            inputSchema: .object(
                properties: ["id": .string(), "ids": .array(items: .string()), "isRead": .boolean()],
                required: ["isRead"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Mark Mail Read or Unread",
                destructiveHint: false,
                idempotentHint: true,
                openWorldHint: false
            )
        ) { args in
            guard let read = args["isRead"]?.boolValue else { throw ToolInputError("isRead is required.") }
            let ids = try args.selectedIDs().map { raw in
                guard let id = Envelope.Message.Identifier(raw) else {
                    throw ToolInputError("Invalid message id: \(raw)")
                }
                return id
            }
            // Resolve every stable identity in one snapshot before changing Mail.
            let targets = try await self.withStore { store in
                try await store.withSnapshot { snapshot in
                    let mailboxes = try snapshot.mailboxes()
                    return try ids.map { id in
                        let record = try snapshot.record(for: id)
                        let mailbox = mailboxes.first { $0.id.rowID == id.mailboxID }
                        let header = record.messageID.flatMap {
                            $0.contains("@") ? $0.trimmingCharacters(in: CharacterSet(charactersIn: "<>")) : nil
                        }
                        guard header != nil || mailbox?.account != nil else {
                            throw ToolInputError("Mail could not verify the account or message identity.")
                        }
                        return (id, header ?? "", mailbox?.account?.id ?? "")
                    }
                }
            }
            var outcomes: [Value] = []
            for (id, header, account) in targets {
                try Task.checkCancellation()
                do {
                    try await Self.setRead(read, row: String(id.rowID), header: header, account: account)
                    outcomes.append(.object(["id": .string(id.description), "updated": true]))
                } catch {
                    if args["ids"] == nil { throw error }
                    outcomes.append(
                        .object([
                            "id": .string(id.description), "updated": false,
                            "error": .string(error.localizedDescription),
                        ])
                    )
                }
            }
            return args["ids"] == nil ? Value.bool(true) : .array(outcomes)
        }
    }

    private static func setRead(_ read: Bool, row: String, header: String, account: String) async throws {
        _ = try await NSAppleScript.execute(
            """
            on locateMessage(boxes, rowNumber, headerID, newFlag)
                tell application id "com.apple.mail"
                    repeat with boxRef in boxes
                        set foundMessages to (messages of boxRef whose id is rowNumber)
                        if (count of foundMessages) is 1 then
                            set m to item 1 of foundMessages
                            if headerID is not "" and message id of m is not headerID then error "Message identity changed."
                            set read status of m to newFlag
                            return true
                        end if
                        if my locateMessage(mailboxes of boxRef, rowNumber, headerID, newFlag) then return true
                    end repeat
                end tell
                return false
            end locateMessage

            on performtask(rowText, headerID, flagText, accountID)
                set num to rowText as integer
                tell application id "com.apple.mail"
                    repeat with acct in accounts
                        if accountID is "" or id of acct is accountID then
                            if my locateMessage(mailboxes of acct, num, headerID, flagText is "true") then return true
                        end if
                    end repeat
                    if headerID is not "" then
                        if my locateMessage(mailboxes, num, headerID, flagText is "true") then return true
                    end if
                end tell
                error "The message is no longer available in Mail."
            end performtask
            """,
            arguments: [row, header, String(read), account]
        )
    }

    var readThread: Tool {
        Tool(
            name: "mail_thread",
            description:
                "Read a local Apple Mail conversation across mailboxes, including available message bodies. Pass nextAfter as after to continue.",
            inputSchema: .object(
                properties: [
                    "id": .string(), "after": .integer(minimum: 0), "limit": .integer(minimum: 1, maximum: 100),
                ],
                required: ["id"],
                additionalProperties: false
            ),
            annotations: .init(title: "Read Mail Conversation", readOnlyHint: true, openWorldHint: false)
        ) { args in
            guard let id = try Envelope.Message.Identifier(args.requiredText("id")) else {
                throw ToolInputError("Invalid message id.")
            }
            let after = args["after"]?.intValue ?? 0
            let limit = args["limit"]?.intValue ?? 30
            guard after >= 0, (1 ... 100).contains(limit) else { throw ToolInputError("Invalid page parameters.") }
            return try await self.withStore { store in
                let location = try store.location()
                guard id.store == location.versionURL.lastPathComponent else {
                    throw ToolInputError("Message belongs to another store.")
                }
                _ = try await store.record(for: id)
                let rows = try ReadOnlyIndex(url: location.indexURL).rows(
                    """
                    SELECT m.mailbox, m.ROWID FROM messages seed JOIN messages m
                    ON ((seed.conversation_id != 0 AND m.conversation_id = seed.conversation_id) OR m.ROWID = seed.ROWID)
                    WHERE seed.ROWID = ? AND seed.mailbox = ? AND m.deleted = 0 AND m.ROWID > CAST(? AS INTEGER)
                    ORDER BY m.ROWID LIMIT ?
                    """,
                    parameters: [String(id.rowID), String(id.mailboxID), String(after), String(limit + 1)]
                )
                var messages: [Value] = []
                for row in rows.prefix(limit) {
                    try Task.checkCancellation()
                    guard let member = Envelope.Message.Identifier("\(id.store):\(row[0]):\(row[1])") else {
                        throw ToolInputError("Invalid index row.")
                    }
                    do {
                        let content = try await store.readMessage(member) {
                            try Envelope.Content(emlx: $0.data, expectedMessageID: $0.message.messageID)
                        }
                        messages.append(content.value(for: member))
                    } catch is CancellationError { throw CancellationError() } catch {
                        var fields = (try? await store.record(for: member).value.objectValue) ?? [:]
                        fields["@id"] = .string(member.description)
                        fields["contentUnavailable"] = true
                        messages.append(.object(fields))
                    }
                }
                var result: [String: Value] = ["messages": .array(messages)]
                if rows.count > limit, let cursor = Int(rows[limit - 1][1]) { result["nextAfter"] = .int(cursor) }
                return Value.object(result)
            }
        }
    }
}
