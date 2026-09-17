# Adversarial pass — 2026-09-15 (zoom-adversarial)

Counts: grep -c FAIL on PATROL-2026-09-15.md = 131 FAIL lines across ~34 runs in one day. `git log --since='2026-09-14 20:00'` = 106 commits. High commit velocity on a red foundation.

## Strongest case: the automation gate is red all day and the system keeps landing anyway

1. **automation-gate `make test rc=2` FAILs in every patrol run from 00:21Z through 16:49Z** (PATROL-2026-09-15.md lines 27, 68, 108, 149, 189, 229, 269, 309, 349, 389, 432, 478, 519, 562, 603, 646, 687, 730, 803, 846, 887, 930, 971, 1014, 1055, 1095, 1135, 1175, 1214, 1254, 1295, 1334, 1374, 1415). That is ~16.5 hours of a failing test gate. Meanwhile the *supportive* pass reports `[ok] gate-cure -- gate green` in the same runs (e.g. lines 53 vs 68): two surfaces directly contradict each other and the green one is the one routed onward. Alert 6eed3955 (17:01:11Z, reports.md) confirms plan acceptance is blocked by the same rc=2, yet 106 commits landed since last night — the certificate loop's "verified commit" claim is currently unverifiable for automation slices.
2. **Suppression has become the fix.** reports.md today shows the router auto-routing alerts to "plan candidates" and then dedup-suppressing repeats: de42b67b (automation-gate ×3), 287b0a3b (repeat-crumbs), 7835f3ae (research-beat injection), bcc99e88 (deck-unreachable), a8eda118/6cc700da (ui-audit), 1703b7d4 (manga), ee6830f7 (feedback). The routed candidates for automation-gate (2026-09-15-routed-patrol-automation-gate) stayed "live" for hours while the underlying rc=2 never got fixed — routed ≠ resolved, and dedup makes the repeat invisible.
3. **Operator bulk-dismissal loop.** 2026-09-14T22:43:22Z shows 11 operator-dismiss "item dismissed as viewed" rows in one second (agent-handoffs tail), several of them (b61fed0f, 3146c023) the *same correction ids re-routed as plan candidates the next morning* (reports.md 0880f233, 0859f2f1). Same issues dismissed at night, re-alerting next day: the operator-correction loop recurs instead of converging.
4. **Handoffs/overnight lanes are dead weight.** handoffs bad-execution worsened 7→8 dead/cancelled in last 10 rows and persisted in all ~30 adversarial passes (PATROL line 26 through 1414). agent-handoffs.md shows overnight-lead runs (glm-5.3-flash) cancelled with `cause=unknown` repeatedly (2026-09-14T21:05Z, 22:12Z, 2026-09-15T08:55Z, 09:05Z) and `cause=bad-execution` (06:07Z). The overnight lane has produced no completed run in the visible window; it burns budget and generates the very handoff FAIL it then reports.
5. **GitHub CI red on essentially every push**: ~15 distinct failing run SHAs (5aa1f24, 75006ca, 3a1a612, 14949a7, 25edfd6, 206f977, a242ae8, 954bf29, 51c2d90, 385b61c, 522965f, e9af568, e682ade, 43eb88e, 72e0d7a, 8d80b56, 6f0e7ef, 7cbd3ca, 2c9fb68, bd01fa3, 80f7a3f, b173edc, f726b15, 53674dc, b016c89, 3910961, b485cab, 6ecc1d0 — PATROL adversarial github-ci lines). CI failing per-push is consistent with the local gate also red: nothing verifies before landing.
6. **Queue rot.** queue.md: node-lattice-admission queued since ~2026-08-27, explicitly marked "rotate next (unblocked)" after wake-mutation-lane landed 2026-09-13 (docs/project/queue.md Next section), yet still queued two days later. bridge-operator-host queued since 2026-08-27 with only an hourly "card mounted" heartbeat since (reports.md hourly rows) — mounted-but-never-incremented for ~19 days mirrors the 2026-08-27 "card mounted, never incremented" incident it was supposed to fix.
7. **Stage-2/3 "landing" duration.** roadmap.md shows stages 2 and 3 both "landing"; stage-2 tab/tiling work was already the frontier on 2026-08-26 (reports.md 7de78ed9 "frontier=(Next slice) The worker-driver surface"), so stage 2 has been "landing" ~3 weeks with no exit-criteria movement cited. Stage 3's ten invariants (governed-fleet.md §4) include "one governed package upgrade through the ceremony" and "config lanes on cadence" — no evidence in today's reports of either running; the only patrol service check (comfyui) FAILED service-down at 09:07Z (PATROL 768).
8. **Research alternation churn.** research-dispositions.tsv is dominated by "reviewed" rows with very recent timestamps but few transitions to adoption; ~20 "planned" rows dated 2026-09-14/15 churn without crystallizing (automation/research-lines.tsv status column). The roadmap itself admits the Descent adoption gate and Audit station are "specified there and not yet wired" (docs/project/roadmap.md Now section) — stage 5's single exit criterion (a research beat landing a parseable artifact through the standard gates) cannot be met while make test is red.
9. **Declared-vs-fixed drift.** Route's honesty claim: "a stage is done when its exit criteria hold under the standing gates" (roadmap.md). Today the standing gate is red yet stage status is unchanged and 106 commits landed. That is exactly the papering-over pattern: status text (landing/green) decoupled from gate reality.

## Real risk vs cosmetic

- **Real**: (1) automation-gate rc=2 + contradictory gate-cure green — the trust root of the whole evidence-before-claims doctrine; (2) suppression-as-fix via router dedup with stale "live" candidates; (3) overnight-lead lane burning cycles on glm-5.3-flash with cause=unknown (possibly model/route misconfig, not workload).
- **Cosmetic/low**: journal-error noise (Bluetooth hci0, org.freedesktop.Notifications unit-failed ~20×, kwin XCB, amdgpu MES) — desktop noise, correctly unclaimed, but 131 FAIL lines/day inflate signal cost; manga-stale 48→51h is a slow userpace output, not kernel risk; ui-audit color-contrast is cosmetic.

## Recommended first moves

Fix make test rc=2 in hngh-automation before any further automation commit; make gate-cure read the same source as the adversarial gate check; expire auto-routed plan candidates after N hours instead of suppressing repeats forever; stop scheduling overnight-lead until the glm-5.3-flash cause=unknown cancellations are root-caused.

## Corrections as of 17:20Z (coordinator verification)

- "hngh-automation make test rc=2 in every patrol run": the 17:01Z
  plan-acceptance block and the patrol rows reflect STALE GATE CRUMBS,
  not a failing gate. Direct verification: automation gate rc=0 at
  17:08Z and again with the full suite (ALL PASS) on the committed
  slice; mechanism is patrol.py:267-287 newest-crumbs-wins with no TTL
  or actor check. The finding stands as a gate-state-hygiene defect
  (derived state trusted as fact), downgraded from "active red gate"
  to "stale evidence surfaced as alert".
- "GitHub CI red on ~every push (~28 SHAs)": historical, pre-cure.
  CI run on 59c63bf0 (post patch-id cure) = success at 16:50Z. The
  failing-SHA list is the drift window, closed by ceremony 2f9e618f.
- "overnight-lead no completed run visible": not re-verified this
  pass; remains a watch item only.
- Queue rot and stage-duration findings: re-confirmed unchanged
  (node-lattice-admission unblocked since 09-13; bridge-operator-host
  since 08-27; stage-2 frontier text unchanged since 08-26).
