import Foundation
import AppKit

struct NotchMetrics: Equatable {
    let screen: NSScreen
    let hasNotch: Bool
    let notchRect: CGRect          // rect of the notch itself (in screen coordinates)
    let menuBarRect: CGRect        // rect of the menu bar strip
    let notchWidth: CGFloat
    let notchHeight: CGFloat
}

enum NotchGeometry {
    /// Pick the screen where the pill should live. Prefer the screen with a notch; otherwise
    /// pick the screen containing the mouse; otherwise fall back to the main screen.
    static func preferredScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { ($0.safeAreaInsets.top) > 0 }) {
            return notched
        }
        let mouse = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSPointInRect(mouse, $0.frame) }) {
            return mouseScreen
        }
        return NSScreen.main
    }

    static func metrics(for screen: NSScreen) -> NotchMetrics {
        let safeTop = screen.safeAreaInsets.top
        let hasNotch = safeTop > 0

        let frame = screen.frame
        let menuBarHeight = max(safeTop, NSStatusBar.system.thickness)
        let menuBarRect = CGRect(
            x: frame.minX,
            y: frame.maxY - menuBarHeight,
            width: frame.width,
            height: menuBarHeight
        )

        let leftAux = screen.auxiliaryTopLeftArea ?? .zero
        let rightAux = screen.auxiliaryTopRightArea ?? .zero

        let notchHeight: CGFloat = hasNotch ? safeTop : 32
        let notchRect: CGRect

        if hasNotch, leftAux.width > 0, rightAux.width > 0 {
            // The notch lives between the two aux rects. Derive its real horizontal
            // extent directly, don't assume frame.midX — on some MBP configs the aux
            // strips aren't perfectly symmetric and frame.midX is a few points off.
            let notchMinX = frame.minX + leftAux.width
            let notchMaxX = frame.maxX - rightAux.width
            notchRect = CGRect(
                x: notchMinX,
                y: frame.maxY - notchHeight,
                width: max(0, notchMaxX - notchMinX),
                height: notchHeight
            )
        } else {
            let syntheticWidth: CGFloat = hasNotch ? max(0, frame.width - leftAux.width - rightAux.width) : 210
            notchRect = CGRect(
                x: frame.midX - syntheticWidth / 2,
                y: frame.maxY - notchHeight,
                width: syntheticWidth,
                height: notchHeight
            )
        }

        return NotchMetrics(
            screen: screen,
            hasNotch: hasNotch,
            notchRect: notchRect,
            menuBarRect: menuBarRect,
            notchWidth: notchRect.width,
            notchHeight: notchHeight
        )
    }
}
