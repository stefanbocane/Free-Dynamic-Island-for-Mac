import AppKit

final class IslandPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        worksWhenModal = true
        acceptsMouseMovedEvents = true
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        registerForDraggedTypes([.fileURL, .URL])
    }

    // Panel is nonactivating (clicking it won't activate the app / steal focus from
    // Xcode etc.), but it CAN become key so text fields inside receive keyboard
    // events — required for the sticky-note input.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
