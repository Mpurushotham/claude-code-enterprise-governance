# Security policy

This repository is the enforcement point for ABC's Claude Code fleet: the policy floor, guardrail hooks, and release pipeline defined here are what every managed laptop runs. Treat every change as a production security change.

## Reporting

- Guardrail bypass, false negative, or policy hole: open a **private** security advisory on this repo (do not file a public issue) or contact sec-platform.
- Blocked by a guardrail that seems wrong: #claude-code-help. Working around a guardrail instead of reporting it is a policy violation.

## Threat model

See [docs/architecture/07-threat-model.md](docs/architecture/07-threat-model.md) — attack paths, the deterministic control stopping each one, and the residual risks we accept with our eyes open.

## Design rules for contributors

1. Controls must be deterministic (settings, exit-2 hooks, rulesets). Prompts are not controls.
2. Every new block rule ships with a block test **and** a must-not-block test.
3. Nothing in this repo may weaken an invariant asserted by `ci/validate-settings.sh` — the PR will fail, by design.
4. All workflow actions are SHA-pinned; the lint enforces it.
