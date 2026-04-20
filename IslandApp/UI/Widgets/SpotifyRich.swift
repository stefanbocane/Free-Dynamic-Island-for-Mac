import SwiftUI

/// Rich Spotify widget shown in expanded state: larger art, progress bar,
/// big primary play button. Replaces the old split between expanded and detail.
struct SpotifyRich: View {
    @EnvironmentObject var spotify: SpotifyService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                artwork

                VStack(alignment: .leading, spacing: 3) {
                    Text(spotify.nowPlaying.title.isEmpty ? "Not playing" : spotify.nowPlaying.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(spotify.nowPlaying.artist)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    Text(spotify.nowPlaying.album)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button { spotify.openInSpotify() } label: {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            progressBar

            HStack(spacing: 26) {
                Spacer()
                RichTransport(system: "backward.fill", size: 18) { spotify.previousTrack() }
                RichTransport(
                    system: spotify.nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                    size: 24,
                    prominent: true,
                    accent: accentColor
                ) { spotify.playPause() }
                RichTransport(system: "forward.fill", size: 18) { spotify.nextTrack() }
                Spacer()
            }
        }
        .overlay(AccentShader(color: spotify.accentColor.map { Color(nsColor: $0) }).opacity(0.3))
    }

    private var accentColor: Color {
        if let c = spotify.accentColor { return Color(nsColor: c) }
        return .green
    }

    @ViewBuilder
    private var artwork: some View {
        if let img = spotify.artwork {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: accentColor.opacity(0.45), radius: 12, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                )
        }
    }

    private var progressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, CGFloat(progress) * proxy.size.width))
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatTime(spotify.nowPlaying.positionSeconds))
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(formatTime(spotify.trackDuration ?? 0))
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var progress: Double {
        guard let total = spotify.trackDuration, total > 0 else { return 0 }
        return min(1.0, max(0.0, spotify.nowPlaying.positionSeconds / total))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct RichTransport: View {
    let system: String
    let size: CGFloat
    var prominent: Bool = false
    var accent: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(prominent ? Color.black : .white)
                .frame(width: prominent ? 50 : 36, height: prominent ? 50 : 36)
                .background(
                    Circle()
                        .fill(prominent ? accent : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
