# 06 — Distribution (MDM)

Blunt version: **policy reaches laptops as a checksum-verified, root-owned file that heals itself on every MDM check-in.** Users can't edit it, and deleting it buys minutes, not freedom.

```mermaid
sequenceDiagram
    participant GH as GitHub release<br/>(policy-release workflow)
    participant MDM as MDM (Mosyle)
    participant Mac as Managed Mac (root)
    participant FS as /Library/Application Support/ClaudeCode

    GH->>GH: artifacts + SHA256SUMS on merge to main
    loop every device check-in
        MDM->>Mac: run mdm/mdm-deploy.sh as root
        Mac->>GH: fetch latest managed-settings.json + SHA256SUMS
        Mac->>Mac: verify checksum — abort on mismatch
        Mac->>FS: atomic install, root:wheel 0644<br/>(+ managed CLAUDE.md)
        Note over FS: local tampering overwritten —<br/>self-healing by construction
    end
```

## Controls at this layer

| Control | Mechanism |
|---------|-----------|
| Integrity | SHA256 verified against the release manifest before install; mismatch = no install |
| Immutability to users | root:wheel 0644 in a system path — admin rights required to touch it |
| Atomicity | `install` to temp + rename; never a half-written policy file |
| Self-healing | re-installed on every check-in; drift lifetime = one MDM sync interval |
| Provenance | artifact traceable to a `main` commit that passed validate + tests + CODEOWNERS review |

## What breaks if this layer is bypassed

A user with admin rights who deletes the file gets an unmanaged session until the next check-in — but stream 3 evidence ([05](05-evidence-and-telemetry.md)) still records their seat usage server-side, and fleet telemetry going dark for one device is itself an alertable signal. Residual risk is bounded by check-in frequency; set it accordingly.
