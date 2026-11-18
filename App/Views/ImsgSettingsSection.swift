import SwiftUI

struct ImsgSettingsSection: View {
    @AppStorage(ImsgConnection.modeKey) private var mode = ImsgConnection.Mode.vm
    @AppStorage(ImsgConnection.hostKey) private var host = ""
    @AppStorage(ImsgConnection.localPathKey) private var localPath = ""
    @State private var testing = false
    @State private var result: String?

    var body: some View {
        Section("imsg Connection") {
            Picker("Connect via", selection: $mode) {
                Text("imsg-vm").tag(ImsgConnection.Mode.vm)
                Text("imsg").tag(ImsgConnection.Mode.local)
                Text("SSH host").tag(ImsgConnection.Mode.ssh)
            }
            if mode == .ssh {
                TextField("SSH host alias", text: $host, prompt: Text("messages-vm"))
                Text("Uses ~/.ssh/config on this Mac and /usr/local/bin/imsg in the guest.")
                    .font(.caption)
            } else if mode == .local {
                TextField("imsg executable", text: $localPath, prompt: Text("/opt/homebrew/bin/imsg"))
                Text("Leave blank to use the Homebrew binary on this Mac.").font(.caption)
            } else {
                Text("Uses imsg-vm on this Mac to run imsg in the guest. Reads use its imsg-ro command.")
                    .font(.caption)
            }
            Button(testing ? "Testing…" : "Test Connection") {
                let connection = ImsgConnection(mode: mode, target: mode == .local ? localPath : host)
                testing = true
                result = nil
                Task {
                    defer { testing = false }
                    do { result = try await connection.check() } catch { result = error.localizedDescription }
                }
            }
            if let result { Text(result).textSelection(.enabled) }
        }
        .disabled(testing)
        .onChange(of: mode) { result = nil }
        .onChange(of: localPath) { result = nil }
        .onChange(of: host) { result = nil }
    }
}
