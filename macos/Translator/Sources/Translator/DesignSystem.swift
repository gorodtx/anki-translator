import SwiftUI

/// Motion tokens. Reduce Motion collapses them to a short fade instead of removing
/// feedback.
enum Motion {
    /// Critically damped, quick: the default for anything that just changes value.
    static var stateChange: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 1.0)
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
