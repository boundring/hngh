# Tigress kimi-telemetry-contradiction verdict (2026-09-18)

Task: reconcile the alleged kimi telemetry contradiction against STATE.md-ledger
ground truth (same ground truth as G2). No live kimi probe run (G1 rule).

## Ground-truth counts (verified live this session)

- `automation/STATE.md`: 610 `| model | kimi` rows, 1440 `| model | unsloth` rows.
- Of the 610 kimi rows, all are failure/fall-through markers: HTTP 403 (dead key),
  HTTP 400 (burst throttle), HTTP 000 (connection-level, 12 rows, latest
  2026-09-18T14:52:43Z), plus defer/fail/pace markers. Zero success breadcrumbs.
- Telemetry `~/.hngh/db/telemetry.db`: 199 kind=model source=kimi rows spanning
  2026-09-08T04:01:51Z .. 2026-09-16T07:49:27Z. No rows after 2026-09-16.
- Ledger kimi rows continue 403-only after 2026-09-16 (latest 2026-09-18T22:34:50Z).

## Mechanism (automation/lib/model.sh)

- `_model_emit` (model.sh:714) writes exactly one kind=model telemetry row per
  *successful* call; `_kimi_leg` (model.sh:739-749) calls it only after
  `kimi_chat` returns 0. Failures fall through to the next backend and leave
  only ledger breadcrumbs, never telemetry rows.

## Verdict: NO contradiction

Ledger and telemetry agree the kimi leg is dead: telemetry success rows stop
2026-09-16T07:49:27Z because no kimi call has succeeded since; the ledger keeps
recording per-attempt 403/400/000 fall-through markers. This matches the G2
record (docs/records/2026-09-18-g2-telemetry-ledger-reconciliation.md row 2:
"No correction to `_model_emit kimi`"). No emission-site change warranted.

## Note on cited sources

The plan step cites "three tiger banked specs" for this work log. No file
matching `tiger` exists under docs/ or automation/docs/ (grep, this session);
the only banked spec found is the Scorpion precision note (banked 14:32Z
2026-09-17) pinning G1 = STATE.md breadcrumb ledger as ground truth, which is
what this verdict uses.
