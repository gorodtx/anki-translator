import Foundation

/// The native app needs durable history; protocol/version alone do not establish it.
/// Shared by bootstrap readiness and the transport's pre-connection handshake.
public enum BackendCompatibility {
    public static let failureMessage = "This backend is incompatible with this version of Translator. Update the backend or remove the custom socket setting, then try again."

    public struct Ping: Decodable, Equatable, Sendable {
        public let protocolVersion: Int
        public let pid: Int32
        public let capabilities: [String: Bool]

        private enum CodingKeys: String, CodingKey {
            case protocolVersion = "protocol"
            case pid, capabilities
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            protocolVersion = try values.decode(Int.self, forKey: .protocolVersion)
            pid = try values.decode(Int32.self, forKey: .pid)
            capabilities = try values.decodeIfPresent([String: Bool].self, forKey: .capabilities) ?? [:]
        }

        public var isCompatible: Bool {
            protocolVersion == 1 && pid > 1 && capabilities["history_persistence"] == true
        }
    }
}
