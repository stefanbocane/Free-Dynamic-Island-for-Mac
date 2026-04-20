import Foundation
import AppKit
import SwiftUI
import Combine

/// Owns the IslandPanel, its position, and hover/state transitions.
@MainActor
final class IslandPanelController: NSResponder, ObservableObject {
    @Published private(set) var state: IslandState = .compact
    @Published private(set) var hasHover: Bool = false
    @Published private(set) var dropPayload: DropPayload?
    @Published private(set) var metrics: NotchMetrics?

    let spotify: SpotifyService
    let calendar: CalendarService
    let system: SystemHUDService
    let power: PowerService
    let bluetooth: BluetoothBatteryService
    let fullscreen: FullscreenWatcher
    let accessibility: AccessibilityPreferences
    let router: WidgetRouter
    let launchAtLogin: LaunchAtLogin
    let notes: NotesService

    private var panel: IslandPanel!
    private var hostingView: NSView!
    private var trackingArea: NSTrackingArea?
    private weak var container: IslandDropView?

    private var hoverEnterWorkItem: DispatchWorkItem?
    private var hoverExitWorkItem: DispatchWorkItem?

    private var cancellables: Set<AnyCancellable> = []

    required init?(coder: NSCoder) { fatalError("not supported") }

    override init() {
        self.spotify = SpotifyService()
        self.calendar = CalendarService()
        self.system = SystemHUDService()
        self.power = PowerService()
        self.bluetooth = BluetoothBatteryService()
        self.fullscreen = FullscreenWatcher()
        self.accessibility = AccessibilityPreferences()
        self.launchAtLogin = LaunchAtLogin()
        self.notes = NotesService()
        self.router = WidgetRouter(spotify: spotify, calendar: calendar)
        super.init()
        wireHUDSources()
        buildPanel()
        observeState()
    }

    private func wireHUDSources() {
        system.onHUDEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hud in self?.router.push(hud: hud) }
            .store(in: &cancellables)

        power.onChargingPluggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pct in
                self?.router.push(hud: HUDEvent(kind: .charging, primaryValue: pct / 100.0, ttl: 3.0))
            }
            .store(in: &cancellables)

        bluetooth.onBatteryUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hud in self?.router.push(hud: hud) }
            .store(in: &cancellables)
    }

    private func buildPanel() {
        let initialMetrics = NotchGeometry.preferredScreen().map { NotchGeometry.metrics(for: $0) }
        let placeholderRect = CGRect(x: 0, y: 0, width: 400, height: 80)

        let panel = IslandPanel(contentRect: placeholderRect)
        self.panel = panel

        let rootView = IslandRootView()
            .environmentObject(self)
            .environmentObject(spotify)
            .environmentObject(calendar)
            .environmentObject(router)
            .environmentObject(accessibility)
            .environmentObject(power)
            .environmentObject(notes)

        let host = NSHostingView(rootView: rootView)
        host.autoresizingMask = [.width, .height]
        host.translatesAutoresizingMaskIntoConstraints = true
        self.hostingView = host

        let container = IslandDropView(frame: placeholderRect)
        container.autoresizingMask = [.width, .height]
        container.controller = self
        host.frame = container.bounds
        container.addSubview(host)
        self.container = container

        panel.contentView = container
        panel.setContentSize(placeholderRect.size)
        installTrackingArea(container)

        if let m = initialMetrics {
            metrics = m
            layout(for: m)
        }
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func installTrackingArea(_ view: NSView) {
        refreshTrackingArea(on: view)
    }

    /// Tracking covers the full panel in all states. Previously tried cropping it
    /// to the visible pill area (so hovering above the pill wouldn't trigger
    /// expansion) — but that re-introduces the open/close/open flicker when the
    /// cursor sits exactly on the screen-top edge, because the compact pill lives
    /// AT the top and the expanded pill hangs below it. Full-panel tracking is the
    /// stable choice; we rely on the 220ms hover-enter debounce to filter out
    /// cursor fly-bys on the way to menu-bar items.
    func refreshTrackingArea(on view: NSView? = nil) {
        guard let container = view ?? self.container else { return }
        if let existing = trackingArea { container.removeTrackingArea(existing) }

        let area = NSTrackingArea(
            rect: container.bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        container.addTrackingArea(area)
        trackingArea = area
    }

    @objc private func handleScreenChange() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let m = NotchGeometry.metrics(for: screen)
        metrics = m
        layout(for: m)
        refreshTrackingArea()
    }

    private func observeState() {
        router.$currentHUD
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hud in
                guard let self else { return }
                if let hud {
                    self.transition(to: .transientHUD(hud))
                } else if self.state.isHUD {
                    self.transition(to: self.hasHover ? .expanded : .compact)
                }
            }
            .store(in: &cancellables)

        fullscreen.$shouldHidePanel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hide in
                guard let self else { return }
                if hide { self.transition(to: .hidden) }
                else if self.state.isHidden { self.transition(to: .compact) }
            }
            .store(in: &cancellables)
    }

    func layout(for m: NotchMetrics) {
        guard let panel else { return }
        let size = preferredSize(for: state, metrics: m)
        let origin = CGPoint(
            x: m.notchRect.midX - size.width / 2,
            y: m.screen.frame.maxY - size.height
        )
        let target = CGRect(origin: origin, size: size)
        panel.setFrame(target, display: true, animate: false)
    }

    /// Panel size. Top edge always sits flush with the screen top so hover events
    /// stay captured even if the cursor drifts into the menu-bar strip. Visual
    /// "hanging card" offset for expanded/HUD states is applied inside SwiftUI as
    /// padding-top, not by moving the panel itself.
    func preferredSize(for state: IslandState, metrics m: NotchMetrics) -> CGSize {
        let notchPadding: CGFloat = 8
        let baseHeight: CGFloat = max(m.notchHeight, 32)
        switch state {
        case .compact:
            let w = m.notchWidth + 2 * 60
            return CGSize(width: w, height: baseHeight + notchPadding)
        case .expanded, .transientHUD:
            let w = max(m.notchWidth + 2 * 340, 740)
            return CGSize(width: w, height: baseHeight + 200)
        case .hidden:
            return CGSize(width: 1, height: 1)
        }
    }

    /// Top-padding applied inside SwiftUI so the content "hangs" below the notch
    /// strip while the panel itself stays flush with the screen top. Keeps hover
    /// tracking stable — cursor-at-screen-edge never exits the panel bounds.
    static func contentTopPadding(for state: IslandState) -> CGFloat {
        switch state {
        case .compact, .hidden: return 0
        case .expanded, .transientHUD: return 14
        }
    }

    func transition(to new: IslandState) {
        guard new != state else { return }
        state = new
        router.setHovering(new.isExpanded)
        if let m = metrics {
            let finalSize = preferredSize(for: new, metrics: m)
            let origin = CGPoint(
                x: m.notchRect.midX - finalSize.width / 2,
                y: m.screen.frame.maxY - finalSize.height
            )
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = accessibility.reduceMotion ? 0.18 : 0.28
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(CGRect(origin: origin, size: finalSize), display: true)
                panel.alphaValue = new.isHidden ? 0 : 1
            }
        }
        refreshTrackingArea()
    }

    // MARK: Mouse tracking (click-to-open, leave-to-close)

    /// Hover is tracked only for state — it does NOT trigger expansion anymore.
    /// Opening is driven by clicks on the compact pill (see didClickPill).
    override func mouseEntered(with event: NSEvent) {
        hoverExitWorkItem?.cancel()
        hasHover = true
    }

    /// Mouse leaving the pill area collapses the expanded view back to compact.
    /// Short debounce so fleeting excursions (e.g., mouse slipping just off the
    /// edge) don't instantly slam it shut.
    override func mouseExited(with event: NSEvent) {
        hasHover = false
        let wi = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if !self.hasHover && self.state.isExpanded {
                    self.transition(to: .compact)
                }
            }
        }
        hoverExitWorkItem = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: wi)
    }

    // MARK: Click

    /// Click toggles: compact → expanded → compact.
    func didClickPill() {
        switch state {
        case .compact:
            transition(to: .expanded)
        case .expanded:
            transition(to: .compact)
        case .transientHUD, .hidden:
            break
        }
    }

    func collapseToCompact() {
        transition(to: .compact)
    }

    // MARK: Drag

    func setDropPayload(_ payload: DropPayload?) {
        dropPayload = payload
        if payload != nil {
            transition(to: .expanded)
        } else if state.isExpanded {
            transition(to: hasHover ? .expanded : .compact)
        }
    }

    func handleDrop(urls: [URL], target: DropTarget) {
        switch target {
        case .airdrop:
            let service = NSSharingService(named: .sendViaAirDrop)
            service?.perform(withItems: urls)
        case .copyPath:
            let paths = urls.map { $0.path }.joined(separator: "\n")
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(paths, forType: .string)
        case .moveToDesktop:
            if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                for url in urls {
                    let dest = desktop.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.moveItem(at: url, to: dest)
                }
            }
        }
        dropPayload = nil
        collapseToCompact()
    }
}
