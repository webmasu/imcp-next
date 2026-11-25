import Foundation
import MCP
import os

/// The installer queries tools/list on the pinned original bridge and keeps its catalog
/// beside the executable. Loading the catalog never launches BusyCal or opens a calendar.
final class BusyCalService: Service, Sendable {
    static let shared = BusyCalService()
    static let writesKey = "busyCalAllowChanges"
    private let catalog = OSAllocatedUnfairLock<[Tool]?>(initialState: nil)

    var isInstalled: Bool { !installedTools.isEmpty }

    private var installedTools: [Tool] {
        catalog.withLock { cached in
            if let cached { return cached }
            guard let scripts = FileManager.default.urls(for: .applicationScriptsDirectory, in: .userDomainMask).first,
                FileManager.default.isExecutableFile(atPath: scripts.appendingPathComponent("imcp-busycal").path),
                let data = try? Data(contentsOf: scripts.appendingPathComponent("BusyCalMCP-1.3.0/catalog.json")),
                let upstream = try? JSONDecoder().decode([MCP.Tool].self, from: data), !upstream.isEmpty
            else { return [] }
            let tools = upstream.map { upstream in
                Tool(forwarding: upstream, prefix: "busycal_") { arguments in
                    if upstream.annotations.readOnlyHint != true && !UserDefaults.standard.bool(forKey: Self.writesKey)
                    {
                        throw LocalScriptError(message: "Enable Allow Changes in Settings > BusyCal.")
                    }
                    let reply = try await LocalScript.call(
                        "imcp-busycal",
                        request: .object([
                            "name": .string(upstream.name), "arguments": .object(arguments),
                        ])
                    )
                    return try JSONDecoder().decode(CallTool.Result.self, from: JSONEncoder().encode(reply))
                }
            }
            cached = tools
            return tools
        }
    }

    var tools: [Tool] {
        let allowChanges = UserDefaults.standard.bool(forKey: Self.writesKey)
        return installedTools.filter { allowChanges || $0.annotations.readOnlyHint == true }
    }

    var isActivated: Bool { get async { isInstalled } }

    func activate() async throws {
        guard isInstalled else {
            throw LocalScriptError(message: "Install the official bridge with Scripts/install-busycal.sh.")
        }
    }
}
