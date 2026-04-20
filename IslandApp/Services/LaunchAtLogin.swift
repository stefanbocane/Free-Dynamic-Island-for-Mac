import Foundation
import AppKit
import ServiceManagement

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var isEnabled: Bool { status == .enabled }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch let error as NSError {
            if error.code == 125 {
                lastError = "macOS rejected the login item (error 125). Move IslandApp.app to /Applications and try again."
            } else {
                lastError = error.localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}
