#!/usr/bin/env bash
# Structural validation of composed policy. Fails the PR on violations.
# NOTE: also run the artifact through a current Claude Code `/doctor` in CI
# container before release — key names evolve between releases.
set -euo pipefail
F="${1:-dist/managed-settings.json}"
fail() { echo "POLICY VALIDATION FAILED: $*" >&2; exit 1; }

jq empty "$F" || fail "not valid JSON"

# Invariants that must never regress (the floor's floor):
[ "$(jq -r '.permissions.disableBypassPermissionsMode' "$F")" = "disable" ] \
  || fail "bypass mode must be disabled"
[ "$(jq -r '.allowManagedHooksOnly' "$F")" = "true" ] \
  || fail "allowManagedHooksOnly must be true"
[ "$(jq -r '.forceLoginMethod' "$F")" = "claudeai" ] \
  || fail "login must be pinned to claude.ai subscription auth (no API keys on laptops)"
[ "$(jq -r '.forceLoginOrgUUID' "$F")" != "null" ] \
  || fail "org UUID must be pinned so personal claude.ai accounts cannot be used"
[ "$(jq -r '.apiKeyHelper // empty' "$F")" = "" ] \
  || fail "apiKeyHelper must not be set — seats are for humans, API keys live only in CI"
jq -e '.env | has("ANTHROPIC_API_KEY") | not' "$F" >/dev/null \
  || fail "ANTHROPIC_API_KEY must never appear in managed settings"
jq -e '.permissions.deny | index("WebFetch")' "$F" >/dev/null \
  || fail "WebFetch must remain denied"
jq -e '.permissions.deny | map(select(test("^Read.*aws"))) | length > 0' "$F" >/dev/null \
  || fail "~/.aws must remain unreadable"
# allow rules must never mention paths/commands that appear in deny (sanity overlap check)
OVERLAP=$(jq -r '[.permissions.allow[] as $a | .permissions.deny[] | select(. == $a)] | length' "$F")
[ "$OVERLAP" = "0" ] || fail "identical rule present in both allow and deny"

echo "policy OK: $F ($(jq -r '."$composed".tier' "$F"))"
