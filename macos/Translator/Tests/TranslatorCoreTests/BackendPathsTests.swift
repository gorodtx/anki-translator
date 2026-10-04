import Foundation
import Testing
@testable import TranslatorCore

@Suite("Backend paths")
struct BackendPathsTests {
    private let support = URL(fileURLWithPath: "/acceptance/Library/Application Support")

    @Test func explicitSocketWins() {
        #expect(BackendPaths.socketPath(environment: [
            "TRANSLATOR_SOCKET_PATH": " /tmp/specific.sock ",
            "TRANSLATOR_RUNTIME_DIR": "/tmp/runtime",
            "TRANSLATOR_CONFIG_DIR": "/tmp/config"
        ], applicationSupportDirectory: support) == "/tmp/specific.sock")
    }

    @Test func runtimeOverrideMatchesPython() {
        #expect(BackendPaths.socketPath(environment: [
            "TRANSLATOR_SOCKET_PATH": " \n",
            "TRANSLATOR_RUNTIME_DIR": "/tmp/runtime"
        ], applicationSupportDirectory: support) == "/tmp/runtime/backend.sock")
    }

    @Test func configOverrideDoesNotMoveSocket() {
        #expect(BackendPaths.socketPath(environment: ["TRANSLATOR_CONFIG_DIR": "/tmp/config"],
                                       applicationSupportDirectory: support)
                == "/acceptance/Library/Application Support/Translator/run-app/backend.sock")
    }

    @Test func tildeExpansion() {
        #expect(BackendPaths.socketPath(environment: ["TRANSLATOR_RUNTIME_DIR": "~/tr-test"],
                                       applicationSupportDirectory: support)
                == NSHomeDirectory() + "/tr-test/backend.sock")
    }
}
