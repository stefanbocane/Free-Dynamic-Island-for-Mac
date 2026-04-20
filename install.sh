#!/bin/bash
# install.sh
#
# Builds IslandApp in Release and installs it to /Applications so it behaves
# like any other Mac app — no more rebuilding from Xcode on every launch.
#
# On first run:
#   1. Sets up a stable self-signed identity (via setup-signing.sh) so macOS
#      TCC remembers granted permissions across rebuilds.
#   2. Generates the Xcode project, builds Release, installs to /Applications.
#   3. Launches the app. Grant permissions once; they'll stick from then on.
#
# Re-run any time you pull changes or want to reinstall. Safe and idempotent.

set -e

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP_NAME="IslandApp"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="${ROOT}/build"

# Prefer /Applications. Fall back to ~/Applications when the user can't write
# to the system-wide location (non-admin / managed accounts). Launch-at-login
# currently needs /Applications to work reliably — the fallback install still
# runs, it just won't auto-start on boot.
SYSTEM_APPS="/Applications"
USER_APPS="${HOME}/Applications"
if [ -w "$SYSTEM_APPS" ]; then
    DEST="${SYSTEM_APPS}/${APP_BUNDLE}"
else
    mkdir -p "$USER_APPS"
    DEST="${USER_APPS}/${APP_BUNDLE}"
fi

log()  { printf "\033[1;34m→\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# Prerequisites
command -v xcodegen >/dev/null 2>&1 || die "xcodegen not found. Install with: brew install xcodegen"
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found. Install Xcode + command-line tools."

# 1. Stable signing identity (idempotent — exits fast if already set up).
log "Ensuring stable code-signing identity"
./setup-signing.sh

# 2. Regenerate Xcode project from project.yml.
log "Generating Xcode project"
xcodegen generate >/dev/null

# 3. If the app is currently running, quit it before replacing the bundle.
if pgrep -x "$APP_NAME" >/dev/null; then
    log "Quitting running ${APP_NAME}"
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
    # Give it a moment; then force-kill anything that refused.
    for _ in 1 2 3 4 5; do
        pgrep -x "$APP_NAME" >/dev/null || break
        sleep 0.3
    done
    pkill -x "$APP_NAME" 2>/dev/null || true
fi

# 4. Build Release. set -o pipefail so xcodebuild's exit status survives the
# grep filter — otherwise a build failure gets silently swallowed and we try
# to install a stale bundle from the previous successful build.
set -o pipefail
log "Building Release (this can take a minute on first run)"
if ! xcodebuild \
        -project "${APP_NAME}.xcodeproj" \
        -scheme "${APP_NAME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}" \
        clean build \
        | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"; then
    die "Build failed. Re-run without the grep filter to see the full log: xcodebuild -project ${APP_NAME}.xcodeproj -scheme ${APP_NAME} -configuration Release -derivedDataPath ${BUILD_DIR} build"
fi
set +o pipefail

BUILT_APP="${BUILD_DIR}/Build/Products/Release/${APP_BUNDLE}"
[ -d "$BUILT_APP" ] || die "Build reported success but ${BUILT_APP} is missing."

# 5. Install to /Applications.
log "Installing to ${DEST}"
rm -rf "$DEST"
cp -R "$BUILT_APP" "$DEST"

# 6. Strip quarantine so Gatekeeper doesn't complain.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# 7. Launch.
log "Launching ${APP_NAME}"
open "$DEST"

ok "Installed to ${DEST}."
ok "Grant macOS permissions once when prompted — they'll persist across future"
ok "rebuilds because signing is stable."
if [ "$DEST" != "${SYSTEM_APPS}/${APP_BUNDLE}" ]; then
    warn "Installed to ~/Applications because /Applications wasn't writable"
    warn "(non-admin account). Launch-at-login needs /Applications — ask an admin"
    warn "to run the installer if you want it to start automatically on boot."
else
    ok "Enable 'Launch at Login' in Settings to have it come up on boot."
fi
