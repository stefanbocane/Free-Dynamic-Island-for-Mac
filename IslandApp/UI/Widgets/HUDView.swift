import SwiftUI

struct HUDView: View {
    let event: HUDEvent

    var body: some View {
        switch event.kind {
        case .volume:
            VolumeHUD(event: event)
        case .brightness:
            BrightnessHUD(event: event)
        case .airpods:
            AirPodsBatteryHUD(event: event)
        case .charging:
            ChargingHUD(event: event)
        }
    }
}
