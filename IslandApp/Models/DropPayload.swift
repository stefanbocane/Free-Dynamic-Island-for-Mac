import Foundation

enum DropTarget: String, CaseIterable, Identifiable {
    case airdrop
    case copyPath
    case moveToDesktop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .airdrop: return "AirDrop"
        case .copyPath: return "Copy Path"
        case .moveToDesktop: return "To Desktop"
        }
    }

    var systemImage: String {
        switch self {
        case .airdrop: return "airplayaudio"
        case .copyPath: return "doc.on.clipboard"
        case .moveToDesktop: return "desktopcomputer"
        }
    }
}

struct DropPayload: Equatable {
    let urls: [URL]
    var isEmpty: Bool { urls.isEmpty }
}
