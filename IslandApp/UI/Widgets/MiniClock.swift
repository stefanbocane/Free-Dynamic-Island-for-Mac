import SwiftUI
import Combine

/// Tight monospaced time display for the compact right-of-notch slot.
/// Refreshes every 20s — good enough for a minute-precision clock.
struct MiniClock: View {
    @State private var now: Date = Date()
    @State private var timer: AnyCancellable?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: now))
            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
            .onAppear {
                now = Date()
                timer = Timer.publish(every: 20, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in now = Date() }
            }
            .onDisappear { timer?.cancel() }
    }
}
