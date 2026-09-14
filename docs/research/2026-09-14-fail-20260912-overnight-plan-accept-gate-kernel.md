# fail-20260912-overnight-plan-accept-gate-kernel

- Subject id: `fail-20260912-overnight-plan-accept-gate-kernel` (plan
  2026-09-12-routed-overnight-plan-accept-gate-kernel).
- Question: acceptance of routed plans was blocked 2026-09-12 with
  `kernel make test FAILED (rc=2) ×2` under identity
  `overnight:plan-accept-gate:kernel` — real kernel defect or transient?
- Disposition: **parked** — duplicate identity + transient gate reds, no
  kernel defect.
- Anchors: `automation/logs/acceptance.log:601-606` (last
  `kernel-gate-red-rc2` batch 2026-09-14T04:30:39Z); prior carrier
  `docs/project/plans/2026-09-08-routed-overnight-plan-accept-gate-kernel.plan.md:1`
  disposed obsolete 2026-09-09 — "the 19:01Z rc=2 is load-transient
  (3 parallel beats) and self-heals each 30m tick"; chassis lesson
  2026-09-14T08:12:00Z: full kernel `make test` reproduced green end-to-end
  (rc=0, lisp suite 2894 checks) with the tailscale mesh up, and the
  step-1 slice of 2026-09-14 landed through the ceremony on that green gate
  (commits 87594976, 0d64c1a) — proving blockers of that shape are
  load/transient skew, not kernel code.
- Doctrine applied: acceptance-gate shape (`overnight:plan-accept-gate`)
  routes on gate rc, not on kernel semantics; the 09-12 alert text
  predates today's verified green run, so the premise resolved at the
  mechanism level without any kernel change in this slice.
- Recommended next line: none for this identity — if a fresh rc=2 appears
  after 2026-09-14T08Z, react to it as a new occurrence with the fresh
  acceptance.log timestamp, not by re-opening this subject.
