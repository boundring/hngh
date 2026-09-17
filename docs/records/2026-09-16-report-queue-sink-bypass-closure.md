# 2026-09-16 — report-queue sink bypass closure: identity, evidence, and every body write pass the boundary guard

## The question

Deep-task node `llc-gate-sink-alert-body-bypass`: the kernel sink
`scripts/report-queue` redacted only the TEXT argument of
`--add alert` (`text = redact_boundary(text)` before rid/first/body
derivation, the 2026-09-16 boundary redaction). Gate-verified live
leaks that post-date that landing:

- `docs/project/report-bodies/2026-09-16T20:30:28Z-alert-976f09b8.md`
  (overnight:plan-accept-gate:kernel) carries
  `tests/scripts/test-probe-model-route.py` verbatim inside a pasted
  pytest traceback — the path rode in via `--evidence`, not TEXT.
- `docs/project/report-bodies/2026-09-16T02:15:00Z-alert-3342f352.md`
  and `…-71d03fef.md` carry `stale-store:/tmp/hngh-cer-*.store`
  verbatim in the `identity:` body meta (oversight-tick's own emitter
  redaction landed later per `llc-boundary-redaction`; the sink did
  not guard identity).
- `write_body` persisted `last-evidence:` and `identity:` meta lines
  unredacted; occurrence/suppressed-duplicate body appends were
  unredacted; any direct `write_body` caller (the auto-land-shaped
  path) wrote body text that never passed the guard at all.

## The census (who feeds the sink, and with what)

| emitter | identity | evidence | raw-token risk |
|---|---|---|---|
| `automation/jobs/oversight-tick.sh:68-79` | `redact_home`-ed at the emitter (2026-09-16) | — | identity strings like `stale-store:/tmp/…` (pre-guard rows prove the shape) |
| `automation/jobs/patrol.py report_alert` | lane ids (path-free) | failing log detail lines (free text, journal-derived) | evidence is exactly where the 976f09b8 leak rode in |
| `automation/jobs/credential-health.sh:47-54` | `credential:<name>:<redacted failure>` — can carry `/tmp` tokens | `http=N` or cksum (token-shaped) | identity can be pathy |
| `automation/jobs/beat-watchdog.py`, `agent-supervision.py` | `beat-stall:<scope>` etc. (path-free) | — | low |
| direct `write_body` callers | any | any | the named `git-auto-land.py` path does not exist (2026-09-16 digest-writer census record §git-auto-land); the guard must hold for the shape, not the missing file |

All pinned automation identity/evidence fixtures
(`cap-block-2026-09-09`, `patrol:email`, router-feed idents) are
path-free, so normalizing the dedup key family changes no pinned
behavior.

## The decision: redact BEFORE the window scan, on both sides

- `--identity` and `--evidence` are ledger-bound keys on EVERY kind
  (they are stored in the git-tracked body meta), so unlike TEXT (the
  progress carve-out stays) they are rewritten at the argument
  boundary, before the dedup window lookup. The dedup key is the
  redacted form. Pinned in the module docstring and in
  `tests/scripts/test-report-queue.py` (pathy identity twice ⇒ one
  row, ×2).
- Rows filed before this guard store raw metas. The scan reads them
  back through `normalize_boundary` (clean values byte-identical, raw
  values rewritten), so raw and redacted spellings of one identity
  collide instead of stranding duplicate rows
  (`test_pre_boundary_raw_identity_still_dedups`). No duplicate-row
  explosion against the live ledger's raw rows.
- Mid-token URL guard semantics are inherited, not re-invented: the
  same `[A-Za-z0-9.~/-]` lookbehind class excludes a preceding URL
  `:`/`/` from matching, for identity and evidence too
  (`test_identity_url_home_component_untouched`).
- `write_body` now takes `redact_text=True` by default: first/full are
  rewritten unless the caller opts out — `add()` does so only for
  progress rows (per-kind carve-out preserved). A direct caller with
  no `--add` argv pass (the auto-land shape) is therefore guarded by
  construction (`test_direct_write_body_call_redacts`). Meta lines are
  always rewritten, for every kind and caller.
- Occurrence and suppressed-duplicate appends pass through the guard
  (currently constant strings, so this is a structural pin, not a
  behavior change).

## What landed

- `scripts/report-queue` — `redact_boundary` (the rewrite, renamed
  entry point; `redact_alert_text` kept as an alias), `boundary_dirty`
  / `normalize_boundary` (comparison form for stored metas),
  `write_body(redact_text=True)`, guarded `set_body_evidence`,
  guarded appends, identity/evidence rewriting at the top of `add()`,
  docstring pin of the dedup-order decision.
- `tests/scripts/test-report-queue.py` — six new contract cases:
  identity stored redacted, identity redacted BEFORE the window
  lookup, pre-guard raw identity still dedups, URL component
  untouched in identity, evidence redacted + occurrence appends stay
  clean + suppression contract, direct `write_body` call redacts.

## Tests (red first)

- Red state verified before the sink change: 4 of the new cases
  failed for the leak reasons (raw identity meta verbatim, pathy
  evidence verbatim, no identity dedup on the redacted key, raw vs
  redacted key strand) and the 18 pre-existing cases stayed green.
- Green after: `python3 tests/scripts/test-report-queue.py` 24/24 OK.
- Sibling consumers through the real script:
  `automation/tests/test-report-queue-evidence.py` 3/3 OK
  (suppression/bump contract intact on redacted tokens),
  `test-cap-block-operator-item.py` 2/2 OK, `test-router-feed.py`
  5/5 OK, `test-oversight-tick-alert-redact.sh` ALL PASS,
  `test-config-backup-fail-redact.sh` ALL PASS, `test-patrol.py`
  40/40 OK.

## What this does not cover

- ~~Existing leaked bodies (976f09b8, 3342f352, 71d03fef) are already
  in git history and on the public origin~~ — REFUTED and replaced
  (2026-09-17 publish-claim adjudication). Corrected state: the three
  leaked bodies are untracked working-tree files, never committed to
  any ref and absent from all reflogs (`git rev-list --all --reflog
  --objects` matches zero fragments). At the 2026-09-17T04:37Z audit
  they existed only as unreachable objects — blobs 1d34a452 and
  ea88947d (reports.md snapshots listing the alerts) and d4452432
  (a record draft quoting the leaks), held by the unreachable
  stash/WIP commits dcacfb74 and 59f08875 (both "WIP on main",
  2026-09-16) and 91ab48ca (autostash) — subject to `git gc`/prune.
  At the 2026-09-17T10:13Z re-verification all six objects are pruned
  from the object store (nothing unreachable holds the fragments), so
  git carries no exposure surface at all; the
  live working-tree body files remain, and scrubbing them is a
  separate, operator-visible decision — flagged as a follow-up.
- Historical published alert bodies did not leak this record's actual
  leak class: the 20 tracked-era alert bodies at
  6529562b32b1e4d64db3038c03a8443c00978ca5 (pre-2026-08-27 untrack
  state) contain zero raw `/tmp/hngh-*.store` paths (`git grep -IlE
  '/tmp/hngh-[a-z0-9]+\.store' 6529562b` over report-bodies is
  empty; each file carries 2 `stale-store:` mentions with no raw
  path). Closes the follow-up question of whether already-published
  history exposed raw store paths — it did not.
- Identity/evidence on progress and other non-alert kinds are now
  rewritten (this slice's deliberate widening); per-kind TEXT
  carve-out for progress is unchanged.
- Other machine path families (the `/Users`-style, the `/root`-style,
  and `//host`-style prefixes) remain outside the token family
  everywhere (same divergence tracked by
  `llc-gate-scrub-site-divergence`).
- `annotate_report` (imap-poll's operator-reply body appender) writes
  through its own `open(path, "a")`, not the sink's writer; its
  input is operator email replies. Flagged as a residual writer the
  critique gate may want to schedule.
