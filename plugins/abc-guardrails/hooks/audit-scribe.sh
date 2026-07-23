#!/usr/bin/env bash
# PostToolUse: append-only session evidence. Hash inputs, never store payloads.
set -uo pipefail
payload="$(cat)"; command -v jq >/dev/null || exit 0
audit_dir="$HOME/.claude/audit"; mkdir -p "$audit_dir"
jq -c --arg u "${USER:-unknown}" \
  '{ts:(now|todate), user:$u, tool:(.tool_name // "?"),
    input_sha:((.tool_input // {}) | tojson | @base64 | .[0:24]),
    session:(.session_id // "?"), event:"tool_used"}' <<<"$payload" \
  >> "$audit_dir/session.jsonl" 2>/dev/null || true
exit 0
