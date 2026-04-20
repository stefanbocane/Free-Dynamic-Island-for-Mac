#!/bin/bash
# bootstrap.sh
#
# One-shot installer for IslandApp. Designed to be piped directly from GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/stefanbocane/DynamicIslandMacCreation-/main/bootstrap.sh | bash
#
# What it does:
#   1. Installs Homebrew if missing.
#   2. Installs xcodegen via brew.
#   3. Clones (or updates) the repo at ~/Developer/IslandApp.
#   4. Runs ./install.sh which handles signing, build, /Applications install.
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

# Homebrew.
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this session.
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# xcodegen.
if ! command -v xcodegen >/dev/null 2>&1; then
    log "Installing xcodegen"
    brew install xcodegen
fi

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
