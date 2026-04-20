import Foundation
import AppKit
import Combine

/// Detects when the current Space on any active display is a native fullscreen
/// Space. When true, the pill fades out so it doesn't peek over the auto-hidden
/// menu-bar strip.
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
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
        shouldHidePanel = isAnyDisplayInFullscreenSpace() || hasFullscreenSizedWindowOnScreen()
    }

    /// Asks WindowServer (via private CGS APIs) whether any active display's
    /// current Space is a native fullscreen Space. This is the canonical
    /// signal — it reflects the actual Space type rather than inferring from
    /// window geometry, so it doesn't depend on `frontmostApplication`,
    /// window-list timing, or Screen Recording permission.
    ///
    /// CGS APIs are private but have been stable since macOS 10.7 and are
    /// used by many production menu-bar apps (Bartender, Hidden Bar, AltTab).
    private func isAnyDisplayInFullscreenSpace() -> Bool {
        let cid = CGSMainConnectionID()
        guard let unmanaged = CGSCopyManagedDisplaySpaces(cid) else { return false }
        let displays = unmanaged.takeRetainedValue() as? [[String: Any]] ?? []
        for display in displays {
            guard let current = display["Current Space"] as? [String: Any] else { continue }
            // Space type 4 = native fullscreen. (0 = user/desktop.)
            if let type = current["type"] as? Int, type == 4 { return true }
        }
        return false
    }

    /// Fallback path: scan on-screen normal-layer windows for any whose size
    /// matches a screen's full frame. Catches the case where the CGS API
    /// changes shape in a future macOS, or where a non-native fullscreen
    /// (game in exclusive mode) covers the screen.
    private func hasFullscreenSizedWindowOnScreen() -> Bool {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let screenSizes = NSScreen.screens.map { $0.frame.size }
        for info in infoList {
            if let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == myPID { continue }
            if let layer = info[kCGWindowLayer as String] as? Int, layer != 0 { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // 2px tolerance handles subpixel rounding and below-notch fullscreen modes.
            for size in screenSizes where matches(bounds.size, size) { return true }
        }
        return false
    }

    private func matches(_ a: CGSize, _ b: CGSize) -> Bool {
        abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
    }
}

// MARK: - Private CGS APIs
// CoreGraphics Skylight (CGS) symbols, exported from CoreGraphics.framework.
// Stable since macOS 10.7; widely used by production menu-bar utilities.

private typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> Unmanaged<CFArray>?
