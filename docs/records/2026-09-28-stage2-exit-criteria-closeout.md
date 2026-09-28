# 2026-09-28 — stage-2 exit-criteria close-out ('One interface' landing → done)

Route row: docs/project/roadmap.md:29 (stage 2, 'One interface'). Exit
criteria and their evidence, one row per criterion:

1. **Every tab renders at desktop + mobile widths** — VERIFIED:
   docs/research/2026-09-03-stage23-exit-criteria-sweep.md:37 (headless
   pass, all five tabs cold-mounted at 1440×900 and 390×844,
   aria-selected + visible content, 10/10 checks).
2. **Cold deep-links mount** — VERIFIED: sweep :38 (`#tab-<name>` hash
   router via app.js; cold fetches return 200).
3. **Operator items flow open→handled→dismissed** — VERIFIED: sweep :39
   flagged the handled leg not-established at the time; landed since and
   recorded — docs/records/2026-09-27-dashboard-operator-actions.md (six
   verbs `/operator-item/{handle,dismiss,park,expire,suppress,
   acknowledge}`, red-first, lifecycle suite green) and
   docs/records/2026-09-27-dashboard-metacycle.md (INT-23 feedback-flood
   MET: 40 real items, all handled, dismissal observed live by the
   standing probe). Extended 2026-09-28: `POST /desk/approve` one-click
   authorization (commit f6dc44b2) rides the same approved ledger.

Honest scope note: the installation desk sub-surface continues mid-flight
under the operator-approved Omarchy-on-CachyOS arc (phases 1–2 landed
2026-09-28; phase-2 config adoption in flight); window-tiling refinements
stay QoL-cadence work. Neither is exit-bearing for the route row above.

Unblock provenance: the 2026-09-22 launch-item-trio step-1 blocker
(per-step Verification lines on the governed-fleet plan) was cured at
accept 2026-09-22T13:03:06Z; no `overnight:plan-accept-blocked` re-fire
since (report-queue head checked 2026-09-28).

Verification: kernel `make test` green on the working tree at flip time
(2954 checks, run this session, post-Wave-1 automation slices);
roadmap pipe-field intact after the edit.
