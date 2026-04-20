import Foundation
import IOKit
import IOKit.ps
import Combine

@MainActor
final class PowerService: ObservableObject {
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var batteryPercent: Int = 0

    let onChargingPluggedIn = PassthroughSubject<Double, Never>()

    private var runLoopSource: CFRunLoopSource?
    private var lastACState: Bool?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
        }
    }

    private func startObserving() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callback: IOPowerSourceCallbackType = { rawPtr in
            guard let rawPtr else { return }
            let service = Unmanaged<PowerService>.fromOpaque(rawPtr).takeUnretainedValue()
            Task { @MainActor in service.refresh(emitTransition: true) }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func refresh(emitTransition: Bool = false) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        var foundCharging = false
        var pct: Int = 0

        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            if let isCh = desc[kIOPSIsChargingKey] as? Bool { foundCharging = isCh || foundCharging }
            if let state = desc[kIOPSPowerSourceStateKey] as? String, state == kIOPSACPowerValue {
                foundCharging = true
            }
            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                pct = Int((Double(cur) / Double(max)) * 100.0)
            }
        }

        let prev = isCharging
        isCharging = foundCharging
        batteryPercent = pct

        if emitTransition, foundCharging, prev == false {
            onChargingPluggedIn.send(Double(pct))
        }
        lastACState = foundCharging
    }
}
