# CLAUDE.md — IslandApp

Context for agents working in this repo. Read before touching signing, permissions, or the pill window layout.

## The product

Personal Dynamic Island for macOS. A borderless `NSPanel` anchored to the notch, SwiftUI content, LSUIElement (no Dock icon). Shows Spotify / calendar / volume / brightness / charging. Unsandboxed by design — uses `CGEventTap`, `IOKit`, AppleEvents.

## How to work on it

- Edit `project.yml` or `IslandApp/**` — **not** the generated `IslandApp.xcodeproj/`.
- `./install.sh` is the canonical build+install command. It runs `xcodegen`, builds Release, and drops the bundle into `/Applications/`. Use it instead of `Product → Run` in Xcode when verifying user-facing behavior — Xcode builds live in a temp derived-data path that breaks launch-at-login and clobbers TCC.
- `./setup-signing.sh` is idempotent and called transitively by `install.sh`. Don't duplicate its logic.
- SourceKit inside Claude Code flags cross-file references (`Cannot find type 'HUDEvent' in scope`) constantly — it doesn't know the module graph. **Ignore those diagnostics unless `xcodebuild` itself reports the same error.** Check `BUILD SUCCEEDED` in the `./install.sh` output instead.

## Signing / TCC gotchas (hit repeatedly — read first)

1. **Ad-hoc signing (`-`) gives a new cdhash every build.** macOS TCC (the permission database) keys permissions by cdhash, so every rebuild re-prompts for Calendar / Automation / Accessibility. `setup-signing.sh` fixes this by creating a self-signed cert `"IslandApp Self Signed"` in the login keychain and patching `project.yml` to use it. Always verify the project is using this identity before spending time debugging "permission loss" bugs.

2. **OpenSSL 3 ↔ macOS `security import` incompatibility.** The default PKCS#12 format OpenSSL 3 writes uses SHA-256 MAC which `security import` can't decrypt with an empty password. Fix: `-legacy` flag **plus** a non-empty throwaway passphrase. `-legacy` alone is not enough — the MAC algorithm is the breaking piece. See `setup-signing.sh`.

3. **Accessibility permission needs `kAXTrustedCheckOptionPrompt: true` to surface the system dialog.** Calling with `false` only checks silently. `SystemHUDService.requestAccessibilityPermission()` uses `true` on user action and falls back to opening `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` if the dialog doesn't appear.

4. **Stale TCC entries survive a reinstall.** If a user removed the old Xcode-built IslandApp from Accessibility and the new one won't auto-register, have them run `tccutil reset Accessibility com.sbocanegra.IslandApp` and re-toggle. The "allowed" row in the pane points at a specific cdhash — a name match isn't enough.

5. **Launch-at-login only works from `/Applications/`.** `SMAppService.mainApp.register()` silently fails (error 125) from Xcode's derived-data path. Don't debug it from there.

## Panel layout

- The panel is top-anchored (flush with `screen.frame.maxY`) for all non-HUD states so hover events remain captured when the cursor drifts into the menu-bar strip. Do **not** move the panel downward for `.compact` / `.expanded` — you'll break hover tracking around the notch.
- `.transientHUD` is the exception: it's offset below the menu bar (`layout()` in `IslandPanelController.swift`) so the HUD pill hangs as a floating indicator and doesn't cover the status-bar icons. Transient HUDs have no hover interaction, so the top-anchor rule doesn't apply.
- `preferredSize(for:metrics:)` has a distinct case per state. If you add a new state, add its size explicitly — reusing `.expanded`'s dimensions for small HUDs produces stretched giant pills (the first bug users report).
- `contentTopPadding(for:)` is separate from the panel Y offset; it controls SwiftUI-side top padding. Keep the two consistent when changing sizing.

## NotchGeometry

- On non-notched displays the geometry returns a synthetic 210-px "notch" centered on `frame.midX` (see `NotchGeometry.metrics`). The pill renders in that synthetic location. Don't assume `hasNotch == true` when implementing new widgets.
- Multi-display: `preferredScreen()` prefers the screen with a physical notch, then the mouse's screen, then main. Widgets must not hard-code to `NSScreen.main`.

## Design/UX conventions

- Pill background is a solid near-black rounded rectangle (corner radius 22). No translucency by default (looks bad against the black notch on OLED). `AccessibilityPreferences.reduceTransparency` collapses further to opaque black.
- HUD widgets share the `.transientHUD` slot. 1.5s default TTL. Most-recent wins. Hover suppresses incoming HUDs (see `WidgetRouter.push`).
- Volume HUD uses a waveform-equalizer visualizer (`WaveformEqualizer` in `VolumeHUD.swift`) with a violet→pink hue sweep. Match that accent family for future HUDs so the pill has visual cohesion.

## User preferences

- `FullscreenWatcher.hideOnFullscreen` — persisted via `UserDefaults`. Default `true`. Exposed in Settings → General → Behavior. Detection uses the private `CGSCopyManagedDisplaySpaces` (type 4 = native fullscreen Space) plus a `CGWindowListCopyWindowInfo` size-match fallback for exclusive-mode games. **Don't try to hide via collection behavior** — `.canJoinAllSpaces` puts the panel on every Space (including fullscreen) regardless of whether `.fullScreenAuxiliary` is present, contrary to what Apple's docs imply. Hiding is done by `IslandPanelController` calling `panel.orderOut(nil)` / `orderFrontRegardless()` from the `$shouldHidePanel` observer — instant, no alpha-fade, since `activeSpaceDidChangeNotification` only fires after the Space transition completes (any animated hide flickers visibly).
- `SystemHUDService.trueReplacementEnabled` — runtime only (not persisted across launches). Requires Accessibility.

## Release / distribution

- Ad-hoc / self-signed only. Not notarized. Not for the App Store.
- One-shot install via `bootstrap.sh` — piped from raw.githubusercontent.com. That script bootstraps Homebrew + xcodegen, clones the repo, and chains into `install.sh`.
- If you change the repo URL or default branch, update both `bootstrap.sh` and the About tab code block in `SettingsScene.swift`.
