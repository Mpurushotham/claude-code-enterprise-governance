# Claude Code enterprise governance

A complete, runnable governance platform for rolling out **Claude Code on Claude Enterprise subscription seats** across an organization — policy floor, runtime guardrails, security pipelines, evidence, and MDM distribution — for a fictional company, **ABC org**, enabling five teams: dev, engineering, product, database, and security.

**The stance, in one line:** prompts are guidance; managed settings, exit-2 hooks, GitHub rulesets, and the Enterprise admin console are the controls.

## Architecture — one diagram per layer

| Layer | Doc |
|-------|-----|
| End-to-end overview | [docs/architecture/00-platform-overview.md](docs/architecture/00-platform-overview.md) |
| Identity & seats (SSO/SCIM → forced org login) | [01-identity-and-seats.md](docs/architecture/01-identity-and-seats.md) |
| Policy floor & the one-way valve | [02-policy-layer.md](docs/architecture/02-policy-layer.md) |
| Runtime guardrails (5 hooks) | [03-runtime-guardrails.md](docs/architecture/03-runtime-guardrails.md) |
| CI/CD security pipeline (7 workflows) | [04-cicd-security-pipeline.md](docs/architecture/04-cicd-security-pipeline.md) |
| Evidence & telemetry (3 independent streams) | [05-evidence-and-telemetry.md](docs/architecture/05-evidence-and-telemetry.md) |
| Distribution via MDM (self-healing) | [06-distribution-mdm.md](docs/architecture/06-distribution-mdm.md) |
| Threat model (attack path → control matrix) | [07-threat-model.md](docs/architecture/07-threat-model.md) |

Plus: [SECURITY-GUARDRAILS.md](docs/SECURITY-GUARDRAILS.md) — every guardrail from scratch to end (blocks what, enforced by what, proven by what, evidences where) — and the phased [ENTERPRISE-ROLLOUT-PLAN.md](docs/ENTERPRISE-ROLLOUT-PLAN.md).

## Repo map

| Path | What | Owner |
|------|------|-------|
| `policy/` | base floor, tier0/1/2 profiles, team cohorts, repo map, MCP catalog | sec-platform |
| `ci/` | `compose.sh` (one-way valve), `validate-settings.sh` (invariant gate) | sec-platform |
| `plugins/abc-guardrails/` | secrets-gate, bash-sentry, pii-filter, audit-scribe, session-banner | sec-platform |
| `agents/` | 4 read-only review agents (security, IaC, compliance, supply-chain) | sec-platform |
| `skills/`, `commands/` | `/security-review` orchestration | platform-eng |
| `.github/workflows/` | 7 pipelines, all actions SHA-pinned | platform-eng + sec-platform |
| `terraform/` | evidence sink only: KMS + versioned bucket + Athena | cloud-platform |
| `ops/` | nightly Compliance API → evidence bucket export | sec-platform |
| `mdm/` | checksum-verified, atomic, self-healing deploy script | IT |
| `tests/` | 28 adversarial + invariant cases | sec-platform |

## Try it in 2 minutes (no cloud, no seats needed)

```bash
# 1. Compose the strictest tier and validate every invariant
ci/compose.sh tier0 > dist/managed-settings.tier0.json
ci/validate-settings.sh dist/managed-settings.tier0.json

# 2. Run the full adversarial suite (block AND must-not-block cases)
tests/test_hooks.sh

# 3. Watch a live-credential paste get blocked (exit 2)
echo '{"tool_name":"Bash","tool_input":{"command":"export T=ghp_abcdefghijklmnopqrstuvwxyz0123456789"}}' \
  | plugins/abc-guardrails/hooks/secrets-gate.sh; echo "exit=$?"
```

## The five invariants (CI-enforced, never regress)

1. Deterministic enforcement only — no prompt is a control.
2. One-way valve — lower layers only narrow; an allow never pierces a managed deny.
3. No static credentials on laptops — subscription seats for humans; the single Console API key lives in CI secrets.
4. Everything emits evidence — three independent streams.
5. Bypass permissions mode disabled fleet-wide.

## Adapting to your org

Search-and-replace `abc-org` / `ABC`, set your real `forceLoginOrgUUID` in `policy/base.json`, point the OTel and guardrails endpoints at your collectors, map your repos in `policy/repos.yaml`, and configure branch rulesets making the four blocking workflows + CODEOWNERS required on `main`.

## Known deferrals (honest list)

- `forceLoginMethod` / `forceLoginOrgUUID` key names should be verified against the current Claude Code settings schema (`/doctor`) before fleet deploy — key names evolve between releases.
- `ops/compliance-export.sh` encodes the flow, not a frozen API contract — confirm the Compliance/usage endpoint shape against current docs; it requires an Enterprise org admin token.
- `tier-stamp` needs a fine-grained org token (`TIER_STAMP_TOKEN`) to open PRs; it dry-runs without one.
- The guardrails HTTP collector (`guardrails.internal.abc-org.example`) is a placeholder endpoint — stand up a receiver or rely on streams 2+3.
- Branch rulesets (required checks, CODEOWNERS review) must be configured in GitHub itself; the repo ships the checks, not the ruleset.
