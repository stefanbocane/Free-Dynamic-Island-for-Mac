# IslandApp


So annoying that people make you pay for these dynamic island apps. Simple one here for free. Follow instructions to install

## Requirements

- macOS 13 Ventura or newer (26.x tested)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```sh
cd ~/Developer/IslandApp
xcodegen generate
open IslandApp.xcodeproj
```

Product → Run from Xcode. The app will launch hidden (no Dock icon); a pill appears at the top of the notched display. A status-bar icon in the top-right lets you quit.

## Install to /Applications (required for launch-at-login)

`SMAppService.mainApp.register()` only works reliably when the app lives at a stable path. To enable launch-at-login:

```sh
# From inside Xcode: Product → Archive → Export → save somewhere
# Or, build from CLI:
xcodebuild -project IslandApp.xcodeproj -scheme IslandApp -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/IslandApp.app /Applications/
```

Then open `/Applications/IslandApp.app`, enable the Launch at Login toggle in Settings.

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
