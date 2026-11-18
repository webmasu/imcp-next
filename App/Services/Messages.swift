import Foundation
import JSONSchema

final class MessageService: Service {
    static let shared = MessageService()

    private let limit = JSONSchema.integer(description: "Maximum rows (1 to 100)", minimum: 1, maximum: 100)
    private let chatID = JSONSchema.integer(description: "Numeric chat ID from messages_chats", minimum: 1)

    var tools: [Tool] {
        Tool(
            name: "messages_chats",
            description: "List conversations on the imsg VM. Use a returned chat ID to read its history.",
            inputSchema: .object(
                properties: [
                    "limit": limit,
                    "unread_only": .boolean(description: "Only return chats with unread messages"),
                ],
                additionalProperties: false
            ),
            annotations: .init(title: "List Conversations", readOnlyHint: true)
        ) { try await ImsgConnection.current.call("chats.list", $0) }

        Tool(
            name: "messages_history",
            description: "Read messages in one VM conversation, newest first. Attachments are returned as metadata.",
            inputSchema: .object(
                properties: [
                    "chat_id": chatID, "limit": limit,
                    "start": .string(description: "Start of date range (ISO 8601)"),
                    "end": .string(description: "End of date range (ISO 8601)"),
                    "participants": .array(description: "Phone numbers or email handles", items: .string()),
                    "attachments": .boolean(description: "Include attachment metadata"),
                ],
                required: ["chat_id"],
                additionalProperties: false
            ),
            annotations: .init(title: "Read Conversation", readOnlyHint: true)
        ) { try await ImsgConnection.current.call("messages.history", $0) }

        Tool(
            name: "messages_search",
            description: "Search message text across conversations on the imsg VM.",
            inputSchema: .object(
                properties: [
                    "query": .string(description: "Text to search for"),
                    "match": .string(description: "contains (default) or exact"), "limit": limit,
                ],
                required: ["query"],
                additionalProperties: false
            ),
            annotations: .init(title: "Search Messages", readOnlyHint: true)
        ) { try await ImsgConnection.current.call("messages.search", $0) }

        Tool(
            name: "messages_send",
            description:
                "Send one text through the VM. Supply either to or chat_id. Check history after an uncertain result before sending again.",
            inputSchema: .object(
                properties: [
                    "to": .string(description: "Recipient phone number or email"),
                    "chat_id": chatID,
                    "text": .string(description: "Message body"),
                    "service": .string(description: "For a direct recipient: auto, imessage, or sms"),
                ],
                required: ["text"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Send Text",
                readOnlyHint: false,
                destructiveHint: false,
                idempotentHint: false,
                openWorldHint: true
            )
        ) { try await ImsgConnection.current.call("send", $0) }
    }
}
