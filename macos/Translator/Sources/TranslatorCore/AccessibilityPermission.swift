/// A live AX operation distinguishes a stale trust answer from actual access.
public enum AccessibilityProbe: Equatable, Sendable {
    case available
    case disabled
    case inconclusive
}

public enum AccessibilityPermission {
    public static func isGranted(reportedTrust: Bool, probe: AccessibilityProbe) -> Bool {
        switch probe {
        case .available: return true
        case .disabled: return false
        case .inconclusive: return reportedTrust
        }
    }
}
