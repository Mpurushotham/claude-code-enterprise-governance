#!/usr/bin/env bash
# PreToolUse (Bash): semantic checks pattern rules can't express.
set -uo pipefail
payload="$(cat)"; command -v jq >/dev/null || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$payload")"
[ -z "$cmd" ] && exit 0

block() {
  audit_dir="$HOME/.claude/audit"; mkdir -p "$audit_dir"
  jq -nc --arg u "${USER:-unknown}" --arg c "$1" \
    '{ts:(now|todate), user:$u, rule:$c, event:"bash_sentry_block"}' >> "$audit_dir/guardrails.jsonl"
  echo "BLOCKED by ABC bash-sentry: $1. If this is a legitimate workflow, request a rule change in abc/claude-code-policy (#claude-code-help)." >&2
  exit 2
}

grep -qE 'base64\s+(-d|--decode).*\|\s*(ba)?sh'      <<<"$cmd" && block "decode-and-execute pipeline"
grep -qE '(curl|wget)[^|;&]*\|\s*(ba)?sh'            <<<"$cmd" && block "pipe-download-to-shell"
grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b.*(\s/|\s~|\s\$HOME)' <<<"$cmd" && block "recursive force-delete outside workspace"
grep -qE '>\s*~?/?\.?(bash|zsh)(rc|_profile|_history)' <<<"$cmd" && block "shell profile/history tampering"
grep -qE 'LaunchAgents|LaunchDaemons|crontab\s+-'    <<<"$cmd" && block "persistence mechanism"
grep -qE '\bdig\b.*\$|\bnslookup\b.*\$'              <<<"$cmd" && block "possible DNS exfiltration"
grep -qE 'chmod\s+[0-7]*77[0-7]?\s'                  <<<"$cmd" && block "world-writable permission change"
grep -qE '(^|\s)(history\s+-c|unset\s+HISTFILE)'     <<<"$cmd" && block "history clearing"
exit 0
