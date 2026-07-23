#!/usr/bin/env python3
"""UserPromptSubmit + PreToolUse(Edit|Write): Nordic-tuned structured-PII gate.
Blocks (exit 2) on validated hits; guidance goes to the model via stderr.
Scope honesty: catches structured identifiers (personnummer, hetu, IBAN, PAN);
free-text PII is handled by upstream controls, not by pretending regex can do it."""
import sys, json, re, os, time

def luhn(digits: str) -> bool:
    d = [int(c) for c in digits if c.isdigit()]
    if len(d) < 10: return False
    total, parity = 0, len(d) % 2
    for i, n in enumerate(d):
        if i % 2 == parity: n *= 2
        total += n - 9 if n > 9 else n
    return total % 10 == 0

def se_personnummer(m: str) -> bool:
    digits = re.sub(r"\D", "", m)
    if len(digits) == 12: digits = digits[2:]          # strip century
    if len(digits) != 10: return False
    mm, dd = int(digits[2:4]), int(digits[4:6])
    if not (1 <= mm <= 12 and 1 <= dd <= 31): return False
    return luhn(digits)

HETU_CHARS = "0123456789ABCDEFHJKLMNPRSTUVWXY"
def fi_hetu(m: str) -> bool:
    body = re.sub(r"[A+-]", "", m[:10])          # ddmmyy + nnn
    if len(body) != 9 or not body.isdigit(): return False
    return HETU_CHARS[int(body) % 31] == m[-1]

RULES = [
    ("personnummer_se", re.compile(r"\b(?:19|20)?\d{6}[-+]?\d{4}\b"), se_personnummer),
    ("hetu_fi",         re.compile(r"\b\d{6}[A+-]\d{3}[0-9A-Y]\b"),   fi_hetu),
    ("iban_nordic",     re.compile(r"\b(?:SE|FI|DK|NO|NL)\d{2}[A-Z0-9]{10,28}\b"), lambda m: True),
    ("card_pan",        re.compile(r"\b(?:\d[ -]?){13,19}\b"),        lambda m: luhn(m) and len(re.sub(r"\D","",m)) >= 13),
]

def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    if payload.get("hook_event_name") == "UserPromptSubmit":
        text = payload.get("prompt", "") or ""
    else:
        ti = payload.get("tool_input", {}) or {}
        text = " ".join(str(ti.get(k, "")) for k in ("content", "new_string", "command"))
    if not text.strip():
        return 0
    hits = [name for name, rx, validate in RULES
            for m in rx.findall(text) if validate(m)]
    if not hits:
        return 0
    audit = os.path.expanduser("~/.claude/audit"); os.makedirs(audit, exist_ok=True)
    with open(os.path.join(audit, "guardrails.jsonl"), "a") as f:
        f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                            "user": os.environ.get("USER", "unknown"),
                            "event": "pii_blocked", "rules": sorted(set(hits))}) + "\n")
    print("BLOCKED by ABC pii-filter ({}): customer identifiers must not enter prompts or code. "
          "Use @abc/test-fixtures synthetic data or the anonymized Athena marts."
          .format(", ".join(sorted(set(hits)))), file=sys.stderr)
    return 2

if __name__ == "__main__":
    sys.exit(main())
