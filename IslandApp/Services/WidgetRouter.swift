import Foundation
import Combine

/// Decides which widget currently owns the pill. Single-slot HUD; most-recent HUD wins.
/// Incoming HUDs while the user is actively hovering are dropped (never yank the view).
@MainActor
final class WidgetRouter: ObservableObject {
    @Published private(set) var currentHUD: HUDEvent?
    @Published private(set) var activeWidget: ActiveWidget = .idle

    private weak var spotify: SpotifyService?
    private weak var calendar: CalendarService?

    private var cancellables: Set<AnyCancellable> = []
    private var hudTimer: Timer?
    private var isUserHovering: Bool = false

    init(spotify: SpotifyService,
         calendar: CalendarService,
         hudSource: PassthroughSubject<HUDEvent, Never>...) {
        self.spotify = spotify
        self.calendar = calendar

        for source in hudSource {
            source
                .receive(on: DispatchQueue.main)
                .sink { [weak self] hud in self?.push(hud: hud) }
                .store(in: &cancellables)
        }

        spotify.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.recompute() }
            .store(in: &cancellables)
        calendar.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.recompute() }
            .store(in: &cancellables)

        recompute()
    }

    func setHovering(_ hovering: Bool) {
        isUserHovering = hovering
    }

    func push(hud: HUDEvent) {
        if isUserHovering { return } // hover override
        currentHUD = hud
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: hud.ttl, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.currentHUD?.id == hud.id {
                    self.currentHUD = nil
                }
            }
        }
    }

    func clearHUDIfExpired() {
        if let h = currentHUD, h.isExpired { currentHUD = nil }
    }

    private func recompute() {
        guard let spotify, let calendar else {
            activeWidget = .idle
            return
        }
        // Priority for persistent widgets when no HUD.
        if let next = calendar.nextEvent, next.isImminent {
            activeWidget = .calendar
            return
        }
        if spotify.nowPlaying.isPlaying {
            activeWidget = .spotify
            return
        }
        if let next = calendar.nextEvent, next.isUpcomingSoon {
            activeWidget = .calendar
            return
        }
        if spotify.nowPlaying.hasTrack {
            activeWidget = .spotify
            return
        }
        activeWidget = .idle
    }
}
