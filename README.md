# IslandApp


So annoying that people make you pay for these dynamic island apps. Simple one here for free. Follow instructions to install

## Requirements

- macOS 14 Sonoma or newer (26.x tested)
- Xcode Command Line Tools (`xcode-select --install`)

The one-shot installer below takes care of the rest (Homebrew + XcodeGen).

## Install

**One-shot (fresh Mac, nothing set up):**

```sh
curl -fsSL https://raw.githubusercontent.com/stefanbocane/DynamicIslandMacCreation-/main/bootstrap.sh | bash
```

This installs Homebrew + xcodegen if missing, clones the repo to `~/Developer/IslandApp`, then runs `install.sh` which sets up stable code signing, builds Release, installs to `/Applications/`, and launches.

**Already cloned?** Just rebuild:

```sh
cd ~/Developer/IslandApp && ./install.sh
```

Grant macOS permissions the first time you see the prompts; they'll persist across every future rebuild because signing is stable. Flip **Launch at Login** in Settings and it comes up on boot like any other Mac app.

## Build (Xcode, for development)

```sh
cd ~/Developer/IslandApp
xcodegen generate
open IslandApp.xcodeproj
```

Product → Run. The app launches hidden (no Dock icon); a pill appears under the notch. Status-bar icon in the top-right lets you quit.

## Permissions

On first use, macOS will prompt for:

| Permission | Trigger | What it's for |
|---|---|---|
| Calendar | First fetch | Show next event |
| Automation (Spotify) | First transport control | Playback controls, artwork fallback |
| Bluetooth | First AirPods connect | Battery levels |
| Accessibility | Only if you enable "True Volume HUD replacement" | Consume key events to suppress system HUD |
| Login Item | First toggle on in Settings | Auto-launch |

If you deny one, the corresponding feature gracefully degrades. Toggle in Settings shows status + a button that opens the right System Settings pane.

## Settings

General tab:
- **Launch at login** — auto-start on boot (requires install to `/Applications/`).
- **True volume HUD replacement** — opt-in, needs Accessibility permission. Suppresses the stock macOS volume HUD so only Island's pill shows.
- **Hide when a fullscreen app is playing audio** — turn off to keep the pill visible over fullscreen video / games.

## Architecture

Short version: a borderless `NSPanel` hugs the notch; SwiftUI renders inside; a `WidgetRouter` picks the active widget by priority (transient HUD → Spotify → Calendar → idle); services publish state via Combine.

## Notes

- App Sandbox is off by design — `CGEventTap`, `IOBluetooth`, `IOKit`, and AppleEvents are all sandbox-hostile.
- Self-signed (`setup-signing.sh` creates a stable identity in your login keychain). Not notarized, not for the App Store.
- MediaRemote private framework is *not* used; Apple broke third-party access in macOS 15.4. Spotify is read via `DistributedNotificationCenter` + AppleScript only.
