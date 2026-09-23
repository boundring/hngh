# 2026-09-16 — progress-kind path redaction: sink widened to
# alert+progress, research-beat ingest redacted at the source

## The question

The 2026-09-16 boundary-redaction work covered alert-kind text at the
report-queue sink (2026-09-16-emitter-boundary-redaction.md D2) and
deferred the progress kind explicitly: "should progress-kind text
eventually be redacted at the sink". Nobody took the deferral. While it
sat open, the unwired class grew: progress rows in
`docs/project/reports.md` carrying `/home/` prefixes went 292 at
assignment time to 319 by 2026-09-17 02:26Z (live growth recorded by the
census), and the research-beat pipeline was leaking through a path no
sink can ever cover — question text enters `automation/research-lines.tsv`
directly, outside report-queue, and the public row id is derived from
that raw text (live sample id `fail-20260914-Where-exactly-in-home-bricker-Projects-e`).

Both sinks are git-tracked and pushed to the public origin
(git@github.com:boundring/hngh). This record consolidates the three
slices that closed the question: the sink widening (kernel ceremony),
the research-beat ingest fix (automation free-commit), and the census
that sized the class.

## Decisions

### D1: the sink control extends from alert-only to alert+progress

`scripts/report-queue` now routes text through the public-redaction
class for `--add progress` exactly as it already did for `--add alert`:
machine-local prefixes (`/home/<user>/`, `/Users`, `/root`, `/tmp`,
`//host/home`) and credential URL userinfo are rewritten before id,
row, and body derivation. A new `PUBLIC_KINDS = ('alert', 'progress')`
constant gates both the text pass and the body write;
`redact_alert_text()` is renamed `redact_public_text()`; all three
docstring sites state the widened contract. Landed through the kernel
ceremony: candidate commit `79eb4733`
(`hngh: candidate ebd74640ea9895b8f4f4d8539d189f8fa9f62f143ef8987971b7362091f3c8ea`,
content hash `ebd74640ea9895b8f4f4d8539d189f8fa9f62f143ef8987971b7362091f3c8ea`,
pushed 827df7d9..79eb4733), dry-run rehearsed first
(action=prepare-candidate, state=admitted, 10/10 principles). The
automation rider (widened test-suite docstring + the
`test_progress_kind_redacted_too` case) landed as free-commit
`12990854` immediately after.

The per-kind boundary survives, and the original objection is recorded
as void in its old form: the 2026-09-16 D2 exclusion protected
progress lanes that carry repo-relative paths in their progress text.
The redaction class never matched repo-relative paths — it rewrites
machine-local absolute prefixes only, with a mid-token guard
(`https://x.io/home/u/f` stays untouched). So the real boundary was
never "progress text is not rewritten"; it is "progress text is not
globally rewritten". That boundary stands unchanged, and the
machine-local prefix class is closed for progress too. Repo-relative
paths remain allowed and untouched, for alert and progress alike.

One pre-existing kernel test pinned the old carve-out (progress `/tmp`
untouched); it was superseded by this decision and updated in the same
candidate with the expectation flipped, so the kernel suite stays
internally consistent.

### D2: the research-beat line-ingest seam is redacted at the source

`automation/research-lines.tsv` receives question text outside
report-queue: `automation/cadence/hour/33-research-beat.sh` seeds the
TSV from `research-subjects.txt`, derives ids and slugs from raw
question text, and `research_commit` (:169-186, call :761-762)
git-commits the unredacted TSVs with pinned machine identity per review
slice. No sink control can ever cover that path, so the fix lands at
the source (commit `2e51d01b`, author hngh-machine
<automation@hngh.local>):

- `ensure_lines` (:200-224): `desc=$(redact_home "$line")` before id
  and description derivation (:216-217), before the TSV append;
- `demand_synthesize` (:392-396): redaction before append, failing
  closed — a question that redacts to empty is discarded;
- `followon_queue` (:536-538): `redact_home` before slug derivation,
  so the public `fail-<date>-<slug>` id is built from redacted text.

Derivation order is the whole fix: the id-slug leak proves it. The
slug pipeline flattens `/` into the id instead of out of it, so
redacting after derivation would still publish the path in the id
(`fail-20260914-Where-exactly-in-home-bricker-Projects-e`). Redaction
now happens before id derivation, before slug derivation, and before
any TSV write. The redaction is the shared `automation/lib/redact.sh`
family (tilde rendering, fail-closed), so ingest and sink speak one
token dialect.

### D3: forward-only; no history rewrite

The historical progress rows in `docs/project/reports.md` (319 carrying
`/home/` at the 2026-09-17 02:26Z recount) and the 9 live
`research-lines.tsv` rows (plus 5 in the untracked-at-source
`research-subjects.txt`) keep their absolute paths. The ledgers are
append-only by design; rewriting public git history would break every
clone, fork, and content-hash reference to remove content that leaks a
username, not a secret. This matches the landed directive and the D3 of
both 2026-09-16 records.

Residual exposure, stated plainly: 319 progress rows, 9 research-lines
rows, 197 research-dispositions rows, 2 research-lessons rows, and 144
of 262 tracked `docs/research/*.md` crystallization docs still carry
`/home/$USER` machine paths in the public history. The username
leaks; no credential does (the credential-evidence work of the same
day keeps tokens out of ledgers entirely). New rows stop carrying
machine-local prefixes from these slices onward; old rows remain
readable history of the pre-boundary era. If the operator ever wants
the rows cleaned, it is a forward migration (append corrected rows,
prune old), never a history rewrite.

### D4: the --add call-site census (48 sites)

The census classified every `--add` call site under `automation/` +
`scripts/` (tests excluded) by wiring: emitter-wired (the script
redacts before filing), sink-covered-only (alerts the sink now
rewrites regardless of the emitter), and unwired (no redaction either
side). Counts and the notable sites:

| Status | Count | Sites |
|---|---|---|
| Emitter-wired | 3 | oversight-tick.sh:76 (lib/redact.sh), config-backup.sh:34 (fail() alert leg), credential-health.sh:52 (local redact_home) |
| Sink-covered-only (alert) | 17 | 30m/58-patrol:23, day/08-doc-suite-check:29, day/26-publication-review:27, day/27-patrol:25, hour/32-deck-facts:69, agent-watchdog:143, news-screen:100, notify-email:60, model-demote:69, patrol.py:1834, beat-watchdog:152, dashboard-self-review (docstring :22), feedback-apply:248, service-state:173, ui-audit.mjs:26, overnight-cycle:219, dashboard-server.py:1113 |
| Unwired (progress/variable-kind) | 28 | day cadence helpers 01/02/03/04/06/07/08/09/11/13/17/18/19/20/22/23/25, week/01, month/01, hour/33-research-beat:192, agent-supervision.py:355/393, hygiene.py:98, context-ratio.py:142, publication-review.py:209, router-tick.py:105, accept-plans.py:217, scripts/run-autonomous:114, automation/scripts/service-ctl.sh:114 |

After D1 and D2, no emitter is correctness-critical: every alert-kind
site is sink-covered, and every progress-kind site is now sink-covered
too. The three emitter-wired sites predate the sink and remain useful
(they also redact breadcrumbs and identity tokens the sink never
sees). A defense-in-depth sweep to wire the remaining emitters is a
follow-up, no longer a correctness requirement. Other kinds (expense,
optimization, scheduled) still pass unredacted by design; no analysis
exists of whether they carry machine-local paths in practice.

The census also widened the sink inventory beyond the coordinator-known
pair: `automation/dashboard/reports.md` is a tracked symlink (mode
120000, commit 13bd1761) to the kernel ledger, so the 319-row exposure
has a second public path with no separate writer; dispositions (197),
lessons (2), and the 144 crystallization docs are counted in D3.

## What landed

- `scripts/report-queue`: `PUBLIC_KINDS = ('alert', 'progress')`
  (:88-96), widened gate in `add()` (:345-350) and `write_body`
  (:390), `redact_public_text()` rename (:156-163), three docstring
  sites updated honestly (:142-152, :241-247) — candidate `79eb4733`.
- `tests/scripts/test-report-queue.py`: six new tests (:492-551: row
  + body redaction, repo-relative untouched, `/tmpfile` untouched,
  URL guard untouched, id-from-redacted-text collapse, alert contract
  stays green) and one superseded carve-out test renamed with flipped
  expectation (:290-315).
- `automation/tests/test-report-queue-redaction.py`: docstring widened
  (:1-10) + `test_progress_kind_redacted_too` (:77-86) — rider
  `12990854`.
- `automation/cadence/hour/33-research-beat.sh`: redact.sh sourced
  (:56); redaction before id/desc derivation in `ensure_lines`
  (:216-217), before append in `demand_synthesize` with fail-closed
  empty discard (:392-396), before slug derivation in
  `followon_queue` (:536-538) — commit `2e51d01b`.
- `automation/tests/test-research-beat-ingest-redact.sh` (new, 10
  cases), wired into `automation/Makefile:113`.
- This record, the `docs/project/decisions.md` pointer, and the root
  CHANGELOG entry.

## Verification

- Sink red proofs (against pristine HEAD, scripts/report-queue
  unmodified): kernel suite 3 failures of 31
  (`test_progress_paths_redacted_in_row_and_body`,
  `test_progress_id_computed_from_redacted_text`,
  `test_alert_redaction_contract_still_green`); green after the fix:
  31 OK. Evidence regression 3 OK (dedup semantics unchanged); rider
  suite 8 OK; full `automation make test` rc=0 on the combined tree;
  kernel suite re-confirmed OK after the rider.
- Ceremony: `ceremony-drive --dry-run` admitted 10/10 principles
  before the real drive; certificate content hash
  `ebd74640ea9895b8f4f4d8539d189f8fa9f62f143ef8987971b7362091f3c8ea`;
  push leg pushed (827df7d9..79eb4733, rider 79eb4733..12990854).
- Ingest red proofs: the new test ran against the unpatched beat
  script with exactly 5 failures (both text columns, both derived-id
  paths, the `/tmp` case) and 5 passes (relative-path passthrough,
  idempotency); 10/10 green after. Research-beat family regression
  (accel2, blockers, governor, review, commit-per-op) all PASS; full
  automation gate rc=0 (2m37s); `bash -n` clean on the patched script.
- Census receipts re-run twice (2026-09-17T02:26:47Z, 02:27:52Z):
  reports.md progress-with-`/home/` = 319, alert-with-`/home/` = 0 of
  293 alert rows (the alert boundary holds); research-lines.tsv = 9;
  dispositions = 197; lessons = 2; symlink mode verified via
  `git ls-files -s` (120000).

## Not done / follow-ups

- The 319 historical progress rows and the 9 live research-lines rows
  keep their paths (D3); a one-shot forward sanitization commit is a
  future option if the operator wants it, with the caveat that it
  changes dedup baselines (ingest dedup keys on raw text until rows
  age out).
- Emitter-side wiring of the 28 unwired sites is defense in depth, not
  correctness (D4); a sweep node can take it.
- The disposition-evidence column and the crystallization-doc write
  path still file absolute paths; sealing them is unscoped work in the
  same class as D2.
- Other kinds (expense, optimization, scheduled) are unredacted by
  design and unanalyzed; if a lane ever carries a machine-local path
  in one of them, this record's D1 rationale extends to it.
- `25-wiki-health.sh`'s emitter wiring status is unverified (its test
  pins redacted output but the census could not locate its redact
  source line); the sink covers it either way.
