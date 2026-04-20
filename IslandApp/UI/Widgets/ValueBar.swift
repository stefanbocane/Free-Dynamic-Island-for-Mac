import SwiftUI

/// Simple capsule progress bar shared by HUD widgets that don't use a custom
/// visualizer (brightness, charging, AirPods). VolumeHUD uses its own
/// WaveformEqualizer instead.
struct ValueBar: View {
    let value: Double
    let accent: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(accent)
                    .frame(width: max(4, CGFloat(min(max(value, 0), 1)) * proxy.size.width))
            }
        }
        .frame(height: height)
    }
}
