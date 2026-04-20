import Foundation
import IOBluetooth
import ObjectiveC
import Combine

/// Observes AirPods/Bluetooth headphone connection events and (when supported)
/// reads battery levels via the private `batteryPercent{Left,Right,Case}`
/// Objective-C properties on IOBluetoothDevice.
///
/// NOTE (macOS 26, April 2026): IOBluetoothDevice's connect-notification callback
/// on this macOS version sometimes passes a `device` argument whose underlying
/// Obj-C object has already been released by the time our handler runs. Any
/// access — including `type(of:)` — crashes with EXC_BAD_ACCESS in
/// `swift_getObjectType`. We work around this by never using the `device`
/// argument; instead, on connect we rescan our own paired-connected list,
/// whose references we can safely retain.
@MainActor
final class BluetoothBatteryService: ObservableObject {
    let onBatteryUpdate = PassthroughSubject<HUDEvent, Never>()

    init() {
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(handleConnect))
        readCurrentlyConnected()
    }

    /// NOTE: Do not accept the `device` argument here — its lifetime is not
    /// guaranteed on macOS 26. Rescan instead.
    @objc private func handleConnect() {
        readCurrentlyConnected()
    }

    private func readCurrentlyConnected() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for d in paired where d.isConnected() {
            if let event = buildEvent(for: d) {
                onBatteryUpdate.send(event)
            }
        }
    }

    private func buildEvent(for device: IOBluetoothDevice) -> HUDEvent? {
        let left = readBatteryPercent(device, selector: Selector(("batteryPercentLeft")))
        let right = readBatteryPercent(device, selector: Selector(("batteryPercentRight")))
        let caseP = readBatteryPercent(device, selector: Selector(("batteryPercentCase")))
        let single = readBatteryPercent(device, selector: Selector(("batteryPercent")))

        let candidates = [left, right, caseP, single].filter { $0 > 0 }
        if candidates.isEmpty { return nil }

        let primary = candidates.max() ?? -1
        guard primary >= 0 else { return nil }
        return HUDEvent(
            kind: .airpods,
            primaryValue: Double(primary) / 100.0,
            auxValues: [left, right, caseP, single].map { Double(max($0, -1)) },
            ttl: 3.0
        )
    }

    private func readBatteryPercent(_ device: IOBluetoothDevice, selector: Selector) -> Int {
        let cls: AnyClass = type(of: device)
        guard let method = class_getInstanceMethod(cls, selector) else { return -1 }
        let imp = method_getImplementation(method)
        typealias IntFunc = @convention(c) (AnyObject, Selector) -> Int32
        let fn = unsafeBitCast(imp, to: IntFunc.self)
        return Int(fn(device, selector))
    }
}
