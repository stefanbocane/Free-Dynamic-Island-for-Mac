import Foundation
import AppKit
import Combine

@MainActor
final class SpotifyService: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying = .empty
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accentColor: NSColor?
    @Published private(set) var trackDuration: TimeInterval?

    private let artworkCache = NSCache<NSString, NSImage>()
    private var durationCache: [String: TimeInterval] = [:]
    private var positionTicker: AnyCancellable?
    private var artworkTask: URLSessionDataTask?
    private var accentTask: Task<Void, Never>?
    nonisolated(unsafe) private static let accentExtractor = AccentColorExtractor()

    init() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        refreshViaAppleScript()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleSpotifyNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let trackID = (info["Track ID"] as? String) ?? ""
        let title = (info["Name"] as? String) ?? ""
        let artist = (info["Artist"] as? String) ?? ""
        let album = (info["Album"] as? String) ?? ""
        let state = (info["Player State"] as? String) ?? ""
        let isPlaying = (state.lowercased() == "playing")
        let position: Double = {
            if let n = info["Playback Position"] as? NSNumber { return n.doubleValue }
            if let d = info["Playback Position"] as? Double { return d }
            return 0
        }()
        let artURLString = info["Artwork URL"] as? String
        let artURL = artURLString.flatMap { URL(string: $0) }

        let np = NowPlaying(
            trackID: trackID,
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            positionSeconds: position,
            artworkURL: artURL
        )
        Task { @MainActor in self.apply(np) }
    }

    private func apply(_ np: NowPlaying) {
        let trackChanged = np.trackID != nowPlaying.trackID
        nowPlaying = np
        if trackChanged {
            loadArtwork(for: np)
            loadDuration(for: np)
        }
        restartPositionTicker()
    }

    /// Spotify only sends a position value on state-change events (play/pause/skip),
    /// not continuously. To make the progress bar + time label feel live we advance
    /// the published position locally by 0.5s while `isPlaying == true`. When the
    /// next real notification arrives, its authoritative position overwrites ours.
    private func restartPositionTicker() {
        positionTicker?.cancel()
        guard nowPlaying.isPlaying else { return }
        positionTicker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.nowPlaying.isPlaying else { return }
                let np = self.nowPlaying
                // Don't walk past the known duration — Spotify will re-sync at the
                // real track change and we don't want negative time-left.
                let cap = self.trackDuration.map { $0 + 0.5 } ?? .infinity
                let nextPos = min(np.positionSeconds + 0.5, cap)
                self.nowPlaying = NowPlaying(
                    trackID: np.trackID,
                    title: np.title,
                    artist: np.artist,
                    album: np.album,
                    isPlaying: np.isPlaying,
                    positionSeconds: nextPos,
                    artworkURL: np.artworkURL
                )
            }
    }

    private func loadDuration(for np: NowPlaying) {
        guard !np.trackID.isEmpty else {
            trackDuration = nil
            return
        }
        if let cached = durationCache[np.trackID] {
            trackDuration = cached
            return
        }
        trackDuration = nil
        Task.detached(priority: .utility) {
            let source = """
            tell application "Spotify"
                if it is running then
                    try
                        return duration of current track
                    on error
                        return "0"
                    end try
                end if
                return "0"
            end tell
            """
            guard let raw = AppleScriptRunner.run(source), let ms = Double(raw), ms > 0 else { return }
            // Spotify returns duration in milliseconds.
            let seconds = ms / 1000.0
            await MainActor.run {
                if np.trackID == self.nowPlaying.trackID {
                    self.durationCache[np.trackID] = seconds
                    self.trackDuration = seconds
                }
            }
        }
    }

    private func loadArtwork(for np: NowPlaying) {
        artworkTask?.cancel()
        accentTask?.cancel()
        artwork = nil
        accentColor = nil

        let cacheKey = np.trackID as NSString
        if !np.trackID.isEmpty, let cached = artworkCache.object(forKey: cacheKey) {
            artwork = cached
            extractAccent(from: cached, for: np.trackID)
            return
        }

        func assign(_ image: NSImage) {
            if !np.trackID.isEmpty {
                artworkCache.setObject(image, forKey: cacheKey)
            }
            artwork = image
            extractAccent(from: image, for: np.trackID)
        }

        if let url = np.artworkURL {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let img = NSImage(data: data) else {
                    Task { @MainActor in self?.fallbackToAppleScriptArtwork(for: np) }
                    return
                }
                Task { @MainActor in assign(img) }
            }
            artworkTask = task
            task.resume()
        } else {
            fallbackToAppleScriptArtwork(for: np)
        }
    }

    private func fallbackToAppleScriptArtwork(for np: NowPlaying) {
        Task.detached(priority: .utility) {
            let source = """
            tell application "Spotify"
                if it is running then
                    try
                        return artwork url of current track
                    on error
                        return ""
                    end try
                end if
                return ""
            end tell
            """
            let urlString = AppleScriptRunner.run(source) ?? ""
            guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
            let data = try? Data(contentsOf: url)
            if let data, let img = NSImage(data: data) {
                await MainActor.run {
                    if np.trackID == self.nowPlaying.trackID {
                        self.artworkCache.setObject(img, forKey: np.trackID as NSString)
                        self.artwork = img
                        self.extractAccent(from: img, for: np.trackID)
                    }
                }
            }
        }
    }

    private func extractAccent(from image: NSImage, for trackID: String) {
        accentTask?.cancel()
        accentTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let color = SpotifyService.accentExtractor.dominantAccent(from: image)
            await MainActor.run {
                if trackID == self.nowPlaying.trackID {
                    self.accentColor = color
                }
            }
        }
    }

    private func refreshViaAppleScript() {
        Task.detached(priority: .utility) {
            let source = """
            tell application "Spotify"
                if it is running then
                    try
                        set tid to id of current track
                        set tn to name of current track
                        set ta to artist of current track
                        set tl to album of current track
                        set aurl to artwork url of current track
                        set ps to player state as string
                        set pp to player position
                        return tid & "\\n" & tn & "\\n" & ta & "\\n" & tl & "\\n" & aurl & "\\n" & ps & "\\n" & pp
                    on error
                        return ""
                    end try
                end if
                return ""
            end tell
            """
            guard let raw = AppleScriptRunner.run(source), !raw.isEmpty else { return }
            let parts = raw.components(separatedBy: "\n")
            guard parts.count >= 7 else { return }
            let np = NowPlaying(
                trackID: parts[0],
                title: parts[1],
                artist: parts[2],
                album: parts[3],
                isPlaying: parts[5].lowercased().contains("playing"),
                positionSeconds: Double(parts[6]) ?? 0,
                artworkURL: URL(string: parts[4])
            )
            await MainActor.run { self.apply(np) }
        }
    }

    // MARK: Transport

    func playPause() { _ = AppleScriptRunner.run(#"tell application "Spotify" to playpause"#) }
    func nextTrack() { _ = AppleScriptRunner.run(#"tell application "Spotify" to next track"#) }
    func previousTrack() { _ = AppleScriptRunner.run(#"tell application "Spotify" to previous track"#) }

    func openInSpotify() {
        let trackID = nowPlaying.trackID
        guard !trackID.isEmpty else { return }
        if let url = URL(string: "spotify:track:\(trackID)") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum AppleScriptRunner {
    @discardableResult
    static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
}
