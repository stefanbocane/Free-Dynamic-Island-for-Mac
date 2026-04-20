import Foundation
import AppKit
import Combine

/// Detects when the frontmost app is in true fullscreen AND producing audio, as a
/// heuristic for "watching a video fullscreen." When true, we fade the pill out of the way.
@MainActor
final class FullscreenWatcher: ObservableObject {
    @Published private(set) var shouldHidePanel: Bool = false

    /// User-visible preference. When false, the pill stays visible even in
    /// fullscreen. Persisted via UserDefaults; observed by Settings.
    @Published var hideOnFullscreen: Bool = UserDefaults.standard.object(forKey: "hideOnFullscreen") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(hideOnFullscreen, forKey: "hideOnFullscreen")
            refresh()
        }
    }

    private var pollTimer: Timer?

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        // Poll periodically for audio-state changes not covered by app-activation events
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        pollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func refresh() {
        guard hideOnFullscreen else {
            shouldHidePanel = false
            return
        }
        let frontApp = NSWorkspace.shared.frontmostApplication
        let fullscreen = isFrontmostAppFullscreen(frontApp: frontApp)
        let audio = AudioActivityService.isDefaultOutputRunning()
        shouldHidePanel = fullscreen && audio
    }

    private func isFrontmostAppFullscreen(frontApp: NSRunningApplication?) -> Bool {
        guard let pid = frontApp?.processIdentifier else { return false }
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            // Fullscreen windows have layer 0 (normal) but span the whole screen; and/or
            // the private "kCGWindowIsFullscreen" key is set. Check size vs any screen bounds.
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                for screen in NSScreen.screens where screen.frame == bounds { return true }
            }
            if let layer = info[kCGWindowLayer as String] as? Int, layer != 0 { continue }
            if let isFS = info["kCGWindowIsFullscreen"] as? Bool, isFS { return true }
        }
        return false
    }
}
