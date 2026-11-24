import Foundation
import TopoText

extension NotesService {
    var createNote: Tool {
        Tool(
            name: "notes_create",
            description:
                "Create a note from HTML. The first line is the title. Defaults to the default account’s default folder.",
            inputSchema: .object(
                properties: ["html": .string(), "folder": .string(description: "Folder @id from notes_folders.")],
                required: ["html"],
                additionalProperties: false
            ),
            annotations: .init(title: "Create Note", destructiveHint: false, openWorldHint: false)
        ) { args in
            let html = try args.requiredText("html")
            let folder = try args.optionalText("folder")
            let folderID: String
            if let folder { folderID = try await self.nativeID(folder, entity: "ICFolder") } else { folderID = "" }
            let id = try await NSAppleScript.execute(
                """
                on performtask(folderID, newBody)
                    tell application id "com.apple.Notes"
                        if folderID is "" then
                            set dest to default folder of default account
                        else
                            set dest to folder id folderID
                        end if
                        return id of (make new note at dest with properties {body:newBody})
                    end tell
                end performtask
                """,
                arguments: [folderID, html]
            )
            guard let native = id.stringValue else { throw ToolInputError("Notes returned no identifier.") }
            return Value.object(["id": .string(native)])
        }
    }

    var updateNote: Tool {
        Tool(
            name: "notes_update",
            description:
                "Replace the entire HTML body, including its title. Locked notes and notes containing attachments or tables cannot be replaced.",
            inputSchema: .object(
                properties: ["id": .string(), "html": .string()],
                required: ["id", "html"],
                additionalProperties: false
            ),
            annotations: .init(title: "Update Note", destructiveHint: true, openWorldHint: false)
        ) { args in
            let html = try args.requiredText("html")
            let pair = try await self.resolveNoteIdentifier(args.requiredText("id"), entity: "ICNote")
            guard let stable = TopoText.Note.ID(pair.stable) else { throw ToolInputError("Invalid note identifier.") }
            try await self.withStore { store in
                try await store.withSnapshot { snapshot in
                    let note = try snapshot.note(for: stable)
                    guard !note.isLocked, !note.isRecentlyDeleted else {
                        throw ToolInputError("This note is locked or deleted.")
                    }
                    let content = try snapshot.content(for: stable)
                    guard
                        !content.paragraphs.contains(where: { p in
                            p.runs.contains { $0.attachment != nil || $0.text.contains("\u{fffc}") }
                        })
                    else {
                        throw ToolInputError("This note contains an embedded item.")
                    }
                }
            }
            let id = pair.native
            _ = try await NSAppleScript.execute(
                """
                on performtask(noteID, newBody)
                    tell application id "com.apple.Notes"
                        set targetNote to note id noteID
                        if password protected of targetNote then error "This note is locked."
                        set original to body of targetNote
                        ignoring case
                            if (count of attachments of targetNote) > 0 or original contains "<table" or original contains "<object" or original contains "<img" then error "This note contains an attachment or a table."
                        end ignoring
                        set body of targetNote to newBody
                    end tell
                end performtask
                """,
                arguments: [id, html]
            )
            return Value.bool(true)
        }
    }

    var openNote: Tool {
        Tool(
            name: "notes_open",
            description: "Show a note in the Notes app by id.",
            inputSchema: .object(properties: ["id": .string()], required: ["id"], additionalProperties: false),
            annotations: .init(title: "Open Note", destructiveHint: false, openWorldHint: false)
        ) { args in
            let id = try await self.nativeID(args.requiredText("id"), entity: "ICNote")
            _ = try await NSAppleScript.execute(
                """
                on performtask(noteID)
                    tell application id "com.apple.Notes"
                        show note id noteID
                        activate
                    end tell
                end performtask
                """,
                arguments: [id]
            )
            return Value.bool(true)
        }
    }

    private func nativeID(_ identifier: String, entity: String) async throws -> String {
        let pair = try await resolveNoteIdentifier(identifier, entity: entity)
        return pair.native
    }

    /// Verify both the store UUID and the entity before mapping in either direction.
    func resolveNoteIdentifier(_ identifier: String, entity: String) async throws -> (native: String, stable: String) {
        try await withStore { store in
            let native = identifier.hasPrefix("x-coredata://")
            let rows = try ReadOnlyIndex(url: store.root.appendingPathComponent("NoteStore.sqlite")).rows(
                """
                SELECT 'x-coredata://' || m.Z_UUID || '/' || p.Z_NAME || '/p' || n.Z_PK AS uri, n.ZIDENTIFIER
                FROM ZICCLOUDSYNCINGOBJECT n JOIN Z_PRIMARYKEY p ON p.Z_ENT = n.Z_ENT CROSS JOIN Z_METADATA m
                WHERE p.Z_NAME = ? AND \(native ? "uri" : "n.ZIDENTIFIER") = ? LIMIT 2
                """,
                parameters: [entity, identifier]
            )
            guard rows.count == 1 else { throw ToolInputError("No unique \(entity) matches this identifier.") }
            return (rows[0][0], rows[0][1])
        }
    }
}
