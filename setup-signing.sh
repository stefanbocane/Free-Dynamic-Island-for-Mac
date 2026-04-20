#!/bin/bash
# setup-signing.sh
#
# Creates a self-signed code-signing certificate in the login keychain so
# IslandApp can be signed with a STABLE identity across rebuilds. Without this,
# ad-hoc signing (`-`) gives a new cdhash every build, which causes macOS TCC
# (the permissions database) to forget every previously-granted permission on
# every launch.
#
# Run once. The project.yml already references the cert name below. After this
# succeeds, rebuild the project — permissions will persist.
#
# Safe to re-run; exits early if the cert is already present.

set -e

CERT_NAME="IslandApp Self Signed"

if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "✓ Certificate '$CERT_NAME' is already in the login keychain."
    echo "  Existing signing identities:"
    security find-identity -v -p codesigning | grep -i island || true
    exit 0
fi

echo "→ Generating self-signed code-signing certificate: '$CERT_NAME'"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

# 10-year self-signed cert with code-signing extended key usage.
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout key.pem -out cert.pem -days 3650 \
    -subj "/CN=$CERT_NAME" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "basicConstraints=critical,CA:FALSE" \
    2>/dev/null

# Bundle into PKCS#12 so `security import` accepts it.
# OpenSSL 3 uses AES-256-CBC + SHA-256 MAC by default, which `security import`
# on macOS cannot decrypt with an empty password. Using `-legacy` plus a
# throwaway passphrase avoids both incompatibilities — the passphrase is only
# used to wrap the transient .p12 file and is discarded with the tmpdir.
P12_PASS="islandapp"
openssl pkcs12 -export -legacy -out cert.p12 -inkey key.pem -in cert.pem \
    -password "pass:${P12_PASS}"

# Import the keypair into the login keychain, granting codesign access.
security import cert.p12 -k ~/Library/Keychains/login.keychain-db \
    -P "${P12_PASS}" -T /usr/bin/codesign >/dev/null

# Trust the cert so codesign accepts it without prompting.
security add-trusted-cert -d -r trustRoot \
    -k ~/Library/Keychains/login.keychain-db cert.pem >/dev/null 2>&1 || \
    echo "  (note: add-trusted-cert may have prompted for admin password)"

echo "✓ Certificate imported."
echo

# Patch project.yml to use the cert, then regenerate the Xcode project so the
# user doesn't have to do it manually.
PROJECT_YML="$(dirname "$0")/project.yml"
if [ -f "$PROJECT_YML" ] && grep -q 'CODE_SIGN_IDENTITY: "-"' "$PROJECT_YML"; then
    echo "→ Patching project.yml to use '$CERT_NAME'"
    /usr/bin/sed -i '' "s|CODE_SIGN_IDENTITY: \"-\"|CODE_SIGN_IDENTITY: \"$CERT_NAME\"|" "$PROJECT_YML"
    if command -v xcodegen >/dev/null 2>&1; then
        echo "→ Regenerating Xcode project"
        (cd "$(dirname "$0")" && xcodegen generate) >/dev/null
    fi
fi

echo
echo "✓ All set. Rebuild the app — permissions granted to IslandApp will now"
echo "  persist across future builds because every build signs with the same"
echo "  stable identity. macOS TCC no longer treats each build as a new app."
