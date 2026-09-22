<!-- plan: status=accepted risk=normal accepted=2026-09-22T18:04:15Z -->
# 2026-09-22 — router alert class channel (Full revised A)

Stop the incident class where a parked critical-class operator alert
(docs/project/report-bodies/2026-09-22T14:57:08Z-alert-afd8588b.md,
mem-caps) was router-routed into a normal-risk candidate and auto-accepted.
Three gates were involved (feed exclusion identity-only scan, router shape
fallthrough, normal-risk auto-acceptance). This plan lands the approved
scope "Full revised A": a durable alert class channel + feed-side
enforcement. Ideas archive with review verdicts:
.agent-scratch/consider/router-class-downgrade-ideas.md (approaches B/C/D
rejected: router never reads body files; per-emitter keyword blocks are
whack-a-mole; kernel acceptance-gate churn out of scope).

## Steps

- [ ] Class channel in scripts/report-queue: `--class critical|normal`
      argv flag (argparse dest=cls, bad value exit 2); add()/write_body()
      gain cls; critical rows carry a `- **class:** critical` body meta
      line (normal/legacy rows carry none); row_class() helper mirroring
      row_identity(); upgrade rule — a `--class critical` re-fire hitting
      a live non-critical row never silently bumps: it files a distinct
      escalation alert (identity `class-upgrade:<orig>`, class critical,
      window 604800) and returns 0.
      Verification: python3 tests/scripts/test-report-queue.py — new
      cases: class meta written for --class critical; no line for
      normal/legacy; upgrade re-fire files class-upgrade row and leaves
      the original row unbumped.
- [ ] Feed enforcement in automation/cadence/hour/10-router-feed.sh:
      parse `- **class:** critical` from the body blob and skip those
      rows; extend the exclusion scan to the alert FIRST line (the exact
      text the router receives) in addition to identity; add
      `class-upgrade:` to the reserved identity prefixes.
      Verification: python3 automation/tests/test-router-feed.py — new
      cases: class=critical row never routed; first-line critical word
      excluded; class-upgrade identity excluded.
- [ ] Filer plumbing: automation/lib/notify-email.sh alert_row gains an
      optional class arg (passes `--class critical` only when critical);
      automation/lib/operator-item.sh operator_item gains an optional 3rd
      arg passed through to alert_row. Existing 2-arg callers unchanged.
      Verification: python3 automation/tests/test-cap-block-operator-item.py
      plus a new critical-filing case proving `--class critical` reaches
      the report-queue argv.
- [ ] Disposition + records: park the accepted routed candidate
      docs/project/plans/2026-09-22-routed-mem-caps-dropin-hngh-dashboard.plan.md
      via plan-dispose.py --action park (superseded by the applied
      drop-in, record 2026-09-22-ram-guardrails-landing.md);
      docs/records/<date>-router-alert-class-channel.md; CHANGELOG entry;
      automation gate + kernel gate green.
      Verification: candidate front-matter status=parked after
      plan-dispose run; make -C automation test ALL PASS; kernel make
      test green.

Non-goals (reviewed, rejected for now): router front-matter risk
derivation (deriving risk=critical for the research-shape fallthrough
would park the entire research lane at acceptance; feed enforcement plus
the CRITICAL_KEYS belt cover the slip-through case), router-side class
plumbing (router never reads bodies — the feed owns parsing), kernel
acceptance-gate changes (normal-risk auto-accept stands; critical rows
never reach the router after this plan).
