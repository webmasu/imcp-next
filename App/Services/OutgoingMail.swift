import Foundation
import JSONSchema
import OrderedCollections

struct OutgoingMail: Codable, Sendable {
    let from: String?
    let to: [String]
    let cc: [String]
    let bcc: [String]
    let subject: String
    let body: String

    static let fields: OrderedDictionary<String, JSONSchema> = [
        "from": .string(description: "Sender email address configured in Mail. Defaults to Mail’s default sender."),
        "to": .array(items: .string()), "cc": .array(items: .string()), "bcc": .array(items: .string()),
        "subject": .string(), "body": .string(description: "Plain text message body."),
    ]
    init(_ args: [String: Value]) throws {
        func address(_ text: String) throws -> String {
            let parts = text.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
                text.rangeOfCharacter(
                    from: .whitespacesAndNewlines.union(.controlCharacters).union(CharacterSet(charactersIn: ",;<>"))
                ) == nil
            else { throw ToolInputError("Supply each recipient as a separate plain email address.") }
            return text
        }
        func addresses(_ key: String) throws -> [String] {
            guard let value = args[key] else { return [] }
            guard case .array(let entries) = value else {
                throw ToolInputError("\(key) must be an array of email addresses.")
            }
            return try entries.map {
                guard let text = $0.stringValue else { throw ToolInputError("Expected an email address.") }
                return try address(text)
            }
        }
        from = try args.optionalText("from").map(address)
        to = try addresses("to")
        cc = try addresses("cc")
        bcc = try addresses("bcc")
        guard !to.isEmpty else { throw ToolInputError("Supply at least one To recipient.") }
        subject = try args.requiredText("subject")
        guard subject.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw ToolInputError("Invalid subject.")
        }
        guard let text = try args.optionalText("body") else { throw ToolInputError("Supply a message body.") }
        body = text
    }

    func send() async throws {
        let result = try await NSAppleScript.execute(
            """
            on performtask(fromAddr, toLines, ccLines, bccLines, newSubject, newBody)
                tell application id "com.apple.mail"
                    if fromAddr is not "" then
                        set matchesCount to 0
                        repeat with acct in accounts
                            if enabled of acct and (email addresses of acct contains fromAddr) then set matchesCount to matchesCount + 1
                        end repeat
                        if matchesCount is not 1 then error "Sender must match one enabled Mail account."
                    end if
                    set draftMessage to make new outgoing message with properties {subject:newSubject, content:newBody, visible:false}
                    tell draftMessage
                        if fromAddr is not "" then set sender to fromAddr
                        repeat with addr in paragraphs of toLines
                            make new to recipient at end of to recipients with properties {address:(contents of addr)}
                        end repeat
                        if ccLines is not "" then
                            repeat with addr in paragraphs of ccLines
                                make new cc recipient at end of cc recipients with properties {address:(contents of addr)}
                            end repeat
                        end if
                        if bccLines is not "" then
                            repeat with addr in paragraphs of bccLines
                                make new bcc recipient at end of bcc recipients with properties {address:(contents of addr)}
                            end repeat
                        end if
                    end tell
                    return send draftMessage
                end tell
            end performtask
            """,
            arguments: [
                from ?? "", to.joined(separator: "\n"), cc.joined(separator: "\n"), bcc.joined(separator: "\n"),
                subject, body,
            ]
        )
        guard result.booleanValue else { throw ToolInputError("Mail did not confirm accepting the message.") }
    }
}
