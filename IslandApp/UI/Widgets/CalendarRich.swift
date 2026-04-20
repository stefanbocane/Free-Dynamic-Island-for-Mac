import SwiftUI

/// Rich Calendar widget: next event prominent, today's agenda below.
struct CalendarRich: View {
    @EnvironmentObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let next = calendar.nextEvent {
                nextEventRow(next)
            } else {
                Text("Nothing next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if !calendar.todaysEvents.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))

                Text(calendar.agendaLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(calendar.todaysEvents.prefix(6)) { e in
                            agendaRow(e)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func nextEventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: 4, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(countdown(for: event))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            if let url = event.meetingURL, event.isImminent {
                Button { NSWorkspace.shared.open(url) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                        Text("Join")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.9))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func agendaRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: 3, height: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeLabel(event))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
    }

    private func countdown(for event: CalendarEventItem) -> String {
        let mins = event.minutesUntilStart
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        if event.isImminent { return mins <= 0 ? "Happening now" : "in \(mins) min · \(fmt.string(from: event.start))" }
        if mins < 60 { return "in \(mins) min · \(fmt.string(from: event.start))" }
        return "in \(mins / 60)h \(mins % 60)m · \(fmt.string(from: event.start))"
    }

    private func timeLabel(_ event: CalendarEventItem) -> String {
        if event.isAllDay { return "All day" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return "\(fmt.string(from: event.start)) – \(fmt.string(from: event.end))"
    }
}
