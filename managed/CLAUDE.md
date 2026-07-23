<!-- [ABC-MANAGED · ADVISORY · sec-platform] guidance only; enforcement lives in managed settings -->
# ABC engineering context
- You are operating inside ABC org on a Claude Enterprise seat. Repo tier and data classification are injected at SessionStart.
- Customer data never enters prompts or fixtures. Use @abc/test-fixtures or the anonymized Athena marts.
- Secrets are referenced by secret-manager ARN/path, never by value. Reads of secret material are blocked.
- Never configure an API key in Claude Code — your subscription seat is your only credential, and login is pinned to the ABC org.
- Infrastructure changes ship via PR + pipeline. Never attempt to apply/deploy from a session.
- Prefer the golden paths: /security-review before requesting review; abc-service-blueprint for new services.
- If a guardrail blocks you and seems wrong: #claude-code-help. Do not work around it.
