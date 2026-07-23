#!/usr/bin/env bash
# Compose managed-settings.json from policy/base.json + a tier profile.
# Usage: ci/compose.sh [tier0|tier1|tier2] > dist/managed-settings.json
# Merge semantics = the one-way valve:
#   - deny/ask arrays: union (tiers may only ADD restriction)
#   - allow arrays: union, but a tier allow never removes a base deny (deny wins at runtime anyway)
#   - scalars/env: tier may add keys, never override base keys
set -euo pipefail
TIER="${1:-tier1}"
BASE="policy/base.json"
PROF="policy/permissions/${TIER}.json"
[ -f "$PROF" ] || { echo "unknown tier: $TIER" >&2; exit 1; }

jq -s '
  def uniq_union(a; b): ((a // []) + (b // [])) | unique;
  .[0] as $base | .[1] as $tier |
  $base
  | .env = (($tier.env // {}) + $base.env)                      # base env keys win
  | .permissions.deny  = uniq_union($base.permissions.deny;  $tier.permissions.deny)
  | .permissions.ask   = uniq_union($base.permissions.ask;   $tier.permissions.ask)
  | .permissions.allow = uniq_union($base.permissions.allow; $tier.permissions.allow)
  | .permissions.defaultMode = ($tier.permissions.defaultMode // $base.permissions.defaultMode)
  | .permissions.disableBypassPermissionsMode = $base.permissions.disableBypassPermissionsMode
  | ."$composed" = { tier: "'"$TIER"'", at: (now | todate) }
  | del(."$comment")
' "$BASE" "$PROF"
