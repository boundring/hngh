# publication-review findings digest scrubbed through lib/scrub.py

2026-09-20, gate gap `wr-pub-paths-archive-scrub-debt::gate` (node
`gate-gap-publication-review-live-fire-proof::seed-524046b0`).

## The gap

`automation/jobs/publication-review.py` wrote the findings digest
(`~/.hngh/archive/digest/PUBLICATION-REVIEW-<date>.md`) with
machine-local paths in the raw: the header embeds the manga/dispatch
source paths and every adversarial FAIL line embeds the artifact path
(emission sites: the `findings_md` header line and the `open(out,
"w").write(findings_md(...))` site). Code-proven only; the emitter had
never been run-proven.

## Run-proof (pre-fix)

Manual deterministic invocation in a sandbox: `HNGH_HOME_DIR` and
`HNGH_REPORT_ROOT` pointed at a temp dir, repo drafts read-only, no
daemon, exit 0, ambient writes confined to the sandbox (digest file +
report-queue state only; a top-level walk of the sandbox showed exactly
the dispatch fixture, the digest, and the copied `report-queue`). The
digest landed with raw `/home/<user>/…` tokens in the header and in
two FAIL lines; `automation/lib/scrub.py` `scrub_grep()` census over
the captured file: 3 leak lines.

The stdout `FAIL <artifact> <cause>` lines keep the full path by
machine contract: the day wrapper (`automation/cadence/day/26-
publication-review.sh`) maps the basename onto scope
`publication:<basename>`, and anything persisted through report-queue
dies at the sink-side redaction guard (`scripts/report-queue`). The
directly written digest file bypasses the sink entirely — that file
was the leak.

## Fix

- `findings_md()` routes its whole output through `lib/scrub.py`
  `scrub_paths()` at the single emission point (the patrol.py
  pattern): header source paths, FAIL artifact paths, and path-bearing
  detail text die to the `[redacted path]` marker; URLs survive as
  wire data per the one token family.
- The import rides the `automation/lib` seam (`dirname(HERE)/lib`),
  which stays hermetic in the test sandbox layout (`$sb/lib`).
- stdout FAIL contract unchanged.

## Tests

Red-first in `automation/tests/test-publication-review.sh` section
(e): a clean-fixture digest (header leak) and a red-fixture digest
(FAIL artifact lines) are both asserted scrub-clean via `scrub_grep`,
and the clean digest must carry the `[redacted path]` markers. The
failing run captured the raw tokens in its output (second run-proof,
in-test); post-fix the full file is 11/11 green and
`test-scrub-module.py` / `test-patrol.py` are unchanged and green.

Post-fix run-proof: digest header renders `_manga: [redacted path] |
dispatch: [redacted path]_`, FAIL lines carry the marker,
`scrub_grep` census 0.