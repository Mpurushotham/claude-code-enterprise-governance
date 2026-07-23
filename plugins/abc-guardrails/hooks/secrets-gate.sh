#!/usr/bin/env bash
# PreToolUse: block Edit/Write/Bash payloads containing live-credential patterns.
# Exit 0 = proceed. Exit 2 = block (stderr is shown to the model).
# Uses gitleaks when installed; otherwise a built-in high-signal pattern set.
set -uo pipefail
payload="$(cat)"
command -v jq >/dev/null || exit 0   # never brick a session on a broken host; drift shows in telemetry

tool="$(jq -r '.tool_name // empty' <<<"$payload")"
content="$(jq -r '
  if .tool_name=="Bash" then (.tool_input.command // "")
  else ((.tool_input.content // "") + " " + (.tool_input.new_string // "")) end' <<<"$payload")"
[ -z "${content// }" ] && exit 0

# Detectors are a union, not a fallback chain: the built-in high-signal set
# always runs (format-valid tokens block even when entropy heuristics pass on
# them), and gitleaks adds breadth where installed.
hit=""
# Built-in: AWS keys, GitHub PATs, Slack tokens, private key blocks, Anthropic keys
if grep -qE 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN( RSA| EC| OPENSSH)? PRIVATE KEY-----|sk-ant-[A-Za-z0-9-]{20,}' <<<"$content"; then
  hit="builtin"
fi
if [ -z "$hit" ] && command -v gitleaks >/dev/null 2>&1; then
  printf '%s' "$content" | gitleaks stdin --no-banner --exit-code 2 \
    --config "$(dirname "$0")/../gitleaks.toml" >/dev/null 2>&1 || hit="gitleaks"
fi
[ -z "$hit" ] && exit 0

# Audit first, block second — evidence survives even if the session dies.
audit_dir="$HOME/.claude/audit"; mkdir -p "$audit_dir"
jq -nc --arg u "${USER:-unknown}" --arg t "$tool" --arg d "$hit" \
  --arg r "$(git rev-parse --show-toplevel 2>/dev/null || echo -)" \
  '{ts:(now|todate), user:$u, tool:$t, repo:$r, detector:$d, event:"secret_blocked"}' \
  | tee -a "$audit_dir/guardrails.jsonl" \
  | curl -s --max-time 2 -X POST -H 'content-type: application/json' \
      -d @- "${ABC_GUARDRAILS_ENDPOINT:-https://guardrails.internal.abc-org.example/events}" >/dev/null 2>&1 || true

echo "BLOCKED by ABC secrets-gate: content matches a live credential pattern. Reference secrets by Secrets Manager ARN/name — never by value." >&2
exit 2
