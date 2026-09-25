# Refoundation P9 — canon method at every decision seam

Date: 2026-09-25. Plan: hngh refoundation pass, phase P9.
Principle: decisions cite their principle (GOVERNANCE.md §6 binds decision
recording; plans/README contract).
Adversarial: a mandatory field can become ritual text — mitigated by the
one-line adversarial note, which must disconfirm, not agree.

## What changed

- `docs/project/decisions.md` — new `## Entry template` section (the file
  had none): entry shape with two mandatory fields,
  `principle: <one closed principle + doc anchor>` and
  `adversarial: <one-line disconfirming note>`, bound to GOVERNANCE.md §6.
  Quarterly-adjudicated tensions are recorded in the ceremony decay-review
  record with their clause + decision (GOVERNANCE §12). No existing
  entries rewritten.
- `automation/scripts/accept-plans.py` — principle gate: a plan is
  acceptable only when its preamble (text before the first `## ` heading)
  carries a `principle:` line. Missing → `blocked <slug> missing-principle`
  + one alert row (`overnight:plan-accept-blocked:<slug>`, never silent per
  the 2026-08-31 blocked-cycle contract); the plan never flips status,
  never mints a research subject, gates never run. `PRINCIPLE` regex +
  `has_principle()` helper.
- `docs/project/plans/README.md` — contract bullet: every plan carries a
  `principle:` line before its first `## ` heading citing one closed
  principle + doc anchor; acceptance blocks without it.
- Sweep: 2 proposed plans currently lack a principle line
  (2026-09-22-dev-synth-2026-09-20-1,
  2026-09-25-dev-fail-20260922-Does-the-research-lines-ts); they stay
  proposeable and will block at acceptance until the operator or a minting
  agent adds the line.

## Verification

- `automation/tests/test-accept-plans-principle.sh` (NEW, 10 checks,
  hermetic mktemp sandboxes incl. `HNGH_REPORT_IDENTITIES` isolation):
  fixture A (principle line + green stub gates) → accepted + front-matter
  flip; fixture B (identical minus principle) → blocked missing-principle,
  front-matter unchanged, not parked, gates never ran, alert row filed.
- Legacy suites updated: `tests/test-plan-acceptance.py` fixture builder
  and `tests/test-rehearse-gate.py` plan fixture carry principle lines.
- Full `make test` green.
