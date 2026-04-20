import SwiftUI

struct VolumeHUD: View {
    let event: HUDEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
            ValueBar(value: event.primaryValue, accent: .white)
        }
        .padding(.horizontal, 14)
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
                    .frame(width: max(4, CGFloat(value) * proxy.size.width))
            }
        }
        .frame(height: height)
    }
}
