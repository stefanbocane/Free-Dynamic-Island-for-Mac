import AppKit

/// NSView subclass that backs the island panel's contentView. It serves two purposes:
/// (1) accepts first mouse so hover/click work on a nonactivating panel,
/// (2) implements NSDraggingDestination to power the file drop zone.
final class IslandDropView: NSView {
    weak var controller: IslandPanelController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        Task { @MainActor in controller?.didClickPill() }
    }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSApp.activate(ignoringOtherApps: true)
        let urls = extractURLs(from: sender)
        guard !urls.isEmpty else { return [] }
        Task { @MainActor in
            controller?.setDropPayload(DropPayload(urls: urls))
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor in controller?.setDropPayload(nil) }
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Actual routing to a target is done by the drop-target UI, which calls
        // controller.handleDrop. Dropping anywhere else (outside a target) cancels.
        Task { @MainActor in controller?.setDropPayload(nil) }
        return true
    }

    private func extractURLs(from dragging: NSDraggingInfo) -> [URL] {
        var out: [URL] = []
        if let classes = [NSURL.self] as? [AnyClass],
           let items = dragging.draggingPasteboard.readObjects(forClasses: classes, options: nil) as? [NSURL] {
            out = items.compactMap { $0 as URL }
        }
        return out
    }
}
