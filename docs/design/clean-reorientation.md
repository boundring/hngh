# Clean reorientation — the automation tier

Status: PLAN — 2026-09-07. Track B is pending the operator's P0 merge
decision ([repo-merge-consideration.md](repo-merge-consideration.md));
Track A starts immediately. Every finding re-verified live on
2026-09-07; one count corrected (finding 4: five stubs, not four).

Cross-links: [repo-merge-consideration.md](repo-merge-consideration.md), [descent.md](descent.md), [context-manager.md](context-manager.md), [keyring.md](keyring.md).

## 1. Principles applied

- **Kernel purity** (AGENTS.md "side-effect-free local kernel",
  [intent.md](../intent.md)): the kernel contains nothing that runs;
  the automation tier is its complement — code that runs, no machine
  data in git, one seam (`HNGH_HOME`). Track A is purity at the file
  level: dead scripts and shadowing config are what the boundary law
  reads through.
- **Derived data is not in git** (Mirror/pack precedents): machine
  data (STATE.md, dashboard/, telemetry.db, digests) leaves git under
  the quarantine path; only curated syncs land in the kernel docs —
  which the hourly kernel-ledger sync already does (P1).
- **Single compression authority** ([context-manager.md](context-manager.md)
  §2): one context-pack builder, one launcher path — the same law at
  code level: one POST-parse helper, one test stub, one param reader
  (`get_param`). Duplication is a second authority waiting to drift.
- **The artifact-consumer invariant** ([descent.md](descent.md)):
  write-only artifacts are deleted or wired. `DIGEST_HOURS` (the
  systemd timer is the schedule authority) and the `notify-immediate`
  tsv row (documents an env-only knob) are tombstones — they die.
- **The trust-boundary pattern** ([keyring.md](keyring.md) §1, §4):
  fail-closed seams, mode-600 checks, operator-only grants — Track A
  never weakens a fail-closed path; §4 exists for this.

## 2. The reorientation in two tracks

### Track A — CLEANUP (decision-independent, immediate)

All paths relative to `automation/`.

1. **Dead utility scripts, 388 lines.** `scripts/hngh-ufw-manage.sh`,
   `bench-rolling.py`, `deck-setup.sh`, `unsloth-url.sh`. Verified:
   callers only in machine data (sessions.json, digest/, prompts/,
   logs/, STATE.md) and historical docs; deck-setup ↔ unsloth-url
   call only each other; zero live references elsewhere. `git rm` all four.
2. **Config stopgaps retire in favor of the tsv.** `config.env:87-88`
   (`KIMI_URL`, `KIMI_MODEL=k3-256k`) and `:93-94` (`LOBEHUB_URL`,
   `LOBEHUB_AGENT_ID`) duplicate cadence-params.tsv rows 24/25/15/16
   byte-for-byte; line 88 even stomps a real env override, violating
   config.env's own `${VAR:-default}` contract. Delete the four
   defaults; update the row-25 note. But `DECK_URL` (`config.env:39`)
   is NOT stale — it activates the deck leg; move its value into the
   `deck-model-endpoint` row (same behavior, one truth).
3. **`lib/model.sh` POST-parse consolidation.** Verified: seven curl
   sites (83/103 unsloth, 182/215 remote, 252 deck, 344 kimi, 404
   lobehub); the chat legs each repeat POST + `%{http_code}` capture +
   jq parse + tmp cleanup. One `_post_chat` helper, ~-40 lines; the
   test-model-*.sh leg tests are the parity check.
4. **`tests/stub-lib.sh` extraction.** Verified live: five duplicated
   `stub_start()` definitions (deck-leg 29, kimi-leg 38, lobehub-leg
   25, pin-routing 37, research-accel2 39 — 168 lines). One lib,
   name-based signature; the deck-leg sleep variant folds in.
5. **Triple comment.** `lib/model.sh:315-317` — `# gateway 400s on
   temperature; leave it out)` three times in `_kimi_body`. Keep one.
6. **`cadence/day/16-remote-push.sh:26` inline awk** over the tsv for
   `push-cadence-hours`, while every sibling cadence script sources
   `lib/params.sh`. Source it; `get_param push-cadence-hours 24`; the
   env override is kept.
7. **`notify-immediate` tombstone row** (cadence-params.tsv:8)
   documents an env-only knob; the reader
   (`scripts/notify-email.py:162`) already documents it in its header.
   Delete the row; the kill switch stays.
8. **`DIGEST_HOURS` resolution.** `config.env:78` + its "keep in sync
   with systemd/hngh-morning.timer" comment. Verified zero consumers —
   the timer is the truth; delete both. (Wire-it rejected: a consumed
   shadow of the timer is worse.)
9. **`scripts/lint-identifiers.sh` → python3.** DEFERRED while green.

### Track B — TOPOLOGY (gated on the operator P0 decision)

Not restated — the plan lives in
[repo-merge-consideration.md](repo-merge-consideration.md): P1
machine-data quarantine, P2 `git subtree add --prefix=automation`, P3
env seam collapse (`HNGH_AUTOMATION_HOME` dies), P4 systemd cutover
(37 units), P5 doc/path sweep; gated on the P0 decision record.

What the audit adds: **Track A executes before P2**, so the history
that migrates is already lean — dead scripts, ~40 lines of model.sh,
the stub quintuplication, and the stopgap config never enter the
subtree; less to move, less to certify. P1 also retires the sweep
debris the dead-script references live in (sessions.json, digest/,
STATE.md).

## 3. Sequence

Each phase lands independently in `hngh-automation` behind its own `make test` gate and its own commit.

- **A1 — dead code** (finding 1). Gate: repo-wide grep zero live
  callers; `make test` green.
- **A2 — config truth** (findings 2, 6, 7, 8). Gate: deleted defaults
  byte-equal to surviving tsv rows; remote-push stamp behavior
  unchanged; `make test` green.
- **A3 — model.sh consolidation** (findings 3, 5). Gate: `make test`
  — the leg tests are the parity check, unchanged.
- **A4 — test stubs** (finding 4). Gate: `make test` with the
  extracted stub-lib; five call sites migrated.
- **Track B** — after A1–A4 and only on the P0 decision; see
  [repo-merge-consideration.md](repo-merge-consideration.md). A3, the
  largest behavior-adjacent diff, is verified before P2 freezes the
  history that migrates.

## 4. What NOT to do

- **Cadence tiers** (hour/day/30m tick design) — the model-free control
  plane ([descent.md](descent.md)); collapsing tiers re-concentrates
  scheduling the systemd timers already own.
- **Fail-closed breadcrumbs** — the error law (AGENTS.md: unknown
  input fails closed); every `breadcrumb ... -> next backend` is the
  boundary working.
- **Quota pacing** (`quota_pace_blocked`) — a real cost control; "just a heuristic" is not a deletion reason.
- **Mode-600 key checks** — the keyring trust boundary: the check IS the boundary.
- **flock token refresh** — single-writer race safety on the unsloth token.
- **`archive_only`** — the fail-closed fallthrough leg that keeps `model_call` total.
- **Torch audit station** — descent station 6 machinery, still being wired.
- **Per-caller env-over-tsv precedence** — the operator override law;
  Track A deletes stale defaults, never the override direction.

## 5. Expected outcome

- **Line delta:** ~-560 automation lines, measured (388 dead scripts +
  ~40 model.sh + ~120 stub dedup + config/row debris) — before any
  history moves.
- **Public-history effect:** on the quarantine path the sweep commits
  retire entirely (170/7d, the committed binary `telemetry.db`); on a
  stay-split decision they are pruned instead (option (d)).
- **Portfolio story:** one clone, one push, one URL; the 856 cross-repo
  reference lines become intra-repo and the dead relative links resolve.

---

Back to the [documentation index](../README.md).
