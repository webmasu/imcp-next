import Foundation

enum ShortcutFiles {
    static let key = "shortcutsFilesBookmark"

    static func folder(_ bookmark: Data) throws -> URL? {
        guard !bookmark.isEmpty else { return nil }
        var stale = false
        return try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    static func access() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key), let url = try folder(data) else { return nil }
        guard url.startAccessingSecurityScopedResource() else {
            throw ToolInputError("Choose the shortcut files folder again in Settings.")
        }
        return url
    }
}
