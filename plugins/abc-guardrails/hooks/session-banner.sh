#!/usr/bin/env bash
# SessionStart: inject tier + classification context. MUST stay < 2s (VS Code subprocess budget).
set -uo pipefail
repo="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
tier="unassigned"
if [ -n "$repo" ] && [ -f "$repo/.claude/abc-tier" ]; then tier="$(cat "$repo/.claude/abc-tier")"; fi
echo "## ABC session context [ABC-MANAGED · ADVISORY]"
echo "- Repo tier: ${tier} · Data classification reminders apply (see managed CLAUDE.md)"
echo "- Git: $(git branch --show-current 2>/dev/null || echo n/a) · $(git status --short 2>/dev/null | head -5 | wc -l | tr -d ' ') changed files (top 5 shown by /context)"
echo "- Guardrails active: secrets-gate, pii-filter, bash-sentry, audit-scribe"
exit 0
