# recovery-drill 6-node evidence pass — hngh-6ih subfamily (b) (2026-09-22)

All runs under `~/.jcode/scratch/recovery-drill/` against the real kernel
`scripts/hngh` (HEAD 142a1899). Real repo verified byte-unchanged; all git
mutations landed in scratch repo copies. Per-node evidence:
`~/.jcode/scratch/recovery-drill/evidence/{1..6}-*.md`.

## Node 1 read-eval-forging-probe — LIVE-VERIFIED fail-closed

30 verbs x 2 runs = 60 probe rows on `#.`-poisoned stores (side-effect,
value, forged-record variants; positions p2/p3): every store-reading verb
(present/admit-transport/close-run/mutation-check) exits 3 TRANSPORT-FAULT;
`status` degrades to all-unavailable rather than fabricating state. The
`#.(with-open-file ...)` side-effect body NEVER ran (no eval-marker file);
ledger bytes identical before/after (md5 diff empty). Control: clean store
reads normally. Mechanism: `read-line-form` binds `*read-eval*` NIL
(2b113e5b), `read-lines` handler-case → transport-fault (142a1899), dispatch
exit 3 (src/main.lisp:2531-2532). The gate fix holds.

## Node 2 t-poison-append-accumulation — LIVE-VERIFIED hazard on HEAD

The `()` truncator poison: `read-lines` `while form` ends silently on NIL
(src/adapter/filesystem.lisp:92-101); accepted writes append BEHIND the wall;
dedupe basis is the truncated replay (:118-131).

- t-p1 (`()` first): whole store invisible; `create-run` ACCEPTED → invisible
  whole-run accumulation; ledger grows, `present` shows nothing.
- t-p2 (`()` between): admit-transport rc=0 on EVERY repeat — 8 accepted
  re-admissions → 8 byte-identical invisible duplicate rows (3→8→11 lines,
  9 admission rows total). Unbounded, no steady state.
- t-p3 (`()` last): duplicate refusals steady, BUT `close-run cancelled`
  ACCEPTED → close receipt appended behind the wall; `present run-1` still
  replays `state=created` — poisoning-induced data loss (written but never
  replayed).

NEW class-t finding: close-run is a repeating no-op on t-poisoned stores —
rc 0 every invocation, no conflict (duplicate check replays the truncated
view). Consumer consequence: `replace_stalled_bridge_run`
(automation/jobs/agent-supervision.py:262-306) treats close-run rc=0 as
terminal and rotates the ledger — on t-poison the guard rotates on a no-op
success while poisoned bytes stay.

## Node 3 poison-matrix-doc-corrections — documentary delta list

Scratch doc `~/.jcode/scratch/hngh-matrix/POISON-MATRIX.md` (175 lines) left
byte-identical (read-only node). Corrections demanded (from live-verified
siblings + nodes 1-2): (1) :68 "p2 appends visible" → appends behind `()` are
reader-invisible (t-p2 == t-p3); (2) :140-147 corruption narrowed to t-p3 →
both t-p2 and t-p3 lose written-but-unreplayed data; (3) add close-run
repeating-no-op + supervision-rotation consequence; (4) `#.` open question →
CLOSED (real pre-fix, fail-closed on HEAD via 2b113e5b + 142a1899); (5) t
accepted-write accumulation → CONFIRMED unbounded; (6) verb census: no
trim/quarantine/archive/repair verb exists (src/main.lisp:2444-2483); recovery
= manual surgery. No repo doc mentions the poison matrix (grep zero hits) —
kernel fixes ARE reflected in CHANGELOG/docs/records; matrix doc is scratch-only.

## Node 4 supervision-recovery-leg-endtoend — LIVE-VERIFIED (2 documented stubs)

Three real ticks of automation/jobs/agent-supervision.py with env seams
(OMP_BRIDGE_STORE, SUPERVISION_STATE, SUPERVISION_REPORT_QUEUE, HNGH_BIN,
OMP_BRIDGE_BIN; seeds from ~/.jcode/scratch/nl-tooling/SETUP.md): tick1
verifying → tick2 stalled → real-kernel close-run-to-dead (rc 0, legal
created→dead chain in rotated ledger) → os.replace rotation → re-provision →
tick3 verifying + one identity-deduped recovery row. Stubs:
SUPERVISION_REPORT_QUEUE (argv-logging stub; real one writes live ledger) and
OMP_BRIDGE_BIN (wrapper performs equivalent real-kernel create-run; real
omp-bridge --run-start spawns a live session = operator-surface side effect).
Mutation leg fully real. Guard selfcheck 7/7 fixtures green.

## Node 5 realistic-ledger-shapes — LIVE-VERIFIED; hazard WORSENS

Shapes: 4-line full-lifecycle, 6-line two-run interleave, UTF-8 multibyte,
inner-state-mismatch, CRLF — plus t-poison and `#.` variants of each.

- `#.` fail-closed holds on every shape (exit 3, no eval marker) incl. CRLF
  and multibyte.
- t hazard worsens on >3-line stores: s4line-t2 → kernel re-armed the run
  from its truncated created view and re-wrote arm+close rows (state
  regression: real ledger has armed+cancelled, poisoned view spawns a SECOND
  armed+cancelled chain); interleave-t3 → re-admission of a wall-hidden
  admission, duplicate state rows accumulate. arm-run refused (callback
  contract) where receipts invisible — gate still bites there.
- Dedupe holds across CRLF (duplicate-admission on re-admit); present renders
  multibyte intact.

## Node 6 manual-archive-open-items — LIVE-VERIFIED (kernel path) + NEW kernel finding

- Cert binding is EVIDENCE-keyed, not path-keyed: after archiving the store
  (whole-dir cp -a), real `mutation-check` from an archived store re-mints
  the certificate from fresh candidate evidence and EXECUTES rc 0; advancing
  the repo copy's HEAD then refuses `mismatched-certificate:
  base-revision-mismatch` — an archived store can neither rescue nor break a
  cert. `repository-identity` embeds store basename only in the fixture path
  where identity is re-derived each invocation (fixture-mutation-check
  src/main.lisp:1506-1512); real path identity comes from repo git evidence
  (src/adapter/run-gather.lisp:77-94). Drill D's unverified A1 claim resolved:
  no functional dangle, traceability-only.
- No `archive` verb on HEAD (exit 2 unknown command); manual whole-dir move is
  the archive path (byte-identity re-verified).
- NEW KERNEL FINDING (filed as bead): the verdict-less fixture
  `mutation-check` is DEAD ON DATE — `dogfood-certificate` hardcodes expiry
  `2026-08-25T00:00:00Z` (src/main.lisp:1250) and
  `certificate-refusal-labels` compares against the real clock → every
  no-verdict fixture mutation-check now refuses `expired-certificate` (rc 1)
  before any evidence runs. Verified live.
- issue-cert does not mutate the ledger (certificate is a rendered artifact;
  md5 identical before/after).

## Disposition

- Subfamily (b) recovery-drill: 6/6 nodes live-verified (node 3 documentary
  by design). Kernel defects discovered → filed as beads, parked per plan
  halt rule (no src/tests mutation outside ceremony): t-poison write-behind-
  wall class; expired fixture certificate.
- Subfamily (a) line-tooling damage matrix (c1-c6): separate read-only pass,
  spec ~/.jcode/scratch/nl-tooling/SETUP.md (snapshotted to
  docs/agent-notes/briefs/2026-09-20-nl-tooling-line-damage-spec.md).
