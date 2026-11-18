import SwiftUI

struct ImsgSettingsSection: View {
    @AppStorage(ImsgConnection.modeKey) private var mode = ImsgConnection.Mode.lume
    @AppStorage(ImsgConnection.hostKey) private var host = ""
    @State private var testing = false
    @State private var result: String?

    var body: some View {
        Section("imsg Connection") {
            Picker("Connect via", selection: $mode) {
                Text("Lume SSH wrappers").tag(ImsgConnection.Mode.lume)
                Text("SSH host").tag(ImsgConnection.Mode.ssh)
            }
            if mode == .ssh {
                TextField("SSH host alias", text: $host, prompt: Text("messages-vm"))
                Text("Uses ~/.ssh/config on this Mac and /usr/local/bin/imsg in the guest.")
                    .font(.caption)
            } else {
                Text("Uses ~/.local/bin/imsg-ro for reads and imsg-rw for sending.")
                    .font(.caption)
            }
            Button(testing ? "Testing…" : "Test Connection") {
                let connection = ImsgConnection(mode: mode, host: host)
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
        .onChange(of: host) { result = nil }
    }
}
