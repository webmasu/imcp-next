import Darwin
import Foundation

struct ImsgError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ImsgConnection {
    enum Mode: String {
        case lume, ssh
    }

    static let modeKey = "imsgConnectionMode"
    static let hostKey = "imsgSSHHost"
    let mode: Mode
    let host: String

    static var current: Self {
        let defaults = UserDefaults.standard
        return Self(
            mode: defaults.string(forKey: modeKey).flatMap(Mode.init) ?? .lume,
            host: defaults.string(forKey: hostKey) ?? ""
        )
    }

    func check() async throws -> String {
        let status = try await call("status", [:]).objectValue
        guard status?["protocol_version"]?.intValue == 1,
            status?["database"]?.objectValue?["ready"]?.boolValue == true
        else { throw ImsgError(message: "Connected, but imsg protocol v1 or the Messages database is unavailable.") }
        let version = status?["version"]?.stringValue ?? "unknown"
        let bridgeReady = status?["bridge"]?.objectValue?["ready"]?.boolValue == true
        return "imsg \(version) · database ready · bridge \(bridgeReady ? "ready" : "offline")"
    }

    func call(_ method: String, _ params: [String: Value]) async throws -> Value {
        let directory = try FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let url = directory.appendingPathComponent("imcp-imsg")
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw ImsgError(message: "Run Scripts/install-imsg-connection.sh on the host Mac, then test again.")
        }

        let request = Value.object(["method": .string(method), "params": .object(params)])
        var data = try JSONEncoder().encode(request)
        data.append(10)
        guard data.count <= 65536 else { throw ImsgError(message: "Request exceeds 64 KiB.") }
        let output = try await Self.run(url, arguments: [mode.rawValue, host], input: data)
        let reply = try JSONDecoder().decode([String: Value].self, from: output)
        if let error = reply["error"] {
            // imsg can report delivery phase and retry safety alongside the error message.
            throw ImsgError(message: String(decoding: try JSONEncoder().encode(error), as: UTF8.self))
        }
        guard let result = reply["result"] else { throw ImsgError(message: "Missing imsg result.") }
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
