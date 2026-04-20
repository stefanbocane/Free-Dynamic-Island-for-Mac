import SwiftUI

struct CalendarCompact: View {
    @EnvironmentObject var calendar: CalendarService

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            if let label = countdownLabel {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }

    static func dotOnly() -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 6, height: 6)
    }

    private var color: Color {
        guard let next = calendar.nextEvent else { return .gray }
        return Color(nsColor: next.calendarColor)
    }

    private var countdownLabel: String? {
        guard let next = calendar.nextEvent else { return nil }
        let mins = next.minutesUntilStart
        if mins <= 0 { return "now" }
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        return "\(hours)h"
    }
}
