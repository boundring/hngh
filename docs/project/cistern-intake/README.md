# Cistern intake — the Hngh-side acceptance queue for Cistern v6

## What this queue is

The Cistern repo (`/home/bricker/Projects/etc/20260830/cistern`) has a
21-directive expansion queued (`cistern docs/v6/V6-SPEC.md`, wave-ordered
V6-01..V6-21). The director's live runs landed wave 1's first two directives
and then halted cleanly mid-wave (ledger L-112) so the work could hand off to
Hngh's automated cycles. This directory is that handoff: one packet per
directive, packaged for a Hngh cycle to claim and execute under the standing
rules.

Packets are **pointers, not copies**. The authoritative contracts stay
single-source in the cistern repo:

- `docs/v6/V6-SPEC.md` — the consolidated build plan: PROTECT block, conflict
  rulings R-1..R-8, wave order, per-directive acceptance namespaces.
- `docs/HANDBRIEF-TEMPLATE.md` — the brief format every packet follows.
- `docs/FAILURE-LEDGER.md` — the harvested lessons; packets cite entry
  numbers (L-0NN), never restate them.
- `docs/PROCESS-RETRO.md` — the standing process changes (P1..P6) and
  steering lessons the packets inherit.

## Acceptance procedure — how a Hngh cycle takes a packet

1. **Claim.** Read `QUEUE.md`; the head packet is the first QUEUED packet
   whose wave gate is satisfied. A cycle claims exactly ONE packet. Before
   its first mutation, run the three reconciliation probes (field report
   item 3): `git -C <cistern> log --oneline -5` (what landed), the full
   canonical suite `emacs -Q --batch -l tests/run.el -f
   cistern-run-all-tests` (what holds), ledger continuity (the last L-0NN
   entry names the halt state). If reality disagrees with the packet's repo
   state, reality wins — record the delta in the packet's outcome section
   and proceed from the actual state.
2. **Execute per the packet's embedded brief** under the standing rules:
   - **Fail-first red/green** (HANDBRIEF-TEMPLATE): the red test commit
     precedes the green implementation commit; an unexpected red-pass
     strengthens the probe, never manufactures a bug (P5).
   - **Commit-per-green** (P2, field report item 2): every green boundary is
     a commit boundary in cistern. A death costs at most the current pair.
   - **Ledger harvest** (§5.3 format): every death, deviation, or ruling
     lands in `cistern docs/FAILURE-LEDGER.md` as the next L-0NN entry
     before anything else.
   - **Death-and-replacement** (roguelike-agentic.md): a cycle that stalls,
     loops, or operates on a faulty basis is dead — call it off, harvest,
     and the successor starts from a failure-informed re-brief (append the
     failure to the packet's outcome section; the next cycle re-claims the
     same packet with the failure named).
   - **Green-boundary sync**: at each green boundary, sync the installed
     cistern copies per the cistern standing rule (see L-112's sync notes).
   - **TTSR tool shape**: the operator's stream rules govern tool use inside
     the cycle — `large-file-incremental-writes` (no write ≥150 lines in one
     generation; ≤60 lines per append), `heredoc-rewrite-caution` (write
     tool for whole-file rewrites; heredocs only for surgical edits <40
     lines), `sed-surgery-nudge` (2nd+ `sed -i` on one file = stop, re-read,
     one verbatim rewrite), `doc-heredoc-length-guard` (no ≥150-line heredoc
     in one generation).
3. **Phase-closing review** (HANDBRIEF-TEMPLATE's six-item checklist) at
   wave close only; structural findings are ledgered, never fixed in passing.

## DONE criteria — when a packet is done

A packet is DONE when all of these hold:

- The directive's `Done-when` acceptance criteria (verbatim from V6-SPEC
  §3, with the source-doc namespace tests) pass red-first: failing before
  the change, passing after, in the canonical batch suite.
- The whole canonical suite is green (baseline 140/140 at queue time).
- The PROTECT block invariants named in the packet still hold (they hold
  with each layer off OR on).
- The work is committed in cistern (red + green commits at minimum), the
  ledger carries this packet's L-0NN entry, and `QUEUE.md`'s status column
  says LANDED with the commit hash(es).

## Where results are recorded

- Each packet file ends with an **Outcome** section: status, commit
  hash(es), ledger entry number, and any re-brief notes for a successor.
- `QUEUE.md` is the index of record: status column (LANDED / QUEUED /
  BLOCKED) plus wave gates. It is updated at every green boundary.
- A pointer back to the cistern ledger: the packet's Outcome names the
  L-0NN entry; the cistern ledger is the authoritative failure record.
- Backlog items (post-playtest structural packets) live at the bottom of
  `QUEUE.md`, clearly separated from the v6 build.

## Claim protocol summary

```
claim   = first QUEUED packet in QUEUE.md whose gate is satisfied
first   = reconciliation probes (git log, suite, ledger tail)
execute = packet brief under standing rules; one packet per cycle
record  = cistern ledger L-0NN + packet Outcome + QUEUE.md status
```
