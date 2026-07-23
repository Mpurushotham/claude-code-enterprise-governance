#!/usr/bin/env bash
# Nightly export of Claude Enterprise org audit data into the evidence bucket.
# This is the third evidence stream (alongside hook JSONL and OTel telemetry):
# the org-side record of who used Claude Code, when, and under which seat.
#
# Auth: COMPLIANCE_API_TOKEN — an Enterprise org admin API token (Compliance
# API access is an Enterprise-plan feature, enabled by an org owner in the
# admin console). Store it in the org secret manager; never on a laptop.
# Schedule: run from a locked-down runner (cron/Scheduled Action) with write
# access to s3://<audit-bucket>/compliance/ only.
#
# NOTE: endpoint path and response shape must be confirmed against the current
# Compliance API docs before production use — this script encodes the flow,
# not a frozen contract.
set -euo pipefail

: "${COMPLIANCE_API_TOKEN:?set COMPLIANCE_API_TOKEN (org admin API token)}"
: "${AUDIT_BUCKET:=abc-claude-audit-evidence}"
API_BASE="${COMPLIANCE_API_BASE:-https://api.anthropic.com/v1/organizations}"
DAY="${1:-$(date -u -v-1d +%F 2>/dev/null || date -u -d 'yesterday' +%F)}"
OUT="$(mktemp -d)/claude-usage-${DAY}.jsonl"

curl -sSf "${API_BASE}/usage_report/claude_code?starting_at=${DAY}&limit=1000" \
  -H "x-api-key: ${COMPLIANCE_API_TOKEN}" \
  -H "anthropic-version: 2023-06-01" \
  -o "$OUT"

aws s3 cp "$OUT" "s3://${AUDIT_BUCKET}/compliance/dt=${DAY}/usage.jsonl" \
  --sse aws:kms
echo "exported ${DAY} -> s3://${AUDIT_BUCKET}/compliance/dt=${DAY}/usage.jsonl"
