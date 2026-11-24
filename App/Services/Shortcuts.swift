import Foundation

final class ShortcutsService: Service {
    static let shared = ShortcutsService()

    var tools: [Tool] {
        Tool(
            name: "shortcuts_list",
            description: "List shortcut names, optionally by folder or with metadata.",
            inputSchema: .object(
                properties: [
                    "folder": .string(description: "Folder name, or none for unfiled shortcuts."),
                    "details": .boolean(description: "Include identifier, folder, action count and input support."),
                ],
                additionalProperties: false
            ),
            annotations: .init(title: "List Shortcuts", readOnlyHint: true, openWorldHint: false)
        ) { args in
            let folder = try args.optionalText("folder")
            if args["details"] == .bool(true) { return try await Self.details(folder: folder) }
            let options = folder.map { ["--folder-name", $0] } ?? []
            return try await Self.names(["list"] + options)
        }
        Tool(
            name: "shortcuts_folders",
            description: "List shortcut folder names.",
            inputSchema: .object(properties: [:], additionalProperties: false),
            annotations: .init(title: "List Shortcut Folders", readOnlyHint: true, openWorldHint: false)
        ) { _ in
            try await Self.names(["list", "--folders"])
        }
        Tool(
            name: "shortcuts_open",
            description: "Open a shortcut by name or identifier in the Shortcuts editor.",
            inputSchema: .object(properties: ["name": .string()], required: ["name"], additionalProperties: false),
            annotations: .init(title: "Open Shortcut", destructiveHint: false, openWorldHint: false)
        ) { args in
            _ = try await Self.command(["view", "--", args.requiredText("name")])
            return Value.bool(true)
        }
        Tool(
            name: "shortcuts_run",
            description: "Run a shortcut by name or identifier with optional text or file input.",
            inputSchema: .object(
                properties: [
                    "name": .string(), "input": .string(description: "Text input, mutually exclusive with inputPath."),
                    "inputPath": .string(description: "Absolute path to a readable file."),
                    "outputPath": .string(description: "Absolute path for a new output file. Omit for text output."),
                ],
                required: ["name"],
                additionalProperties: false
            ),
            annotations: .init(title: "Run Shortcut", destructiveHint: true, openWorldHint: true)
        ) { args in
            let name = try args.requiredText("name")
            let input = try args.optionalText("input")
            let inputPath = try args.optionalText("inputPath")
            let outputPath = try args.optionalText("outputPath")
            guard input == nil || inputPath == nil else { throw ToolInputError("Choose input or inputPath.") }
            guard [inputPath, outputPath].compactMap({ $0 }).allSatisfy({ $0.hasPrefix("/") }) else {
                throw ToolInputError("File paths must be absolute.")
            }
            let grant = (inputPath != nil || outputPath != nil) ? try ShortcutFiles.access() : nil
            defer { grant?.stopAccessingSecurityScopedResource() }
            let dir = try Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            // Preserve the requested extension so Shortcuts exports the correct type.
            let output = dir.appendingPathComponent("output", isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
            let file = output.appendingPathComponent(
                outputPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "output.txt"
            )
            if let outputPath, FileManager.default.fileExists(atPath: outputPath) {
                throw ToolInputError("The output file already exists.")
            }
            var options = ["run", "--output-path", file.path]
            if let inputPath {
                // The command runs separately from the process holding the folder bookmark.
                let source = URL(fileURLWithPath: inputPath).resolvingSymlinksInPath()
                guard try source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                    throw ToolInputError("inputPath must identify a regular file.")
                }
                let inputs = dir.appendingPathComponent("input", isDirectory: true)
                try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: false)
                let staged = inputs.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: staged)
                options += ["--input-path", staged.path]
            } else if let input {
                let url = dir.appendingPathComponent("input.txt")
                try input.write(to: url, atomically: true, encoding: .utf8)
                options += ["--input-path", url.path]
            }
            _ = try await Self.command(options + ["--", name])
            var result: [String: Value] = ["success": true, "shortcut": .string(name)]
            if let outputPath {
                try FileManager.default.copyItem(at: file, to: URL(fileURLWithPath: outputPath))
                result["outputPath"] = .string(outputPath)
            } else if let text = try? String(contentsOf: file, encoding: .utf8), !text.isEmpty {
                result["output"] = .string(text)
            }
            return Value.object(result)
        }
    }

    private static func names(_ arguments: [String]) async throws -> Value {
        .array(try await command(arguments).split(separator: "\n").map { .string(String($0)) })
    }

    private static func details(folder: String?) async throws -> Value {
        let rows = try await NSAppleScript.execute(
            """
            on performtask(filterName)
                tell application id "com.apple.shortcuts"
                    set output to {}
                    repeat with s in shortcuts
                        set parentName to ""
                        if folder of s is not missing value then set parentName to name of folder of s
                        if filterName is "" or filterName is parentName or (filterName is "none" and parentName is "") then
                            set end of output to {id of s, name of s, parentName, action count of s, accepts input of s}
                        end if
                    end repeat
                    return output
                end tell
            end performtask
            """,
            arguments: [folder ?? ""]
        )
        return .array(
            (0 ..< rows.numberOfItems).compactMap { index -> Value? in
                guard let row = rows.atIndex(index + 1), let id = row.atIndex(1)?.stringValue,
                    let name = row.atIndex(2)?.stringValue
                else { return nil }
                return [
                    "id": .string(id), "name": .string(name), "folder": .string(row.atIndex(3)?.stringValue ?? ""),
                    "actionCount": .int(Int(row.atIndex(4)?.int32Value ?? 0)),
                    "acceptsInput": .bool(row.atIndex(5)?.booleanValue ?? false),
                ]
            }
        )
    }

    private static func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return dir
    }

    private static func command(_ arguments: [String]) async throws -> String {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        func capture(_ name: String) throws -> (URL, FileHandle) {
            let url = dir.appendingPathComponent(name)
            try Data().write(to: url)
            return (url, try FileHandle(forWritingTo: url))
        }
        let (output, stdout) = try capture("stdout")
        let (error, stderr) = try capture("stderr")
        defer { try? stdout.close(); try? stderr.close() }
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try Task.checkCancellation()
        try process.run()
        // Foundation calls waitUntilExit reliably even for a very short-lived process.
        let waiter = Task.detached { process.waitUntilExit() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await waiter.value }
            group.addTask {
                try await Task.sleep(for: .seconds(300))
                throw ToolInputError("Shortcuts timed out after five minutes.")
            }
            defer { group.cancelAll() }
            do { _ = try await group.next() } catch {
                if process.isRunning { process.terminate() }
                throw error
            }
        }
        guard process.terminationStatus == 0 else {
            throw ToolInputError(try String(contentsOf: error, encoding: .utf8))
        }
        return try String(contentsOf: output, encoding: .utf8)
    }
}
