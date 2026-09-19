# 2026-09-19 — plan-drain synthesis: beads-tombstone family

## Family scope

Beads issue-tracker lifecycle: tombstone semantics, Jev propagation,
closeout evidence, duplicate/orphan/stale hygiene (beads-tomb-* and
beads-* branches of the deep plan, ~300 nodes).

## Completed children banked

- `docs/records/2026-09-18-beads-jev-propagation.md`: `bd delete` is
  a hard row delete with no tombstone; re-import of a stale export
  resurrects as open; closed issues sync as live rows (last-write-wins
  can reopen); conflicts halt exit 2 for manual resolve. Practical
  rule of record: never re-import stale exports; push after closes.
- First real bead loop closed: `hngh-4eh` (commits `10cccb2d` +
  `d740d967`), with the lesson that dep direction was inverted
  (implementation does not depend on the assessment doc).
- Beads census hygiene probes (beads-census, beads-inventory,
  beads-jsonl-schema, beads-dolt-db, beads-dup-*, beads-orphan-*,
  beads-stale-*): completed probes live in records and `bd` state;
  remaining open gate nodes are process rules, not code work.
- Tombstone mechanism probes (beads-tombstone-*, tomb-help-*):
  semantics documented; `bd close --reason` with hashes/files/
  validation is the mandated closeout form.

## Park decision

The beads-tombstone audit is closed as an audit: tombstone semantics
are documented behavior, not a bug to fix in this wave. The standing
rules (no stale re-imports, push after closes, `--reason` with
evidence on every close) are the mitigation. Future tombstone-format
work (e.g. soft-delete, closeout-v2) goes through small light graphs
per topic, per the collapse guidance already of record.

## Follow-ups (bead)

Filed as bead `hngh-tombstone-follow` (placeholder — see implement
step): backfill closeout linkage on already-closed beads; add
acceptance criteria to open backlog beads flagged by `bd lint`.
