# Line-tooling damage matrix c1-c6 — hngh-6ih subfamily (a) (2026-09-22)

Read-only pass per `~/.jcode/scratch/nl-tooling/SETUP.md` (snapshotted as
docs/agent-notes/briefs/2026-09-20-nl-tooling-line-damage-spec.md); kernel
probes ran via the real `scripts/hngh` (HEAD 142a1899) with `--store=` under
the scratch lab; repo untouched. Full corpus: this doc (the scout's write
surface was xd-only; c1's live evidence also at
`~/.jcode/scratch/nl-tooling/evidence/c1-state-claim.md`).

## Per-child verdicts

- **c1 state-claim — CLAIM VERIFIED** (sibling, live on 20 records + 3
  adversarial probes): `record-line-for` (src/main.lisp:409-418) emits keys
  in fixed order → top-level `:STATE` always on the record's first physical
  line; inner `:RUN :STATE` structurally ignored by `rebuild-run`
  (src/main.lisp:384-407).
- **c2 agent-supervision (bridge_sessions, automation/jobs/agent-supervision.py:153-198)
  — SILENT LOSS**: same-line IDENTIFIER+STATE rule makes record line 2 safe
  (inner states invisible), but the objective regex `:OBJECTIVE "([^"]*)"`
  needs the closing quote on the SAME line — multiline records lose the
  objective ENTIRELY (empty at :197), not just truncated. Receipt ts missed →
  mtime fallback (:192). `replace_stalled_bridge_run` (:262-306) re-provisions
  new runs with the lost objective.
- **c3 sessions-feed/email-digest — FABRICATION**: bridge_rows
  (automation/jobs/sessions-feed.py:440-483) is last-match-wins → inner-state
  override: adversarial A (top CREATED/inner EVACUATED) renders `evacuated`,
  B (top DEAD/inner CREATED) renders `working` → dead run shown LIVE in the
  observatory. email-digest `open_runs` (automation/scripts/email-digest.py:
  466-494, worst consumer): last-`:STATE`-per-file with no identifier anchor →
  A silently VANISHES from "runs still open", B FABRICATED as open; the
  production shape lands correct only BY LUCK (CLOSE's inner `:DEAD` is the
  last match). Objective truncated at line boundary + 70 chars (:482).
- **c4 time-ledger (automation/jobs/time-ledger.sh:128-181) — most robust,
  silent imprecision**: whole-text objective regex captures the FULL
  multiline mission; close-ts same-line-only and production CLOSE receipts
  carry NO timestamp fact → mtime fallback (:169-175); closed<made guard
  blocks negative walls. No fabrication/loss.
- **c5 dashboard — INSULATED, cosmetic**: file-count metrics line-insensitive
  (common.sh:111-113, hngh-record.sh:67-73); sessions-view.js :461-468 renders
  a mid-record tail fragment verbatim (cosmetic).
- **c6 mutation hazards**: NEVER `sort` record.lisp — separates spill lines
  from their records (reader chaos/TRANSPORT-FAULT) or, on single-line
  stores, reorder + newest-wins resurrects dead runs (kernel-level
  fabrication); `dos2unix` harmless repair (kernel reader treats CR as
  whitespace); `uniq` no-op; `wc -l` overcounts records. The LF write-hole is
  CLOSED at creation: `no-newlines-p` (src/adapter/filesystem.lisp:60-66)
  refuses LF/CR, and hngh-record.sh:26 passes raw missions → multiline
  missions refused rc=1. Exposure is legacy stores + hand edits only.

## Kernel live-probe matrix

- stores/overnight (production 3×2-line shape, embedded 0x0A): `status` ✓;
  `present run-1` ✓ renders the FULL multiline mission untruncated
  (raw LF + UTF-8 intact), state=dead from the CLOSE record — the kernel
  reader is multiline-tolerant.
- baseline/utf8/cr fixtures: `status` ✓ but `present` CRASHES — unhandled
  SIMPLE-ERROR "verification must be a nonempty string"
  (ENSURE-NONEMPTY-STRING ← MAKE-MISSION :VERIFICATION NIL ← REBUILD-RUN ←
  dispatch-present), raw backtrace, exit 1. **Kernel defect**: dispatch-present
  (src/main.lisp:791-808) has no handler around rebuild-run → any record whose
  :MISSION lacks :VERIFICATION crashes instead of a clean refusal. Filed as
  bead hngh-3do (same kernel lane).
- multiline-store + adversarial-inner-state fixtures: status AND present →
  TRANSPORT-FAULT — root cause (hand-counted bytes): every record ends
  `...Z"))` WITHOUT the outer record paren (`Z")))`). **Fixture defect** (the
  two fixtures designed to probe multiline/inner-state are kernel-illegible);
  adversarial inner-state kernel verdict therefore NOT-LIVE-VERIFIED
  (statically: kernel takes top-level :STATE, ignores inner).

## Defect list (filed / parked per plan halt rule)

1. Kernel: `dispatch-present` missing handler around rebuild-run
   (`src/main.lisp:791-808`) → crash instead of refusal. Kernel lane.
2. Kernel (already hngh-3do): expired fixture certificate. Kernel lane.
3. Automation: email-digest `open_runs` last-`:STATE`-per-file rule —
   fabrication/omission on the shapes the kernel tolerates. Fix = anchor
   `:STATE` to the record's `:IDENTIFIER` line (or parse s-expressions).
   Automation surface.
4. Scratch fixtures multiline-store / adversarial-inner-state missing final
   close-paren — regenerate (kernel-illegible as-is).
5. Production CLOSE receipts carry no `timestamp:` fact → all close-time
   consumers fall back to mtime (kernel emit-side; certificate lane).

## Mechanism (the one-line architecture fact)

The store is a stream of s-expressions (`read-line-form`
src/adapter/filesystem.lisp:81-90); physical lines are irrelevant to the
kernel. Every line-based consumer guesses at a format the kernel does not
guarantee — the writer's fixed key order (record-line-for) is the only reason
top-level keys are line-visible, and free-text length is what spills records
across lines. Inner `:RUN :STATE` on the spill line is the fabrication vector
for last-match-wins parsers.
