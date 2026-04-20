import SwiftUI

struct VolumeHUD: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hue: 0.80, saturation: 0.9, brightness: 1.0),
                                 Color(hue: 0.95, saturation: 0.9, brightness: 1.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: Color(hue: 0.9, saturation: 0.8, brightness: 1.0).opacity(0.55), radius: 5)
                .frame(width: 22, height: 22)

            WaveformEqualizer(level: event.isMuted ? 0 : event.primaryValue)
                .frame(height: 18)

            Text("\(Int((event.primaryValue * 100).rounded()))")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        if event.isMuted { return "speaker.slash.fill" }
        switch event.primaryValue {
        case 0: return "speaker.fill"
        case 0..<0.33: return "speaker.wave.1.fill"
        case 0.33..<0.66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

/// 18-bar audio-waveform visualizer whose bars form a sine-wave envelope.
/// Lit bars get a hue-shifting violet→pink→cyan gradient with a neon glow;
/// unlit bars are dim rails. Scales with the container height.
struct WaveformEqualizer: View {
    let level: Double
    private let barCount = 20

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let threshold = (Double(i) + 0.5) / Double(barCount)
                    let isLit = level >= threshold
                    let h = barHeight(index: i, maxHeight: proxy.size.height)
                    Capsule(style: .continuous)
                        .fill(isLit ? AnyShapeStyle(litGradient(for: i)) : AnyShapeStyle(Color.white.opacity(0.10)))
                        .frame(width: 2.5, height: h)
                        .shadow(color: isLit ? glowColor(for: i).opacity(0.7) : .clear, radius: 3)
                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isLit)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }

    private func barHeight(index: Int, maxHeight: CGFloat) -> CGFloat {
        let t = Double(index) / Double(max(barCount - 1, 1))
        let env = sin(t * .pi)
        return maxHeight * (0.32 + 0.68 * env)
    }

    private func litGradient(for index: Int) -> LinearGradient {
        let t = Double(index) / Double(max(barCount - 1, 1))
        let hue = 0.78 + t * 0.17
        let top = Color(hue: hue.truncatingRemainder(dividingBy: 1.0), saturation: 0.88, brightness: 1.0)
        let bot = Color(hue: hue.truncatingRemainder(dividingBy: 1.0), saturation: 0.95, brightness: 0.78)
        return LinearGradient(colors: [top, bot], startPoint: .top, endPoint: .bottom)
    }

    private func glowColor(for index: Int) -> Color {
        let t = Double(index) / Double(max(barCount - 1, 1))
        let hue = (0.78 + t * 0.17).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.9, brightness: 1.0)
    }
}
