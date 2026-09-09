# 2026-09-09 — publication pipeline --site increment

## Status
accepted. Evidence reviewed 2026-09-09T23:00Z.

## --site run output

`scripts/generate-publication --site=/tmp/pub-temp` completed successfully:
- Generated `/tmp/pub-temp/index.html` (7519 bytes)
- Output: HTML page with dashboard title, timeline, queue, live sessions, live agents, instance interaction, leaderboard sections

## Gap inventory versus research-lines surface

Per `automation/research-lines.tsv` row 17: "self-funding-paths-publications-ebook-site-operator-runway" (reviewed 2026-09-08T09:01:40Z).

The site currently lacks:
- Static content pages for each research line (currently only the dashboard HTML)
- Navigation between research lines (no index of research topics)
- Per-research-line detail pages (currently just the dashboard index)
- Operator-runway documentation (self-funding paths not yet surfaced)

## Verification

- No publication artifacts committed (git status clean for publication/site files)
- The generated HTML is a throwaway artifact in `/tmp/pub-temp/` (not committed)

## Kernel gate

`make test` passes (2855 checks, 2026-09-09T23:00Z).
