import Foundation

/// Match desktop_app.platform.paths on macOS. Config and runtime roots are
/// independent: changing the config profile does not relocate the socket.
public enum BackendPaths {
    public static func socketPath(environment: [String: String], applicationSupportDirectory: URL) -> String {
        for key in ["TRANSLATOR_SOCKET_PATH", "TRANSLATOR_RUNTIME_DIR"] {
            guard let raw = environment[key] else { continue }
            let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            let expanded = (path as NSString).expandingTildeInPath
            return key == "TRANSLATOR_SOCKET_PATH"
                ? expanded
                : URL(fileURLWithPath: expanded).appendingPathComponent("backend.sock").path
        }
        return applicationSupportDirectory.appendingPathComponent("Translator/run-app/backend.sock").path
    }
}
