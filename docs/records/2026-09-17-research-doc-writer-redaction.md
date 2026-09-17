# 2026-09-17 research-doc writer redaction (crystallized-doc title gap)

## Trigger

Adversarial audit gap (gate wiki-health-wiring-reconcile): the
crystallized-doc writer in `automation/cadence/hour/33-research-beat.sh`
was a live un-redacted emitter onto a git-tracked, publicly pushed
surface. At write time the transition `printf`'d the RAW lines-TSV
question text (`printf '# %s\n' "$line"`) as the doc title plus the
model body into `$KERNEL/docs/research/<day>-<id>.md`, then
`research_commit` shipped it. docfilter.py covers injection + char cap
only. Proof it leaked: HEAD:docs/research/2026-09-17-fail-20260916-
If-the-probe-returns-a-clean-negative-fo.md line 1 carried a literal
`/home/bricker/Projects/etc/hngh`; 144 tracked docs/research files
contained `bricker`; `git grep -o '/home/bricker' HEAD` counted 729
hits repo-wide. The TSV sweep node (research-tsv-raw-columns-fix)
explicitly scoped only the four data files and deferred these docs;
its gate (`--check`) covered only the TSVs.

## Two-lane anatomy (why one seam was open while the other looked safe)

- **Body lane** was already covered at the `model_call` chokepoint
  (lib/model.sh `_scrub_paths`, the marker family of the single-source
  lib/scrub.py): the leaked doc's body shows `[redacted path]` markers.
- **Title lane** was open: `$line` is direct research-lines.tsv column-4
  text, never model output, so no output chokepoint ever saw it. The
  ingest seams redact at TSV-write time, but rows committed before
  2026-09-17 carry raw text in the TSV history, and the writer read
  the TSV row verbatim.

## Writer cure (fail-closed, one token family)

After the docfilter/injection block and before ANY write (digest beat
copy included), the beat now runs `redact_home` (lib/scrub.py tilde
family; fail-closed to empty output when the module breaks) over BOTH
`$line` and `$body`. Either coming back empty is a new
`redaction-failed` outcome: alert filed, blocker escalation, nothing
written, line state held for retry. Digest copy and crystallized doc
stay byte-identical siblings. The redact_home fixpoint is the clean
invariant: pre-existing tilde forms and URL home components
(`https://x.io/home/u/f`) pass untouched.

## Red-first proof

`automation/tests/test-research-doc-writer-redact.sh` (full-beat
harness: stub model chain, sandbox kernel git repo, pathy id + pathy
STUB_CONTENT body): 4 assertions fail against the unguarded writer
(raw token in worktree doc, in the committed HEAD blob, title not
tilde-rendered, digest copy leaked), all green after the cure. The
suite also guards its own harness: a sandbox with a missing/broken
lib/scrub.py copy fails loudly instead of faking a pass through
redact_home's fail-closed empty output.

## Back-redaction (forward-only)

`scripts/research-tsv-path-sweep.py` scope widened from the four
research data files to also sweep tracked `docs/research/*.md` (glob
expands against the enclosing git toplevel; ROOT-resolved TSVs +
toplevel-relative docs, CWD-independent so the gate, an operator, and
the live beat all resolve identically). `--apply` swept 153 research
docs (578 lines rewritten through redact_home from HEAD blobs;
worktree-refusing rc=2 dirty-guard kept: the dirty
research-subjects.txt with in-flight live-beat appends was correctly
refused mid-run). Zero raw `/home/<user>` tokens remain in
docs/research; the full-scope `--check` is green.

Residue kept, with reasons (GAP-B precedent: ids are immutable
research keys):

- Ids/slugs baked into FILENAMES and the Status lines that quote them
  (`fail-20260914-Where-exactly-in-home-bricker-Projects-e`): renaming
  tracked research keys breaks the digest cross-reference and the
  TSV `id` linkage; the slug is a pre-redaction-era artifact, not a
  live emitter (the ingest seams now redact before derivation).
- Two prose mentions of `bricker` as a hostname/name ("brickertop",
  "bricker's HF cache"): not `/home/<user>` token-family members;
  swept only if the operator directs a wider net.
- `~/.unsloth/studio` style tilde forms: the fixpoint invariant --
  already-conventioned forms stay.

History is untouched (no rewrite, no force-push): pre-scrub bodies
keep their `[redacted path]` markers; raw content remains in git
history until the operator directs otherwise (same forward-only
posture as the GAP-B TSV sweep).

## Gate coverage

`automation/Makefile` `make test` now runs the sweep `--check` over
the full default scope (four research data files + all tracked
docs/research/*.md), so a newly committed raw research doc goes red at
the gate. The sweep test suite grew md-doc groups: glob check counts,
apply back-redaction from HEAD blobs with invariants asserted (title
tilde rendering, pre-existing tilde preserved, URL untouched),
re-check green, dirty-md refusal rc=2.

## Verification

- `bash automation/tests/test-research-doc-writer-redact.sh` (new,
  red-first proven by reverting the writer block: 4 failures, restore:
  green)
- `bash automation/tests/test-research-tsv-path-sweep.sh` (9 groups)
- `python3 -B automation/scripts/research-tsv-path-sweep.py --check`
  (full default scope, green)
- `make test` in automation/ (full gate, ALL PASS incl. the widened
  check)
- Post-sweep census: `grep -rEho '/home/[a-z0-9_-]+' docs/research`
  empty; per-line redact_home fixpoint scan over docs/research: 0
  non-fixpoint lines.

Commits: 9afe899b (docs lane: 153 swept docs), 1d846a75 (free-commit
lane: writer cure, sweep scope, tests, gate). Kernel src/, tests/,
Makefile, hngh.asd untouched.
