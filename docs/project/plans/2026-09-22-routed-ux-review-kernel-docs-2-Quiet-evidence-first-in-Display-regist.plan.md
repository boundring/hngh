<!-- plan: status=proposed risk=normal accepted=- routed-from=ux-review:kernel-docs:2-Quiet-evidence-first-in-Display-regist -->
# 2026-09-22 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:kernel-docs:2-Quiet-evidence-first-in-Display-regist`
at 2026-09-22T10:00:22Z. Alert text: 2. "Quiet, evidence-first" in Display register definition is a meta-description of the register itself rather than a literal fact or caption, violating display-register's "literal fact renders first" rule -> replace with specific observable state (e.g., "renders raw data before labels"). fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
