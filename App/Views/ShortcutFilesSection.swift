import SwiftUI

struct ShortcutFilesSection: View {
    @AppStorage(ShortcutFiles.key) private var bookmark = Data()
    @State private var error: String?

    var body: some View {
        Section("Shortcut files") {
            if let folder = try? ShortcutFiles.folder(bookmark) { Text(folder.path).textSelection(.enabled) }
            Button("Choose folder for file input and output…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                guard panel.runModal() == .OK, let url = panel.url else { return }
                do {
                    bookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    error = nil
                } catch { self.error = error.localizedDescription }
            }
            if !bookmark.isEmpty {
                Button("Remove folder access") {
                    bookmark = Data(); error = nil
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
    }
}
