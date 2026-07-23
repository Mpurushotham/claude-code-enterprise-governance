---
name: abc-secure-review
description: Run ABC's security review process on the current change set. Use when reviewing code before a PR, or when asked for a security review.
disable-model-invocation: false
---
# ABC secure review

1. Determine the change set: `git diff main...HEAD` (or staged changes if no branch diff).
2. Delegate analysis to the `security-reviewer` agent with the diff as context — always.
3. Route additional specialists by what the diff touches:
   - `*.tf` or CDK code → `iac-reviewer`, with any `terraform plan` / `cdk diff`
     output from CI artifacts.
   - package manifests, lockfiles, Dockerfiles, or `.github/workflows/**` →
     `supply-chain-reviewer`.
   - data models, migrations, logging, fixtures, analytics, or export flows →
     `compliance-reviewer`.
4. Summarize findings by severity, deduplicated across agents. Criticals and
   highs get a proposed fix diff.
5. Remind the author: deterministic gates (secret-scan, iac-scan, dependency
   review, hook tests, human review) still decide the merge — this review is
   additive, not a sign-off.
