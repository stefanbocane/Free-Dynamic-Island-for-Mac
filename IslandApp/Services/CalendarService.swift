import Foundation
import EventKit
import AppKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var todaysEvents: [CalendarEventItem] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var nextEvent: CalendarEventItem?

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
        refresh()
        startTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.refresh() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.refresh() }
                }
            }
        }
    }

    @objc private func handleStoreChanged() {
        Task { @MainActor in refresh() }
    }

    private func startTimer() {
        // Live updates come from three sources:
        //  1. `.EKEventStoreChanged` — fires when events change in any local
        //     calendar (Calendar.app, direct EventKit writes). Usually instant.
        //  2. 10s timer — backstop for calendars that push events via sync
        //     (iPhone CalDAV, Gmail) without always posting store-changed.
        //  3. didBecomeActive — snap refresh when user switches to IslandApp.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Also refresh when the workspace wakes up from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Events displayed in the "Today" list. If today has no upcoming events
    /// left, this rolls over to tomorrow's events so the pill always shows
    /// something useful when a day is winding down.
    @Published private(set) var agendaLabel: String = "Today"

    func refresh() {
        guard isAuthorized else {
            todaysEvents = []
            nextEvent = nil
            return
        }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now.addingTimeInterval(86_400)
        let dayAfterTomorrow = cal.date(byAdding: .day, value: 2, to: todayStart) ?? now.addingTimeInterval(2 * 86_400)

        let todayEvents = fetch(from: todayStart, to: tomorrowStart)
        let upcomingToday = todayEvents.filter { !$0.isAllDay && $0.end > now }

        // If nothing left today (either empty OR all events ended), roll over to tomorrow.
        if upcomingToday.isEmpty {
            let tomorrowEvents = fetch(from: tomorrowStart, to: dayAfterTomorrow)
            if !tomorrowEvents.isEmpty {
                todaysEvents = tomorrowEvents
                agendaLabel = "Tomorrow"
            } else {
                // Nothing tomorrow either — fall back to showing today's (likely
                // all-day or already-ended) events so the UI isn't empty.
                todaysEvents = todayEvents
                agendaLabel = "Today"
            }
        } else {
            todaysEvents = todayEvents
            agendaLabel = "Today"
        }
        recomputeNext()
    }

    private func fetch(from start: Date, to end: Date) -> [CalendarEventItem] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let color: NSColor = {
                    if let cg = event.calendar?.cgColor { return NSColor(cgColor: cg) ?? .systemBlue }
                    return .systemBlue
                }()
                let meeting = Self.findMeetingURL(notes: event.notes, location: event.location)
                let externalURL: URL? = {
                    if let eid = event.eventIdentifier, !eid.isEmpty {
                        return URL(string: "ical://ekevent/\(eid)")
                    }
                    return nil
                }()
                return CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "(No title)",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarColor: color,
                    meetingURL: meeting,
                    externalCalendarURL: externalURL
                )
            }
    }

    private func recomputeNext() {
        let now = Date()
        // Find the first non-all-day event in our (possibly tomorrow) window that hasn't ended.
        nextEvent = todaysEvents.first { !$0.isAllDay && $0.end > now }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .fullAccess, .writeOnly: return true
        default: return false
        }
    }

    private static let meetingURLRegex: NSRegularExpression? = {
        let pattern = #"https?:\/\/(?:[a-z0-9-]+\.)*(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|bluejeans\.com|whereby\.com|around\.co|gather\.town|hangouts\.google\.com)\/[^\s"'<>]+"#
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    static func findMeetingURL(notes: String?, location: String?) -> URL? {
        let haystack = [notes, location].compactMap { $0 }.joined(separator: "\n")
        guard !haystack.isEmpty, let regex = meetingURLRegex else { return nil }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        guard let match = regex.firstMatch(in: haystack, options: [], range: range),
              let r = Range(match.range, in: haystack) else { return nil }
        return URL(string: String(haystack[r]))
    }
}
