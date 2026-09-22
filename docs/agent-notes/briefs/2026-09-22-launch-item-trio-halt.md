# launch-item-trio halt brief — 2026-09-22 (machine:omp)

Plan 2026-09-22-launch-item-trio: 3/3 lanes executed; kernel gate at halt
(this run); automation gate green at fe1c40b4 (ALL PASS + lint clean).
Tree clean at halt; all commits pushed to origin.

## Lane results

### 1. Fleet-plan unblock (review item 3) — DONE
Per-step Verification lines added to
docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md per the
acceptance-parser grammar (automation/scripts/accept-plans.py:39,
first_unverified_step :153-165). Both plans verify: `first_unverified_step
== 0` for the fleet plan and the new plan. Commits e6ca9d40.

### 2. Dispatch ceilings (charter step-4 remainder) — DONE, gate green
automation/ng/cadence.py: `_dispatch_admit` UTC-daily cap (env
HNGH_DISPATCH_DAY_CAP > cadence-params `dispatch-day-max` > fail-closed
default 4), refusal = escalation.filed reason=dispatch-capped with
defer-to-next-beat; legs via HNGH_JEV_LEGS with prepaid-first/blocked-last
ordering (tiering.leg_order), fail-closed on empty urls, legs-exhausted
escalation with deferred preserved. Self-test
automation/ng/test-dispatch-gate.py wired into automation make test.
Commits a98aa105 (slice), fc74aa3b (back-redact of raw home tokens that had
landed raw in research-dispositions.tsv — gate red fix), fe1c40b4 (LAYERS
registration fix), plus emitter-rows commits.

### 3. Evidence passes (T1-trio) — DONE, all beads closed with evidence
- hngh-8ls CLOSED (84087e55 census doc): dead twin, no outside writers,
  LIVE dedupe defect (→ hngh-1ec), reader inventory 1 strict/9 loose, no
  owed rows.
- hngh-6ih CLOSED (53eb0a03 drills + 41fbf048 damage matrix): `#.` poison
  fail-closed LIVE-VERIFIED on HEAD; t-poison write-behind-wall hazard
  LIVE-VERIFIED (→ hngh-3fx); supervision recovery leg end-to-end
  LIVE-VERIFIED; cert binding evidence-keyed; email-digest/sessions-feed
  fabrication (→ hngh-gn9); kernel present-crash defect (→ parked on
  hngh-3do); fixture paren defect noted; never-sort rule recorded.
- hngh-ays audited (227050ac): rotate-queue lane legitimate, F1 fail-open
  queue-row flip filed; dispatch half of spend-verify landed with a98aa105.

## New beads filed during execution
hngh-1ec (catalog path normalization, P2), hngh-3fx (t-poison accumulation,
kernel lane), hngh-3do (expired fixture certificate + present-crash kernel
lane), hngh-gn9 (email-digest fabrication, automation), hngh-bmb (amdgpu BO
exhaustion patrol signature, P2).

## Plasma crash (operator-reported)
Diagnosed read-only (29beb928): amdgpu BO memory exhaustion → Mesa SIGABRT
of Xorg → session loss; plasmalogin greeter no-fallback amplified re-login
pain; recurred from 2026-09-20. hngh unaffected (timers survived, Linger
kept user manager). Operator decisions pending: chrome restart cadence,
sysrq, upstream reports. Bead hngh-bmb covers the patrol signature.

## Halt state
Tree clean; automation gate green; kernel gate green at halt: 2934
checks passed. Remaining machine-lane work parked: the five new beads. Next operator
items: fleet-plan acceptance rides the accepted-plans tick; ZHIPU rotation
already handled by operator (vault-freshness clean).
