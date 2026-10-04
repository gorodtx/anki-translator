import Testing
@testable import TranslatorCore

@Test func liveAccessOverridesStaleDenial() {
    #expect(AccessibilityPermission.isGranted(reportedTrust: false, probe: .available))
}

@Test func liveDenialOverridesStaleGrant() {
    #expect(!AccessibilityPermission.isGranted(reportedTrust: true, probe: .disabled))
    #expect(!AccessibilityPermission.isGranted(reportedTrust: false, probe: .disabled))
}

@Test func inconclusiveProbeDoesNotInventPermission() {
    #expect(!AccessibilityPermission.isGranted(reportedTrust: false, probe: .inconclusive))
    #expect(AccessibilityPermission.isGranted(reportedTrust: true, probe: .inconclusive))
}
