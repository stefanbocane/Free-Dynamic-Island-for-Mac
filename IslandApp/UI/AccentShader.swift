import SwiftUI

/// Subtle radial glow border tinted from the current Spotify album art accent color.
/// Invisible when no accent is available.
struct AccentShader: View {
    let color: Color?

    var body: some View {
        GeometryReader { proxy in
            if let color {
                RadialGradient(
                    colors: [color.opacity(0.55), color.opacity(0.0)],
                    center: .bottom,
                    startRadius: proxy.size.width * 0.1,
                    endRadius: proxy.size.width * 0.6
                )
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}
