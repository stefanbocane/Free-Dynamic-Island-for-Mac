import Foundation
import AppKit

struct NowPlaying: Equatable {
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let positionSeconds: Double
    let artworkURL: URL?

    static let empty = NowPlaying(
        trackID: "",
        title: "",
        artist: "",
        album: "",
        isPlaying: false,
        positionSeconds: 0,
        artworkURL: nil
    )

    var hasTrack: Bool { !trackID.isEmpty }
}
