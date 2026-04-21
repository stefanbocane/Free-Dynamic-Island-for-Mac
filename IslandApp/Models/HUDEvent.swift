import Foundation

enum HUDKind: Equatable {
    case volume
    case brightness
    case charging
}

struct HUDEvent: Equatable, Identifiable {
    let id = UUID()
    let kind: HUDKind
    let primaryValue: Double
    let auxValues: [Double]
    let isMuted: Bool
    let createdAt: Date
    let ttl: TimeInterval

    var expiresAt: Date { createdAt.addingTimeInterval(ttl) }
    var isExpired: Bool { Date() >= expiresAt }

    init(kind: HUDKind,
         primaryValue: Double,
         auxValues: [Double] = [],
         isMuted: Bool = false,
         ttl: TimeInterval = 1.5) {
        self.kind = kind
        self.primaryValue = primaryValue
        self.auxValues = auxValues
        self.isMuted = isMuted
        self.createdAt = Date()
        self.ttl = ttl
    }
}
