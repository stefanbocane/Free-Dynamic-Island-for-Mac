import SwiftUI

@main
struct IslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsScene()
                .environmentObject(appDelegate.controller.accessibility)
                .environmentObject(appDelegate.controller.launchAtLogin)
                .environmentObject(appDelegate.controller.system)
                .environmentObject(appDelegate.controller.calendar)
                .environmentObject(appDelegate.controller.notes)
                .environmentObject(appDelegate.controller.fullscreen)
                .environmentObject(appDelegate.controller)
                .frame(minWidth: 460, minHeight: 440)
        }
    }
}
