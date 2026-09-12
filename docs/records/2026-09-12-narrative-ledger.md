# Narrative ledger and the public dispatch -- 2026-09-12

The operator asked for a narrative ledger "as well as any
clean-architecture mandated one" and for hngh to publish a newspaper --
a digest of its own activity AND the world's, with a public knowledge
base as a continual news record (see
docs/records/2026-09-11-operating-system-harness-vision.md). This
record states the inventory that answer is built on: which ledgers are
mandated, what narrative may attach, and where the public edition
lives.

## Ledger inventory

| Ledger | Location | Mandate (what it must contain) | Narrative attachment |
|---|---|---|---|
| Run receipts/certificates | git commits (`hngh: candidate ...`) via the ceremony loop | Byte-precise proof: candidate hash, gate verdicts, mutation evidence | None. Reconstructible from git; never decorated |
| Torch ledger | `automation/torch-ledger.tsv` + `STATE-OF-PROJECT.md` torch sentinels | Time/time-governance: artifact classes, write-only debt, audit numbers | None. Sentinel-bounded, machine-rewritten |
| Session handoffs | `automation/agent-handoffs.md` | Session lifecycle: launches, drops, respawns with cause | None. Watchdog-owned, append-only |
| Plan ledger | `docs/project/plans/*.plan.md` + `dashboard/plans.json` | Plan identity, acceptance, execution state | None. The story quotes its counts, never edits it |
| Report queue | `scripts/report-queue` ledger | Alerts pending operator review | None |
| Lessons | `automation/state/ocgo-agent-lessons.md`, `docs/project/lessons-<date>.md` | One line per failure class / harvested record | Quoted by the story (counts, newest class), never rewritten |
| Beat blockers | `automation/state/beat-blockers.tsv` | Durable stall rows: plan, cause class, count, status | Quoted by the story, never rewritten |
| Budget | `automation/logs/budget.md` | Overnight session budget per date | Quoted (session counts) |
| Telemetry | `automation/dashboard/telemetry.db` | Metered spend, tokens, calls, beats (append-only events) | Quoted (the meter read) |
| Public journal | `docs/journal/<date>.md` | Machine-checked counts (commits, candidates, check-ins) | The narrative layer lives HERE: `## The day's story` attaches after the ledger |
| Public dispatch | `docs/dispatch/<date>.md` | New: the day's newspaper edition, markdown | Generated whole from the same feeds |

## The mandated/narrative rule

Mandated ledgers stay byte-precise: the narrative never rewrites them.
Narrative layers attach. In the journal the attachment point is the
`## The day's story` section (after the machine-checked ledger,
before "The book of the day"); in the public README the
`dispatch:begin/dispatch:end` sentinels keep their bytes outside the
block. Every narrative sentence is grounded: each paragraph is
preceded by a `<!-- feeds: ... -->` citation naming the source file,
the same convention the megastructure block uses.
## The narrative ledger (the day's story)

Written by `scripts/generate-publication --daily`, deterministic -- no
model call at render time. Structure, one paragraph per state, each
with its feeds comment:

1. The hall fired: sessions and lanes from `automation/logs/budget.md`,
   metered spend/calls/tokens from `automation/dashboard/telemetry.db`,
   plan counts and queue-next from `automation/dashboard/plans.json`.
2. The outside world: the loudest digest line (first CRITICAL, else
   first item) with its UTC stamp, from `automation/digest/<date>.md`
   Deck A -- parsed by the digest-html module itself so the story and
   the page can never disagree.
3. The stalls: rows the day added to
   `automation/state/beat-blockers.tsv` (plan, cause class, count,
   status), or the honest quiet line.
4. The learning loop: session lessons filed in
   `automation/state/ocgo-agent-lessons.md` plus records folded in by
   `docs/project/lessons-<date>.md`.
5. Verdict: one line -- research-line posture (advancing/holding/
   quiet), open operator items, blockers on file.

Register voice: evidence-first, one caption per state, counts over
adjectives, ASCII only. Optionally model-polished later behind a flag;
the deterministic layer ships first.

## The public news record

`automation/jobs/digest-public.py` renders `docs/dispatch/<date>.md`
from the same pulls as the HTML page (reusing jobs/digest-html.py):
masthead with edition number, THE LEDGER stat block, Deck A verbatim
digest items, Deck B grounded megastructure blocks, the day's lessons,
and a reading-room link list (journal, raw digest, records, research).
Wiring: `generate-publication --daily` calls it after the journal
step; the journal's ledger section links back to the edition (the
lower-touch README option -- the sentinel generator is untouched).
Committed markdown is GitHub-safe: no HTML, no JS, no external
assets. Continual record: one file per day, the public knowledge base
grows a page a day.

## Verification

- `automation/tests/test-narrative-ledger.py` (9 cases, hermetic):
  story after ledger with ledger intact; every paragraph grounded;
  all-feeds-missing still structured; masthead numbers match fixture
  telemetry; dispatch file written; fail-open on missing digest;
  README sentinel bytes identical outside the block; sentinels
  absent -> refused; full --daily writes journal + dispatch and
  --check still verifies.
- `cd automation && make test` green (full suite, 2026-09-12).
- `env -i` hermetic runs of the new and adjacent suites green.
