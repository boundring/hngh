# 2026-09-27 — typesafe fallback crumbs reach the journal

## Finding

`lib/typesafe.py` `_crumb()` subprocessed a `breadcrumb` binary that does
not exist on this system (`command -v breadcrumb` empty). Every
fail-closed path in the typed lane — missing key, SDK import error, API
exception — was therefore invisible: fail-closed returns were correct,
but no diagnostic residue ever landed in `state/crumbs.db`.

This is the observability half of the intermittent research-beat
"parked untyped: typed verdict unavailable" class
(`typed-gap:research-beat` alert; e.g. arc-20260927-dashboard-choice-previews
at 2026-09-27T15:23:45Z, while fb-20260927-1 at ~09:21Z typed
successfully — end-to-end `ask_choices` probe under `systemd-run --user`
returns fine now, so the trigger is intermittent and was undiagnosable).

## Change

- `_crumb()` now calls the single writer seam in-process
  (`lib/crumbs.py` `crumb()`, loaded via importlib), with the strictest
  common detail scrub and `HNGH_CRUMBS_DB` honored for hermetic tests.
- The five API-error `except` sites append `repr(e)` to the crumb detail,
  so the next occurrence records what actually raised.
- `test-typesafe-wrapper.py` gains `FallbackCrumbs` (no-key writes a
  row; forced API error writes a row containing the error text) plus a
  module `setUpModule` tmp-db sink so the suite never writes the live
  `state/crumbs.db`.
- Suite registered in `automation/Makefile` (it existed unregistered).

## Verification

- Red-first: both new tests errored (`no such table: crumbs`) before the
  fix; green after (31/31 in the wrapper suite).
- Live state clean: 0 `typesafe`/`fallback` rows in
  `automation/state/crumbs.db` after the full suite run.
- Gate: `make test` under `automation/`.
