#!/bin/bash
# bootstrap.sh
#
# One-shot installer for IslandApp. Designed to be piped directly from GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/stefanbocane/DynamicIslandMacCreation-/main/bootstrap.sh | bash
#
# What it does:
#   1. Ensures xcodegen is available — prefers Homebrew if present, otherwise
#      downloads the official xcodegen binary to ~/.islandapp-tools (no admin
#      required, so it works on managed / non-admin accounts).
#   2. Clones (or updates) the repo at ~/Developer/IslandApp.
#   3. Runs ./install.sh which handles signing, build, /Applications install.
#
# Safe and idempotent — re-run any time to pull the latest and reinstall.

set -e

REPO_URL="https://github.com/stefanbocane/DynamicIslandMacCreation-.git"
TARGET_DIR="${HOME}/Developer/IslandApp"

log()  { printf "\033[1;34m→\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# macOS only.
[ "$(uname)" = "Darwin" ] || die "IslandApp is macOS-only."

# Xcode command-line tools.
if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools (GUI prompt will appear)"
    xcode-select --install || true
    echo "  Finish the install in the popup, then re-run this command."
    exit 0
fi

# Pick up a brew that's already installed but not on PATH (common when brew is
# present but the user's shell hasn't sourced shellenv yet).
if ! command -v brew >/dev/null 2>&1; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# xcodegen — prefer brew when it's available, otherwise drop a standalone
# binary into a user-owned prefix. Avoids requiring admin/sudo.
TOOLS_DIR="${HOME}/.islandapp-tools"
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        log "Installing xcodegen via Homebrew"
        brew install xcodegen
    else
        log "Fetching xcodegen binary (no Homebrew required)"
        mkdir -p "$TOOLS_DIR"
        curl -fsSL https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip \
            -o "$TOOLS_DIR/xcodegen.zip"
        rm -rf "$TOOLS_DIR/xcodegen"
        unzip -oq "$TOOLS_DIR/xcodegen.zip" -d "$TOOLS_DIR"
        rm -f "$TOOLS_DIR/xcodegen.zip"
        chmod +x "$TOOLS_DIR/xcodegen/bin/xcodegen"
        export PATH="$TOOLS_DIR/xcodegen/bin:$PATH"
    fi
fi

# If we fetched the binary in a previous run, make sure it's on PATH.
if ! command -v xcodegen >/dev/null 2>&1 && [ -x "$TOOLS_DIR/xcodegen/bin/xcodegen" ]; then
    export PATH="$TOOLS_DIR/xcodegen/bin:$PATH"
fi

command -v xcodegen >/dev/null 2>&1 || die "xcodegen install failed — see output above."

# Clone or update.
mkdir -p "$(dirname "$TARGET_DIR")"
if [ -d "$TARGET_DIR/.git" ]; then
    log "Updating existing clone at $TARGET_DIR"
    git -C "$TARGET_DIR" fetch --quiet origin
    git -C "$TARGET_DIR" reset --hard origin/main
else
    log "Cloning IslandApp into $TARGET_DIR"
    git clone --quiet "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

# Delegate to the in-repo installer.
log "Running install.sh"
./install.sh

ok "Done. IslandApp is installed at /Applications/IslandApp.app and running."
ok "Grant the macOS permission prompts once; they persist across rebuilds."
