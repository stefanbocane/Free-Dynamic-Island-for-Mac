import Foundation
import AppKit
import CoreAudio
import CoreGraphics
import Combine

/// Observes volume / brightness / mute keys globally and emits HUDEvents so our
/// pill shows a custom overlay.
///
/// Two modes:
/// - Passive (default): uses `NSEvent.addGlobalMonitorForEvents(.systemDefined)`.
///   Observes only; macOS still processes the key press and shows its own HUD.
/// - True replacement (opt-in, Accessibility permission required):
///   Installs a `CGEvent.tapCreate` at `.cgSessionEventTap`. When a volume key
///   fires we consume the event (return nil) and change the volume directly via
///   CoreAudio. With the key event dropped, the system volume HUD never fires.
@MainActor
final class SystemHUDService: ObservableObject {
    let onHUDEvent = PassthroughSubject<HUDEvent, Never>()

    @Published private(set) var trueReplacementEnabled: Bool = false
    @Published private(set) var lastError: String?

    private var globalMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        startPassiveMonitor()
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        // Tap cleanup relies on main-actor state — rely on process-exit cleanup
        // instead of touching it from deinit.
    }

    // MARK: Passive monitor (always on when true replacement is off)

    private func startPassiveMonitor() {
        stopPassiveMonitor()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in self.handlePassive(event) }
        }
    }

    private func stopPassiveMonitor() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    private func handlePassive(_ event: NSEvent) {
        guard let info = Self.decodeMediaKey(nsEvent: event) else { return }
        guard info.keyDown else { return }
        emitHUD(for: info.keyCode)
    }

    // MARK: True replacement (opt-in)

    func setTrueReplacementEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            // Prompt the system dialog on first toggle so Island auto-appears
            // in Privacy & Security → Accessibility. The call returns immediately;
            // the user accepts asynchronously, so we also retry briefly below.
            if !requestAccessibilityPermission() {
                waitForAccessibility(timeout: 0.6)
            }
            guard hasAccessibilityPermission() else {
                lastError = "Accessibility permission required. Approve Island in the system dialog (or add /Applications/IslandApp.app manually under Privacy & Security → Accessibility), then toggle again."
                trueReplacementEnabled = false
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                return
            }
            if startTap() {
                stopPassiveMonitor()
                trueReplacementEnabled = true
            } else {
                lastError = "Couldn't install the event tap. Make sure IslandApp is enabled under Privacy & Security → Accessibility."
                trueReplacementEnabled = false
            }
        } else {
            stopTap()
            startPassiveMonitor()
            trueReplacementEnabled = false
        }
    }

    private func hasAccessibilityPermission() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Triggers the system's Accessibility prompt and registers Island under
    /// Privacy & Security → Accessibility. Returns true if already granted.
    @discardableResult
    private func requestAccessibilityPermission() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func waitForAccessibility(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasAccessibilityPermission() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func startTap() -> Bool {
        stopTap()
        let mask = CGEventMask(1 << UInt32(NSEvent.EventType.systemDefined.rawValue))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: systemHUDTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = src
        return true
    }

    private func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
    }

    /// Called from the C tap callback on the main runloop. Returns nil to drop the
    /// event (the default system processing will NOT run — no system HUD, no
    /// volume change — we do the volume change ourselves via CoreAudio). Returns
    /// `Unmanaged.passUnretained(event)` to let the event through untouched.
    fileprivate func handleTappedEvent(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == UInt32(NSEvent.EventType.systemDefined.rawValue) else {
            return Unmanaged.passUnretained(event)
        }
        guard let ns = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        guard let info = Self.decodeMediaKey(nsEvent: ns) else {
            return Unmanaged.passUnretained(event)
        }
        // Only act on key-down. Key-up events are let through as-is so no key
        // stuck state ever persists.
        guard info.keyDown else {
            return Unmanaged.passUnretained(event)
        }

        switch info.keyCode {
        case KeyCode.soundUp.rawValue:
            adjustVolume(delta: +0.0625) // 1/16th; matches macOS 16-step HUD
            emitHUD(for: info.keyCode)
            return nil
        case KeyCode.soundDown.rawValue:
            adjustVolume(delta: -0.0625)
            emitHUD(for: info.keyCode)
            return nil
        case KeyCode.mute.rawValue:
            toggleMute()
            emitHUD(for: info.keyCode)
            return nil
        default:
            // Brightness and others: let through (we only replace volume).
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: CoreAudio helpers

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    func currentSystemVolume() -> Double {
        guard let id = defaultOutputDeviceID() else { return 0 }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &volume)
        return status == noErr ? Double(volume) : 0
    }

    func isSystemMuted() -> Bool {
        guard let id = defaultOutputDeviceID() else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &muted)
        return status == noErr && muted != 0
    }

    private func setSystemVolume(_ value: Float32) {
        guard let id = defaultOutputDeviceID() else { return }
        var v = max(0, min(1, value))
        let size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(id, &addr, 0, nil, size, &v)
    }

    private func setSystemMute(_ muted: Bool) {
        guard let id = defaultOutputDeviceID() else { return }
        var v: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(id, &addr, 0, nil, size, &v)
    }

    private func adjustVolume(delta: Float32) {
        if isSystemMuted() { setSystemMute(false) }
        let next = Float32(currentSystemVolume()) + delta
        setSystemVolume(next)
    }

    private func toggleMute() {
        setSystemMute(!isSystemMuted())
    }

    // MARK: HUD emission

    private func emitHUD(for keyCode: Int) {
        switch keyCode {
        case KeyCode.soundUp.rawValue, KeyCode.soundDown.rawValue:
            let vol = currentSystemVolume()
            onHUDEvent.send(HUDEvent(kind: .volume, primaryValue: vol, isMuted: isSystemMuted(), ttl: 1.5))
        case KeyCode.mute.rawValue:
            onHUDEvent.send(HUDEvent(kind: .volume, primaryValue: currentSystemVolume(), isMuted: isSystemMuted(), ttl: 1.5))
        case KeyCode.brightnessUp.rawValue, KeyCode.brightnessDown.rawValue:
            onHUDEvent.send(HUDEvent(kind: .brightness, primaryValue: readUserBrightness(), ttl: 1.5))
        default: break
        }
    }

    func readUserBrightness() -> Double {
        CoreDisplayBrightness.get(displayID: CGMainDisplayID()) ?? 0.5
    }

    // MARK: Media-key decoding

    struct MediaKeyInfo {
        let keyCode: Int
        let keyDown: Bool
    }

    /// NX_SYSDEFINED events encode media keys in `data1`. Standard decoding per
    /// hidsystem/ev_keymap.h:
    ///   keyCode  = (data1 & 0xFFFF0000) >> 16
    ///   keyFlags = data1 & 0x0000FFFF
    ///   keyState = (keyFlags & 0xFF00) >> 8 == 0x0A  (NX_KEYDOWN)
    static func decodeMediaKey(nsEvent: NSEvent) -> MediaKeyInfo? {
        // Subtype 8 is NX_SUBTYPE_AUX_CONTROL_BUTTONS.
        guard nsEvent.subtype.rawValue == 8 else { return nil }
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
        return MediaKeyInfo(keyCode: keyCode, keyDown: keyDown)
    }

    enum KeyCode: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }
}

/// C tap callback must be a plain function, not a method.
private let systemHUDTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<SystemHUDService>.fromOpaque(userInfo).takeUnretainedValue()
    // Tap callback is invoked on the main runloop thread; we know the service is
    // main-actor-isolated so this hop is sync.
    return MainActor.assumeIsolated {
        service.handleTappedEvent(type, event)
    }
}

// MARK: - Private brightness SPI wrapper

enum CoreDisplayBrightness {
    private static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW)
    }()

    typealias GetFn = @convention(c) (CGDirectDisplayID) -> Double

    private static let getFn: GetFn? = {
        guard let handle else { return nil }
        guard let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetFn.self)
    }()

    static func get(displayID: CGDirectDisplayID) -> Double? {
        guard let fn = getFn else { return nil }
        let value = fn(displayID)
        if value.isFinite && (0.0...1.0).contains(value) { return value }
        return nil
    }
}
