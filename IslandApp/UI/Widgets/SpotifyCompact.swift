import SwiftUI

struct SpotifyCompact: View {
    @EnvironmentObject var spotify: SpotifyService

    var body: some View {
        HStack(spacing: 6) {
            artwork
            if spotify.nowPlaying.isPlaying {
                PlayingBars(color: tint)
            }
        }
        .frame(height: 22)
    }

    static func dotOnly() -> some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
    }

    private var tint: Color {
        if let c = spotify.accentColor { return Color(nsColor: c) }
        return .green
    }

    @ViewBuilder
    private var artwork: some View {
        if let img = spotify.artwork {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.green.opacity(0.8))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black)
                )
        }
    }
}

struct PlayingBars: View {
    let color: Color
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: 10 + CGFloat(sin(phase + Double(i) * 0.9) * 4))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
