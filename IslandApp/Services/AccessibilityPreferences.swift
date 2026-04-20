import Foundation
import AppKit
import SwiftUI

@MainActor
final class AccessibilityPreferences: ObservableObject {
    @Published private(set) var reduceMotion: Bool
    @Published private(set) var reduceTransparency: Bool

    /// User-visible preference for pill background opacity (0.5–1.0). Persisted.
    /// Default 1.0 — solid black, matching the CLAUDE.md "no translucency by default"
    /// directive and avoiding a visible translucent rectangle on bright wallpapers.
    @Published var pillOpacity: Double = {
        let stored = UserDefaults.standard.object(forKey: "pillOpacity") as? Double
        return stored.map { max(0.5, min(1.0, $0)) } ?? 1.0
    }() {
        didSet {
            let clamped = max(0.5, min(1.0, pillOpacity))
            UserDefaults.standard.set(clamped, forKey: "pillOpacity")
            if clamped != pillOpacity { pillOpacity = clamped }
        }
    }

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

    /// Effective pill fill opacity. System reduceTransparency forces fully opaque
    /// regardless of the user slider — accessibility setting wins.
    var effectivePillOpacity: Double {
        reduceTransparency ? 1.0 : pillOpacity
    }
}
