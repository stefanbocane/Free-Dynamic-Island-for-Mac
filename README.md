# IslandApp


So annoying that people make you pay for these dynamic island apps. Simple one here for free. Follow instructions to install

## Requirements

- macOS 13 Ventura or newer (26.x tested)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

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

## Feature flags

Settings scene:
- **Launch at login** — on/off
- **Show Spotify / Calendar / Volume / Brightness / AirPods / Charging / File drop** — per-widget toggles
- **True volume HUD replacement** — opt-in, needs Accessibility permission

## Architecture

See `~/.claude/plans/yeah-real-design-and-splendid-pizza.md` for the full design. Short version: a single borderless `NSPanel` hugs the notch; SwiftUI renders inside; a `WidgetRouter` picks the active widget based on priority (transient HUD → Spotify → Calendar → idle); services publish state via Combine.

## Notes

- App Sandbox is off by design. We need `CGEventTap`, `IOBluetooth`, `IOKit`, and AppleEvents — all sandbox-hostile.
- Ad-hoc signed (`codesign --sign -`). Not for distribution. Personal use only.
- MediaRemote private framework is *not* used; Apple broke third-party access in macOS 15.4 (2025). Spotify is read via `DistributedNotificationCenter` + AppleScript only.
