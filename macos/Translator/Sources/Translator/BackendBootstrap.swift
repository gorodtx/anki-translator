import Darwin
import Foundation
#if canImport(TranslatorCore)
import TranslatorCore
#endif

/// The ordinary app owns a backend child. A responding legacy agent is attach-only.
/// No launchd registration, shell, external Python or checkout is needed at runtime.
@MainActor
final class BackendBootstrap {
    static let shared = BackendBootstrap()

    private let executable: URL
    private let environment: [String: String]
    private let readinessTimeout: TimeInterval
    private var child: Process?
    private var logHandle: FileHandle?
    private var startup: Task<String?, Never>?
    private var monitor: Task<Void, Never>?
    private var active = false
    private var generation = 0
    private var automaticRestarts = 0
    private var socketPath = ""
    var onFailure: ((String) -> Void)?

    init(executable: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment,
         readinessTimeout: TimeInterval = 30) {
        self.executable = executable ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/TranslatorBackend")
        self.environment = environment
        self.readinessTimeout = readinessTimeout
    }

    /// Idempotent even when Settings and app launch ask concurrently.
    @discardableResult
    func start(socketPath: String) async -> String? {
        await begin(socketPath: socketPath, resetRestarts: true)
    }

    private func begin(socketPath: String, resetRestarts: Bool) async -> String? {
        if let startup { return await startup.value }
        active = true
        if resetRestarts { automaticRestarts = 0 }
        self.socketPath = socketPath
        let current = generation
        let task = Task { await ensureReady(generation: current) }
        startup = task
        let failure = await task.value
        if current == generation { startup = nil }
        guard active, current == generation else { return nil }
        if let failure { onFailure?(failure) }
        if monitor == nil {
            monitor = Task { [weak self] in
                defer {
                    if self?.generation == current { self?.monitor = nil }
                }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, self.active, self.generation == current, !Task.isCancelled else { return }
                    if let child = self.child, !child.isRunning {
                        self.child = nil
                        self.closeLog()
                        guard self.automaticRestarts < 3 else {
                            self.onFailure?("The backend stopped. Open Settings and choose Start Backend to try again.")
                            return
                        }
                        self.automaticRestarts += 1
                        NSLog("[translator.bootstrap] retry %d after owned child exit", self.automaticRestarts)
                        _ = await self.begin(socketPath: self.socketPath, resetRestarts: false)
                    }
                }
            }
        }
        return failure
    }

    /// Only the Process launched by this instance can receive a signal.
    /// Bounded synchronous cleanup is needed in applicationWillTerminate.
    func stop() {
        active = false
        generation += 1
        startup?.cancel()
        startup = nil
        monitor?.cancel()
        monitor = nil
        if let child, child.isRunning {
            NSLog("[translator.bootstrap] stopping owned child %d", child.processIdentifier)
            child.terminate()
            let deadline = Date().addingTimeInterval(3)
            while child.isRunning, Date() < deadline { usleep(20_000) }
            if child.isRunning { _ = Darwin.kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
        }
        child = nil
        closeLog()
    }

    private func ensureReady(generation current: Int) async -> String? {
        let deadline = Date().addingTimeInterval(readinessTimeout)
        var launched = child?.isRunning == true
        while active, current == generation, !Task.isCancelled, Date() < deadline {
            let path = socketPath
            let probe = await Task.detached(priority: .utility) { BackendProbe.read(path: path) }.value
            guard active, current == generation, !Task.isCancelled else { return nil }
            switch probe {
            case .ready(let pid):
                NSLog("[translator.bootstrap] ready backend %d; owned=%@", pid, launched ? "yes" : "no")
                return nil
            case .occupied:
                // A live listener may still be warming its engines. Never replace it.
                break
            case .incompatible:
                return BackendCompatibility.failureMessage
            case .absent:
                if !launched {
                    if let failure = launch() { return failure }
                    launched = true
                }
            }
            if launched, let child, !child.isRunning {
                return "The backend could not start. Open Settings and choose Start Backend to try again."
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return active ? "The backend did not answer. Open Settings and choose Start Backend to try again." : nil
    }

    private func launch() -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            return "This copy of Translator is incomplete. Download the app again."
        }
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Translator")
            let logs = environment["TRANSLATOR_LOG_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Translator")
            let config = environment["TRANSLATOR_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? support
            for directory in [config, logs, URL(fileURLWithPath: socketPath).deletingLastPathComponent()] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
            }
            let log = logs.appendingPathComponent("bootstrap.log")
            if !FileManager.default.fileExists(atPath: log.path) {
                FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            closeLog()
            let handle = try FileHandle(forWritingTo: log)
            try handle.seekToEnd()
            logHandle = handle
            let process = Process()
            process.executableURL = executable
            process.currentDirectoryURL = executable.deletingLastPathComponent()
            var pinned = environment
            pinned["TRANSLATOR_SOCKET_PATH"] = socketPath
            pinned["PYTHONDONTWRITEBYTECODE"] = "1"
            pinned["TRANSLATOR_PARENT_PID"] = String(Darwin.getpid())
            process.environment = pinned
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = handle
            process.standardError = handle
            try process.run()
            child = process
            NSLog("[translator.bootstrap] launched owned child %d", process.processIdentifier)
            return nil
        } catch {
            closeLog()
            NSLog("[translator.bootstrap] launch failed: %@", error.localizedDescription)
            return "The backend could not start. Check that Translator is in Applications and try again."
        }
    }

    private func closeLog() {
        try? logHandle?.close()
        logHandle = nil
    }
}

private enum BackendProbe: Sendable {
    case absent
    case occupied
    case incompatible
    case ready(Int32)

    private struct Reply: Decodable {
        let id: String
        let ok: Bool
        let result: BackendCompatibility.Ping?
    }

    /// A successful connect with a missing/incompatible response is occupied, not absent.
    static func read(path: String) -> BackendProbe {
        let bytes = Array(path.utf8)
        guard bytes.count <= 103 else { return .occupied }
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return .occupied }
        defer { Darwin.close(fd) }
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes + [0])
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            return [ENOENT, ECONNREFUSED].contains(errno) ? .absent : .occupied
        }
        let request = Data("{\"id\":\"bootstrap\",\"method\":\"ping\",\"params\":{}}\n".utf8)
        let sent = request.withUnsafeBytes { Darwin.send(fd, $0.baseAddress, $0.count, 0) }
        guard sent == request.count else { return .occupied }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, data.count < 262_144 {
            let received = Darwin.recv(fd, &buffer, buffer.count, 0)
            guard received > 0 else { return .occupied }
            data.append(contentsOf: buffer.prefix(received))
            while let newline = data.firstIndex(of: 10) {
                let line = data[..<newline]
                data.removeSubrange(...newline)
                if let reply = try? JSONDecoder().decode(Reply.self, from: line),
                   reply.id == "bootstrap", reply.ok, let ping = reply.result {
                    return ping.isCompatible ? .ready(ping.pid) : .incompatible
                }
            }
        }
        return .occupied
    }
}
