import Darwin
import Foundation

struct LocalScriptError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum LocalScript {
    static func call(_ name: String, arguments: [String] = [], request: Value) async throws -> Value {
        let directory = try FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw LocalScriptError(
                message: "Install \(name) in the app’s Application Scripts folder. See the fork’s README."
            )
        }

        var data = try JSONEncoder().encode(request)
        data.append(10)
        guard data.count <= 65536 else { throw LocalScriptError(message: "Request exceeds 64 KiB.") }
        let output = try await Self.run(url, arguments: arguments, input: data)
        let reply = try JSONDecoder().decode([String: Value].self, from: output)
        if let error = reply["error"] {
            if let fields = error.objectValue, fields.count == 1, let message = fields["message"]?.stringValue {
                throw LocalScriptError(message: message)
            }
            throw LocalScriptError(message: String(decoding: try JSONEncoder().encode(error), as: UTF8.self))
        }
        guard let result = reply["result"] else { throw LocalScriptError(message: "Missing script result.") }
        return result
    }

    private static func run(_ url: URL, arguments: [String], input data: Data) async throws -> Data {
        let task = try NSUserUnixTask(url: url)
        let input = Pipe()
        let output = Pipe()
        task.standardInput = input.fileHandleForReading
        task.standardOutput = output.fileHandleForWriting
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)

        // Drain while the script runs. A single history response can exceed a pipe buffer.
        let reader = Task.detached { try output.fileHandleForReading.readToEnd() ?? Data() }
        let writer = Task.detached {
            defer { try? input.fileHandleForWriting.close() }
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        do {
            try await task.execute(withArguments: arguments)
        } catch {
            try? input.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            throw error
        }
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        try await writer.value
        return try await reader.value
    }
}
