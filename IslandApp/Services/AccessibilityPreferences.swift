import Foundation
import AppKit
import SwiftUI

@MainActor
final class AccessibilityPreferences: ObservableObject {
    @Published private(set) var reduceMotion: Bool
    @Published private(set) var reduceTransparency: Bool

    init() {
        self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }
        }
    }

    var morphAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.35, dampingFraction: 0.72)
    }
}
