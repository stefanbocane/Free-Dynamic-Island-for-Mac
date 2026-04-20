import SwiftUI

struct CompactView: View {
    @EnvironmentObject var controller: IslandPanelController
    @EnvironmentObject var spotify: SpotifyService
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var router: WidgetRouter

    var body: some View {
        HStack(spacing: 0) {
            leftSide
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            notchSpacer
            rightSide
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .frame(height: notchHeight + 4)
    }

    @ViewBuilder
    private var leftSide: some View {
        switch router.activeWidget {
        case .spotify:
            SpotifyCompact()
        case .calendar:
            CalendarCompact()
        case .idle:
            if spotify.nowPlaying.hasTrack {
                SpotifyCompact()
            } else if calendar.nextEvent != nil {
                CalendarCompact()
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private var rightSide: some View {
        if spotify.nowPlaying.isPlaying {
            MiniWaveform(color: spotifyTint)
        } else if let next = calendar.nextEvent, next.minutesUntilStart <= 60, next.minutesUntilStart >= 0 {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(nsColor: next.calendarColor))
                    .frame(width: 7, height: 7)
                Text(countdown(for: next))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else {
            MiniClock()
        }
    }

    private var spotifyTint: Color {
        if let c = spotify.accentColor { return Color(nsColor: c) }
        return .green
    }

    private var notchSpacer: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: (controller.metrics?.notchWidth ?? 190) + 8)
    }

    private var notchHeight: CGFloat {
        controller.metrics?.notchHeight ?? 32
    }

    private func countdown(for e: CalendarEventItem) -> String {
        let m = e.minutesUntilStart
        if m <= 0 { return "now" }
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h"
    }
}

/// Smaller waveform visualization for the right-of-notch slot.
struct MiniWaveform: View {
    let color: Color
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: 4 + CGFloat(abs(sin(phase + Double(i) * 0.7)) * 9))
            }
        }
        .frame(width: 20, height: 14)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
