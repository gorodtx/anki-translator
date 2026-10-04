import Foundation
import Testing
@testable import TranslatorCore

@Suite("Backend capabilities")
struct BackendCompatibilityTests {
    @Test func modernBackendSupportsRequiredHistory() throws {
        let data = Data(#"{"protocol":1,"pid":123,"capabilities":{"history_persistence":true,"other":false}}"#.utf8)
        let ping = try JSONDecoder().decode(BackendCompatibility.Ping.self, from: data)
        #expect(ping.isCompatible)
    }

    @Test(arguments: [
        #"{"protocol":1,"pid":123}"#,
        #"{"protocol":1,"pid":123,"capabilities":{"history_persistence":false}}"#,
        #"{"protocol":2,"pid":123,"capabilities":{"history_persistence":true}}"#,
        #"{"protocol":1,"pid":1,"capabilities":{"history_persistence":true}}"#,
        #"{"protocol":1,"pid":123,"capabilities":null}"#,
        #"{"protocol":1,"pid":123,"capabilities":{"history_persistence":1}}"#,
        #"{"protocol":1,"pid":123,"capabilities":{"history_persistence":"true"}}"#,
        #"{"version":"0.3.0"}"#,
    ])
    func incompatibleOrMalformedBackendCannotPass(_ json: String) {
        let ping = try? JSONDecoder().decode(BackendCompatibility.Ping.self, from: Data(json.utf8))
        #expect(ping?.isCompatible != true)
    }
}
