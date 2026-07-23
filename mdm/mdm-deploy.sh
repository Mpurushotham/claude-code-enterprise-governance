#!/bin/bash
# Mosyle "Custom Command" script. Runs as root on managed Macs on every sync.
# Fetches the released policy artifact, verifies checksum, installs atomically.
set -euo pipefail
RELEASE_URL="https://github.com/abc/claude-code-policy/releases/latest/download"
DEST_DIR="/Library/Application Support/ClaudeCode"
TMP="$(mktemp -d)"

curl -fsSL "$RELEASE_URL/managed-settings.json" -o "$TMP/managed-settings.json"
curl -fsSL "$RELEASE_URL/SHA256SUMS" -o "$TMP/SHA256SUMS"
(cd "$TMP" && grep ' managed-settings.json$' SHA256SUMS | shasum -a 256 -c -)

mkdir -p "$DEST_DIR"
install -m 0644 -o root -g wheel "$TMP/managed-settings.json" "$DEST_DIR/managed-settings.json"
# Managed memory ships alongside policy
curl -fsSL "https://raw.githubusercontent.com/abc/claude-code-policy/main/managed/CLAUDE.md" \
  -o "$TMP/CLAUDE.md" && install -m 0644 -o root -g wheel "$TMP/CLAUDE.md" "$DEST_DIR/CLAUDE.md"

echo "abc-claude-policy installed: $(shasum -a 256 "$DEST_DIR/managed-settings.json" | cut -c1-16)"
# Drift self-heals: Mosyle re-runs this on every check-in.
