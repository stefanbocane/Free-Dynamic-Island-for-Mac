import SwiftUI
import EventKit
import ServiceManagement
import AppKit
import IOBluetooth

struct SettingsScene: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PermissionsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 480, minHeight: 480)
    }
}

// MARK: - General tab

struct GeneralTab: View {
    @EnvironmentObject var launch: LaunchAtLogin
    @EnvironmentObject var system: SystemHUDService
    @EnvironmentObject var fullscreen: FullscreenWatcher
    @EnvironmentObject var accessibility: AccessibilityPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionHeader("Launch")
                launchBox

                sectionHeader("HUDs")
                hudBox

                sectionHeader("Appearance")
                appearanceBox

                sectionHeader("Behavior")
                behaviorBox

                Spacer()
            }
            .padding(22)
        }
    }

    private var appearanceBox: some View {
        SettingsBox {
            HStack {
                Text("Pill opacity")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int((accessibility.pillOpacity * 100).rounded()))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $accessibility.pillOpacity, in: 0.5...1.0, step: 0.05)
                .disabled(accessibility.reduceTransparency)

            Text(accessibility.reduceTransparency
                ? "System Reduce Transparency is on — pill is forced to 100%."
                : "100% is solid black. Lower values let the wallpaper show through the pill body.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var behaviorBox: some View {
        SettingsBox {
            Toggle(isOn: $fullscreen.hideOnFullscreen) {
                Text("Hide when a fullscreen app is active")
                    .font(.system(size: 13, weight: .medium))
            }
            Text("Turn off to keep the pill visible on top of fullscreen apps. Island still uses a non-activating panel so it won't steal focus.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var launchBox: some View {
        SettingsBox {
            Toggle(isOn: Binding(
                get: { launch.isEnabled },
                set: { launch.setEnabled($0) }
            )) {
                Text("Launch Island at login")
                    .font(.system(size: 13, weight: .medium))
            }

            if let err = launch.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }

            Text("Island lives in the menu bar and runs hidden. For launch-at-login to work reliably, install the app to /Applications/ (see instructions under About).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var hudBox: some View {
        SettingsBox {
            Toggle("True volume HUD replacement", isOn: Binding(
                get: { system.trueReplacementEnabled },
                set: { system.setTrueReplacementEnabled($0) }
            ))
                .font(.system(size: 13, weight: .medium))

            if let err = system.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                HStack {
                    Button("Open Accessibility Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    Button("Re-check") {
                        system.setTrueReplacementEnabled(system.trueReplacementEnabled)
                    }
                }
            }

            Text("When on, Island intercepts the volume keys with a CGEventTap and changes volume via CoreAudio. The default macOS volume HUD no longer shows. Requires Accessibility permission on the Permissions tab.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Permissions tab

struct PermissionsTab: View {
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var launch: LaunchAtLogin
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Grant the permissions below for each feature. Island works even if you skip any of these — the affected feature simply degrades.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                PermissionCard(
                    title: "Calendar",
                    icon: "calendar",
                    status: calendarStatus,
                    statusTint: calendar.isAuthorized ? .green : .orange,
                    explanation: "Shows your next event, today's agenda, and a Join button for Zoom/Meet/Teams events.",
                    howTo: "Click Request, then allow Calendar access in the popup. If the popup doesn't appear, open System Settings → Privacy & Security → Calendar and enable IslandApp.",
                    actions: {
                        Button("Request") { calendar.requestAccess() }
                            .disabled(calendar.isAuthorized)
                        Button("Open System Settings") {
                            openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                        }
                    }
                )

                PermissionCard(
                    title: "Apple Events (Spotify)",
                    icon: "music.note",
                    status: "Prompt appears on first use",
                    statusTint: .secondary,
                    explanation: "Lets Island control Spotify playback (play/pause/skip) and fetch album artwork when it's missing from the standard notification.",
                    howTo: "macOS will prompt the first time you hit a transport button. If you denied it, toggle IslandApp → Spotify in System Settings → Privacy & Security → Automation.",
                    actions: {
                        Button("Open System Settings") {
                            openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
                        }
                    }
                )

                PermissionCard(
                    title: "Accessibility",
                    icon: "person.wave.2",
                    status: accessibilityGranted ? "Granted" : "Not granted",
                    statusTint: accessibilityGranted ? .green : .orange,
                    explanation: "Only needed for the \"true volume HUD replacement\" option on the General tab. Without it, the system HUD still appears alongside Island's.",
                    howTo: "Click Open System Settings. Add or enable IslandApp under Privacy & Security → Accessibility, then re-launch.",
                    actions: {
                        Button("Re-check") {
                            accessibilityGranted = AXIsProcessTrusted()
                        }
                        Button("Open System Settings") {
                            openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                        }
                    }
                )

                PermissionCard(
                    title: "Bluetooth",
                    icon: "airpodspro",
                    status: "Prompt appears on first use",
                    statusTint: .secondary,
                    explanation: "Reads AirPods / Bluetooth headphone battery levels so Island can show a little battery pill when they connect.",
                    howTo: "The prompt appears when AirPods connect for the first time. If denied, toggle IslandApp in System Settings → Privacy & Security → Bluetooth.",
                    actions: {
                        Button("Open System Settings") {
                            openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
                        }
                    }
                )

                PermissionCard(
                    title: "Login Item",
                    icon: "power",
                    status: launch.isEnabled ? "Enabled" : "Disabled",
                    statusTint: launch.isEnabled ? .green : .secondary,
                    explanation: "Makes Island auto-launch when you log in. Requires the app to live at a stable path — install it to /Applications/ first.",
                    howTo: "Toggle \"Launch Island at login\" on the General tab. If you see error 125, move IslandApp.app to /Applications/ and try again.",
                    actions: {
                        Button(launch.isEnabled ? "Disable" : "Enable") {
                            launch.setEnabled(!launch.isEnabled)
                        }
                        Button("Open System Settings") {
                            openURL("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                        }
                    }
                )
            }
            .padding(22)
        }
        .onAppear { accessibilityGranted = AXIsProcessTrusted() }
    }

    private var calendarStatus: String {
        switch calendar.authorizationStatus {
        case .authorized, .fullAccess: return "Granted"
        case .writeOnly: return "Write-only (limited)"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested yet"
        @unknown default: return "Unknown"
        }
    }

    private func openURL(_ s: String) {
        guard let url = URL(string: s) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - About tab

struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Island")
                        .font(.system(size: 24, weight: .bold))
                    Text("Personal Dynamic Island for macOS.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Version 0.1.0 · macOS 14+")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("One-shot install from anywhere")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Paste this into Terminal on a fresh Mac — it clones the repo, sets up stable code signing, builds Release, installs to /Applications/, and launches. Re-run any time to update.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    codeBlock("""
                    curl -fsSL https://raw.githubusercontent.com/stefanbocane/Free-Dynamic-Island-for-Mac/main/bootstrap.sh | bash
                    """)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Update your local copy")
                        .font(.system(size: 14, weight: .semibold))
                    Text("If the repo is already cloned, just run install.sh. Stable self-signing means your granted permissions stick across every rebuild.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    codeBlock("""
                    cd ~/Developer/IslandApp
                    ./install.sh
                    """)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Features at a glance")
                        .font(.system(size: 14, weight: .semibold))
                    BulletList(items: [
                        "Click the pill to expand; click again or move mouse away to collapse.",
                        "Spotify widget: live-ticking progress bar, transport controls, album-art accent.",
                        "Calendar widget: next event with Join button for Zoom/Meet/Teams links; rolls over to tomorrow when today is done.",
                        "Sticky notes panel: + to add, click to edit, persists across launches.",
                        "Transient HUDs for volume, brightness, AirPods battery, charging.",
                        "File drop zone: drag a file onto the pill for AirDrop / Copy-Path / Move-to-Desktop.",
                        "Auto-hide when a fullscreen app is active."
                    ])
                }
                Spacer()
            }
            .padding(22)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .textSelection(.enabled)
    }
}

// MARK: - Shared building blocks

struct SettingsBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8, content: { content })
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PermissionCard<Actions: View>: View {
    let title: String
    let icon: String
    let status: String
    let statusTint: Color
    let explanation: String
    let howTo: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusTint.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(explanation)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(howTo)
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.top, 2)
            HStack(spacing: 8) {
                actions
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundStyle(.secondary)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
