import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: IslandPanelController
    private var statusItem: NSStatusItem!

    override init() {
        self.controller = IslandPanelController()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installStatusItem()

        // Trigger Calendar permission prompt on first run; Spotify/Bluetooth prompt
        // on first interaction. Accessibility and LoginItem are opt-in from Settings.
        controller.calendar.requestAccess()

        let key = "didOfferLoginItem"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.fill", accessibilityDescription: "Island")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Island", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .islandOpenSettings, object: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let islandOpenSettings = Notification.Name("islandapp.openSettings")
}
