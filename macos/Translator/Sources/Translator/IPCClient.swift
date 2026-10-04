import Darwin
import Foundation
import TranslatorCore

/// NDJSON client for the Python backend over a Unix domain socket.
///
/// One background thread owns the socket: it connects (retrying), reads frames, and feeds
/// them back. Requests are written from the caller's thread under a lock and completed by
/// `id`. Callbacks are delivered on the main actor, so the UI never marshals by hand.
final class IPCClient: @unchecked Sendable {
    enum ConnectionState: Equatable {
        case idle
        case connecting(attempt: Int)
        case connected
        case failed(String)
    }

    /// Burst shape from the GNOME extension, plus a retry that never gives up: see
    /// `ReconnectPolicy`.
    static let retryLimit = ReconnectPolicy().burstAttempts
    static let retryDelay: TimeInterval = ReconnectPolicy().burstDelay
    static let requestTimeout: TimeInterval = 30

    private let socketPath: String
    private let lock = NSLock()
    private var fd: Int32 = -1
    private var reader: Thread?
    private var nextId = 1
    private var pending: [String: (Result<Data, Error>) -> Void] = [:]
    private var stopping = false
    private var framer = LineFramer()
    private let policy: ReconnectPolicy

    var onEvent: (@MainActor (IPCEvent) -> Void)?
    var onStateChange: (@MainActor (ConnectionState) -> Void)?

    private(set) var state: ConnectionState = .idle {
        didSet {
            guard state != oldValue, let handler = onStateChange else { return }
            let value = state
            Task { @MainActor in handler(value) }
        }
    }

    init(socketPath: String, policy: ReconnectPolicy = ReconnectPolicy()) {
        self.socketPath = socketPath
        self.policy = policy
    }

    static func defaultSocketPath() -> String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return BackendPaths.socketPath(environment: ProcessInfo.processInfo.environment,
                                       applicationSupportDirectory: support)
    }

    // MARK: - Lifecycle

    func start() {
        lock.lock()
        let alreadyRunning = reader != nil && !stopping
        stopping = false
        lock.unlock()
        guard !alreadyRunning else { return }
        let thread = Thread { [weak self] in self?.runLoop() }
        thread.name = "translator.ipc"
        thread.qualityOfService = .userInitiated
        lock.lock()
        reader = thread
        lock.unlock()
        thread.start()
    }

    func stop() {
        lock.lock()
        stopping = true
        let socket = fd
        fd = -1
        lock.unlock()
        if socket >= 0 { Darwin.close(socket) }
        failAllPending(IPCError(code: "disconnected", message: "Client stopped."))
    }

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fd >= 0
    }

    // MARK: - Requests

    /// Send a request and decode `result` as `T`.
    func send<T: Decodable>(_ method: String, params: [String: Any] = [:], as type: T.Type) async throws -> T {
        let data = try await sendRaw(method, params: params)
        if T.self == Empty.self { return Empty() as! T }
        return try IPCCoding.decoder.decode(T.self, from: data)
    }

    /// Send a request, ignoring the result payload.
    @discardableResult
    func send(_ method: String, params: [String: Any] = [:]) async throws -> Data {
        try await sendRaw(method, params: params)
    }

    private func sendRaw(_ method: String, params: [String: Any]) async throws -> Data {
        let id = nextRequestId()
        let frame = try IPCFraming.request(id: id, method: method, params: params)
        return try await withCheckedThrowingContinuation { continuation in
            let key = String(id)
            var resumed = false
            let finish: (Result<Data, Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }
            lock.lock()
            let socket = fd
            if socket < 0 {
                lock.unlock()
                finish(.failure(IPCError(code: "disconnected", message: "Backend is not connected.")))
                return
            }
            pending[key] = finish
            lock.unlock()

            if !Self.writeAll(socket, frame) {
                lock.lock(); pending.removeValue(forKey: key); lock.unlock()
                finish(.failure(IPCError(code: "write_failed", message: "Failed to write to backend.")))
                return
            }
            // Timeout guard so a wedged backend cannot leak continuations.
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.requestTimeout) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let handler = self.pending.removeValue(forKey: key)
                self.lock.unlock()
                handler?(.failure(IPCError(code: "timeout", message: "\(method) timed out.")))
            }
        }
    }

    private func nextRequestId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    // MARK: - Socket thread

    private func runLoop() {
        // A thread that has finished must not leave `reader` set, or `start()` sees a
        // live reader and refuses to revive the client.
        defer {
            lock.lock()
            if reader === Thread.current { reader = nil }
            lock.unlock()
        }
        var round = 0
        while true {
            lock.lock(); let shouldStop = stopping; lock.unlock()
            if shouldStop { break }

            round += 1
            let wait = policy.delayBeforeRound(round)
            if wait > 0 {
                Thread.sleep(forTimeInterval: wait)
                lock.lock(); let cancelled = stopping; lock.unlock()
                if cancelled { break }
            }

            var socket: Int32 = -1
            for attempt in 1...policy.burstAttempts {
                lock.lock(); let cancelled = stopping; lock.unlock()
                if cancelled { return }
                state = .connecting(attempt: attempt)
                socket = Self.connect(to: socketPath)
                if socket >= 0 { break }
                Thread.sleep(forTimeInterval: policy.burstDelay)
            }
            guard socket >= 0 else {
                // The backend takes seconds to start, so an expired burst means "not yet",
                // never "never": keep waiting instead of killing the client for good.
                state = .failed(policy.waitingMessage(socketPath: socketPath))
                continue
            }
            let validation = Self.validateBackend(socket)
            let validated: ValidatedConnection
            switch validation {
            case let .ready(connection): validated = connection
            case .incompatible:
                Darwin.close(socket)
                state = .failed(BackendCompatibility.failureMessage)
                continue
            case .unavailable:
                Darwin.close(socket)
                state = .failed(policy.waitingMessage(socketPath: socketPath))
                continue
            }
            round = 0
            lock.lock()
            if stopping {
                lock.unlock()
                Darwin.close(socket)
                return
            }
            fd = socket
            framer = validated.framer
            lock.unlock()
            state = .connected
            for line in validated.queued { handle(line: line) }

            readUntilClosed(socket)

            lock.lock()
            let wasStopping = stopping
            if fd == socket { fd = -1 }
            lock.unlock()
            Darwin.close(socket)
            failAllPending(IPCError(code: "disconnected", message: "Backend connection closed."))
            emit(IPCEvent(name: IPCEventName.disconnected, payload: Data("{}".utf8)))
            if wasStopping { return }
            state = .idle
            Thread.sleep(forTimeInterval: policy.burstDelay)
        }
    }

    private func readUntilClosed(_ socket: Int32) {
        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        while true {
            let count = chunk.withUnsafeMutableBytes { buffer in
                Darwin.recv(socket, buffer.baseAddress, buffer.count, 0)
            }
            if count > 0 {
                let data = Data(chunk[0..<count])
                lock.lock()
                let lines = framer.append(data)
                lock.unlock()
                for line in lines { handle(line: line) }
                continue
            }
            if count == 0 { return }               // peer closed
            if errno == EINTR { continue }
            return
        }
    }

    private func handle(line: Data) {
        guard let incoming = try? IPCFraming.parse(line: line) else { return }
        switch incoming {
        case let .response(response):
            lock.lock()
            let handler = pending.removeValue(forKey: response.id)
            lock.unlock()
            guard let handler else { return }
            if response.ok {
                handler(.success(response.result ?? Data("{}".utf8)))
            } else {
                handler(.failure(response.error ?? IPCError(code: "internal", message: "Request failed.")))
            }
        case let .event(event):
            emit(event)
        }
    }

    private func emit(_ event: IPCEvent) {
        guard let handler = onEvent else { return }
        Task { @MainActor in handler(event) }
    }

    private func failAllPending(_ error: Error) {
        lock.lock()
        let handlers = pending
        pending.removeAll()
        lock.unlock()
        for handler in handlers.values { handler(.failure(error)) }
    }

    // MARK: - POSIX helpers

    private struct ValidatedConnection {
        let framer: LineFramer
        let queued: [Data]
    }

    private enum Validation {
        case ready(ValidatedConnection)
        case incompatible
        case unavailable
    }

    /// No app request/event is exposed until this listener proves compatibility.
    /// Preserve every initial event, including a partial frame following the reply.
    private static func validateBackend(_ socket: Int32) -> Validation {
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        let length = socklen_t(MemoryLayout<timeval>.size)
        guard setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, length) == 0,
              setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, length) == 0 else {
            return .unavailable
        }
        defer {
            var blocking = timeval(tv_sec: 0, tv_usec: 0)
            _ = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &blocking, length)
            _ = setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &blocking, length)
        }
        guard let request = try? IPCFraming.request(id: 0, method: IPCMethod.ping, params: [:]),
              writeAll(socket, request) else { return .unavailable }
        var framer = LineFramer()
        var queued: [Data] = []
        var receivedBytes = 0
        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, receivedBytes < 262_144, queued.count < 1024 {
            let count = chunk.withUnsafeMutableBytes { buffer in
                Darwin.recv(socket, buffer.baseAddress, buffer.count, 0)
            }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { return .unavailable }
            receivedBytes += count
            guard receivedBytes <= 262_144 else { return .unavailable }
            var accepted = false
            for line in framer.append(Data(chunk.prefix(count))) {
                if let incoming = try? IPCFraming.parse(line: line),
                   case let .response(response) = incoming, response.id == "0" {
                    guard response.ok, let data = response.result,
                          let ping = try? IPCCoding.decoder.decode(BackendCompatibility.Ping.self, from: data),
                          ping.isCompatible else { return .incompatible }
                    accepted = true
                } else {
                    queued.append(line)
                }
            }
            guard queued.count < 1024 else { return .unavailable }
            if accepted { return .ready(ValidatedConnection(framer: framer, queued: queued)) }
        }
        return .unavailable
    }

    private static func connect(to path: String) -> Int32 {
        guard path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { return -1 }
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return -1 }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
            raw[pathBytes.count] = 0
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(socket, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result != 0 {
            Darwin.close(socket)
            return -1
        }
        var noSigPipe: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        return socket
    }

    private static func writeAll(_ socket: Int32, _ data: Data) -> Bool {
        var sent = 0
        return data.withUnsafeBytes { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            while sent < buffer.count {
                let written = Darwin.send(socket, base.advanced(by: sent), buffer.count - sent, 0)
                if written > 0 { sent += written; continue }
                if written < 0 && errno == EINTR { continue }
                return false
            }
            return true
        }
    }
}

/// Placeholder for methods whose result carries no fields.
struct Empty: Codable, Sendable {
    init() {}
}
