# Records

Records preserve verified facts, decisions, and bounded unknowns. They do not
authorize a future action.

- `2026-08-11-crystallized-cutover.md` identifies the external retirement
  archive and its active-state boundary.
- `2026-08-11-task-1-boundaries.md` records the dependency and presentation
  boundary publication.
- `2026-08-11-task-2-run-domain.md` records the pure domain lifecycle and
  evidence boundary.
- `2026-08-12-task-3.1-create-run.md` records the first application use case,
  its callback boundary, and atomic recording contract.
- `2026-08-12-task-3.2-arm-run.md` records closed admission evidence and the
  created-to-armed application transition.
- `2026-08-12-task-3.3-start-run.md` records the armed-to-running application
  transition and its one-slot recording boundary.
- Future records name their scope, evidence command, observed result, and
  remaining unknowns.

The archive verifier is `make check-archive`. It is read-only and uses a
temporary directory for regenerated inventories.
