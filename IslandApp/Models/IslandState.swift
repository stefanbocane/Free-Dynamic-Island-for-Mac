import Foundation

enum IslandState: Equatable {
    case compact
    case expanded
    case transientHUD(HUDEvent)
    case hidden

    var isCompact: Bool { if case .compact = self { return true }; return false }
    var isExpanded: Bool { if case .expanded = self { return true }; return false }
    var isHUD: Bool { if case .transientHUD = self { return true }; return false }
    var isHidden: Bool { if case .hidden = self { return true }; return false }

    /// Kept for API compatibility with code that used to check detail state.
    /// Detail is now merged into expanded.
    var isDetail: Bool { false }

    var activeHUD: HUDEvent? {
        if case let .transientHUD(hud) = self { return hud }
        return nil
    }
}

enum ActiveWidget: Equatable {
    case spotify
    case calendar
    case idle
}
