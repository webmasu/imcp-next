import Foundation

struct ImsgConnection {
    enum Mode: String {
        case vm = "imsg-vm"
        case local, ssh

        init?(rawValue: String) {
            switch rawValue {
            case "lume", "imsg-vm": self = .vm
            case "local": self = .local
            case "ssh": self = .ssh
            default: return nil
            }
        }
    }

    static let modeKey = "imsgConnectionMode"
    static let hostKey = "imsgSSHHost"
    static let localPathKey = "imsgLocalPath"
    let mode: Mode
    let target: String

    static var current: Self {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: modeKey).flatMap(Mode.init) ?? .vm
        return Self(mode: mode, target: defaults.string(forKey: mode == .local ? localPathKey : hostKey) ?? "")
    }

    func check() async throws -> String {
        let status = try await call("status", [:]).objectValue
        guard status?["protocol_version"]?.intValue == 1,
            status?["database"]?.objectValue?["ready"]?.boolValue == true
        else {
            throw LocalScriptError(message: "Connected, but imsg protocol v1 or the Messages database is unavailable.")
        }
        let version = status?["version"]?.stringValue ?? "unknown"
        let bridgeReady = status?["bridge"]?.objectValue?["ready"]?.boolValue == true
        return "imsg \(version) · database ready · bridge \(bridgeReady ? "ready" : "offline")"
    }

    func call(_ method: String, _ params: [String: Value]) async throws -> Value {
        let request = Value.object(["method": .string(method), "params": .object(params)])
        return try await LocalScript.call("imcp-imsg", arguments: [mode.rawValue, target], request: request)
    }
}
