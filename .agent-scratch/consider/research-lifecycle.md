# Research lifecycle audit — 2026-09-15 (read-only)

## 1. Quantify
- research-lines.tsv (165 lines): 21 planned, 141 reviewed, 2 crystallized, 1 expanding.
- research-dispositions.tsv (169): 73 adopted, 64 parked, 31 killed, 1 fixed, 1 action.
- Digest archive: 124 RESEARCH-BEAT digests under ~/.hngh/archive/digest/; 217 crystallized docs in docs/research/.
- Post-completion consumption: docs/research/ is only read for freshness mtime (research-feed.py:92) and as a pointer in context-pack.sh. patrol.py reads dispositions.tsv solely as alert-history input (patrol.py:1476). No beat, job, or script ever reads an adopted disposition's verdict/followons back as guidance. 0 of 73 adopted rows feed any runtime decision.

## 2. Lifecycle map
33-research-beat.sh: planned → expanding → contracting → crystallized (writes docs/research/<date>-<id>.md + digest) → review (two-sided) → research-dispositions.tsv row + lines.tsv state=reviewed. TERMINUS. Adopted verdicts sit in TSV columns (support/oppose/followons) that nothing consumes; the only onward motion is follow-on subjects re-entering the same loop. The pipeline is circular, never cumulative.

## 3. Existing destinations (unused)
- llm-wiki vaults: ~/.llm-wiki (61 sources) and project vault (53). Ingestion is MANUAL only — the repo supplies read-only pointers into the vault (33-research-beat.sh:150,346) and a wiki-health patrol (day/25-wiki-health.sh); no beat writes research results into it. research-feed.py merely counts sources.
- jcode memories ~/.jcode/memory/: global.json + projects/ exist, no hngh writer.
- hngh docs/records/ has "Lessons (llm-wiki)" sections — again, harvested by hand.
- Report queue / agent-handoffs.md: coordination only, not knowledge storage.

## 4. Smallest proposed pipeline (existing seams only)
One crystallize-time extension in 33-research-beat.sh, after it writes docs/research/<id>.md (and again at review, using the verdict):
(a) KB entry: the beat already talks to the model chain; add a step that appends a condensed lesson (title + 5-line finding + pointer to the docs/research path) to the llm-wiki project vault sources/ dir as a plain markdown file (same shape kb-feed.py and wiki-health already expect; vault index refresh stays with the existing rebuild seam).
(b) Memory: the beat's free-commit lane can append one line per adopted disposition to a file (e.g. automation/research-lessons.tsv, id, verdict, one-line lesson, evidence path); context-pack.sh:89 already prints a research index line — extend it to surface top-N lessons, making them reachable by every future session.
(c) Lesson line: no new mechanism needed — adopted verdicts are already prose; the step above is the lesson line.
What's missing: (1) topic clustering/folding of related lines (dispositions name duplicates but nothing merges them); (2) a dedupe/refresh rule so re-dispositions update rather than duplicate vault entries; (3) jcode-memory write seam (hngh has no tool contract for ~/.jcode/memory — recommend the TSV surface instead).
