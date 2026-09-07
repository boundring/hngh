# Context manager (display alias: "the Compass" — orientation)

Status: designed 2026-09-07 from the measured baseline in
hngh-automation/docs/session-cost-analysis-2026-09-07.md. Orientation is
the single largest token sink in delegated sessions and is therefore a
cross-cutting concern of the Descent: every station wakes a session, and
every waking pays the orientation cost. This doc makes context
management routine machinery, not an ad-hoc packet each plan assembles.

## 1. The problem, in this project's own numbers

From the 2026-09-07 analysis (last 7 days of delegated sessions):

- 12 paid lead sessions burned 3.77M input tokens for 592k output —
  in:out ratios 1.3x-40x; the two worst (40x, 36x) were dashboard/feed
  self-reviews that read machine-greppable material by hand: 1.9M
  combined input tokens for 95k output.
- 16 local bench sessions ran 65x-281x; the worst (2026-09-07 03:03)
  consumed 3,632,224 input tokens for 16,340 output and a 41-byte final
  log, cause=unknown.
- ~44% of sessions since 08-28 produced nothing (10 rc=124/1 dead
  timeouts plus 4 no-output rows) — and the dead ones still spent:
  each paid timeout forfeits $1.5-2.2 of mid-work input spend; one
  gate-blocked night spent $9.23 re-deriving the same blocked state
  four times.
- The analysis's own finding: fixed per-session overhead (the brief
  skeleton) is <1% of input tokens. Essentially all waste is variable
  spend on orientation — re-reading plan, ledgers, reports, and git
  history every wake.

## 2. Three duties

### 2.1 Orientation at start — the context pack

Every delegated session orients from a context pack: one bounded,
pre-digested file assembled at launch from existing artifacts — repo
map, ledger paths, role hint (what good output looks like for the
session's role), and the frontier (the torch-sentinel Verified-numbers
block from docs/project/STATE-OF-PROJECT.md). Hard cap 1500 bytes,
`head -c` enforced. The single generator is
`hngh-automation/lib/context-pack.sh` (`context_pack ROLE SLUG`); both
launch paths — the gated launcher `lib/launch-session.sh` and the
watchdog respawn executor `jobs/agent-respawn.sh` — consume it. No
second pack builder may be added; the pack path is carried in the
session brief and the prompt pointer line ("read this before
re-deriving any repo fact") bounds discovery to one citation.

### 2.2 Reorientation on interruption — death/steer briefs

The roguelike respawn path (hngh docs/project/roguelike-agentic.md)
launches a failure-informed replacement. The brief follows the minimal
eight-field schema (docs/research/2026-08-30-handoff-brief-schema.md —
flat, one `field: value` line per field, `not established` never a
guess). The context manager adds one bounded reorientation block:
pack path (the same pack file the replacement's launch regenerates) +
death cause + one corrective instruction. The reborn session orients
from the same derived state the dead one used, in one read, instead of
re-walking the ground that killed its predecessor. The brief stays a
pointer-carrier (~1.5KB cap) — packs are never inlined.

### 2.3 Lifetime compaction — checkpoints (designed, not built)

Long sessions should checkpoint at turn boundaries so a reborn session
reorients in one read: what state to persist is exactly the brief's
fillable fields — objective, budget spent, landed, uncommitted — plus
the smallest set of verified facts the next step needs. The handoff
schema already defines the shape; the missing piece is the dying
session emitting it (fields 1/2/4/5/6 are always fillable from
producers; 3/7/8 only with real evidence). Until that wire exists,
respawn briefs carry `not established` for session state, which is
honest but blind — the compaction wire is the designed fix, not built
today.

Boundary (2026-09-07): in-session token compaction is billion-context's
authority (the operator's proxy, per hngh
docs/records/2026-08-24-context-budget-and-toolchain.md). Hngh's
checkpoints are turn-boundary respawn briefs layered on top — never a
second compressor. The ctx-compaction-strategies research subject
resolves against billion-context as prior art.

## 3. The measurement loop

The tracked metric is the per-session input:output ratio. Telemetry
kind=session-cost already captures tokens per session hourly
(cadence/hour/25-session-cost.sh -> jobs/telemetry.py); the ratio job
`cadence/day/21-context-ratio.sh` (producer jobs/context-ratio.py)
reads the last 7 days, computes paid/local medians and the worst
session, and files ONE identity-deduped report-queue progress row
(identity `context-ratio:<date>`) with the trend vs the previous row.
Model-free and deterministic. Targets, measured weekly: paid sessions
toward <=10:1, local toward <=50:1 (from the measured 40x paid / 281x
local ceilings). The row is the Compass's weekly vital sign; the day
the trend stops moving down, the pack contents — not the metric — are
the thing to change.

## 4. Research subjects opened

Queued in hngh-automation/research-subjects.txt (ctx-* rows): long-
session compaction strategies (what to persist at turn boundaries),
structured briefs (which fields measurably cut reorientation cost),
and retrieval vs repetition (pointers vs inlined content at equal
task quality). Each lands through the Delve station with a named
consumer before adoption.

## 5. Boundaries

- Packs are derived data, never sources of truth. The ledgers and
  kernel docs behind them are; a pack that drifts is regenerated at
  the next launch and no record may cite a pack as evidence.
- No secret values ever enter a pack (the Keyring law,
  [keyring.md](keyring.md)): credentials live in the keyring harness
  and its store; packs carry paths and ledger names, never values.
- One generator, two consumers, one cap. A second orientation file
  builder is the exact duplication this concern exists to delete.

## 6. Lexicon row

Per the Lexicon scope rules in [descent.md](descent.md) (design-layer
alias, same tier as the Mirror and the Keyring; never a path, package,
CLI flag, or record field):

| Alias | Canonical term | Scope |
|---|---|---|
| the Compass | context manager | design layer; display alias (this file) |

Adopted into descent.md's Lexicon table at that file's next landing
(`descent.md` Lexicon, row added 2026-09-07).
