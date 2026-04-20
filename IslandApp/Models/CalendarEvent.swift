import Foundation
import AppKit

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarColor: NSColor
    let meetingURL: URL?
    let externalCalendarURL: URL?

    var minutesUntilStart: Int {
        Int(start.timeIntervalSinceNow / 60.0)
    }

    var isImminent: Bool {
        let diff = start.timeIntervalSinceNow
        return diff > -60 && diff <= 120
    }

    var isUpcomingSoon: Bool {
        let diff = start.timeIntervalSinceNow
        return diff > 0 && diff <= 15 * 60
    }
}
