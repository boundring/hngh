# 2026-09-23 — overnight handoff

## State at handoff

`origin/main` through `ce605f2a`, all pushed (21:19Z: "Everything
up-to-date"). Evening run `d3afae01..ce605f2a` one-liners:

- `d3afae01`/`c63a3e38`/`e0a28599`/`ce605f2a` — docs: machine ledger
  sync (N changed files).
- `8d38b48d` — `hngh: candidate cc0a1eff5ba0991a5c3666a3d7136b39c9734245ef83bb155b6552e4ebd7717a`:
  `scripts/omp-bridge` AUTOMATION_ROOT defaults to `ROOT/automation`,
  orphaned `--register`/`--note` deleted; test asserts default +
  override.
- `0be14264` — crumbs: single writer (`automation/lib/crumbs.py`,
  `breadcrumbs.sh` shim) + mirror verify alert in
  `cadence/1m/15-crumbs-sync.sh` (evidence-gated report-queue row on
  `verdict=mismatch:*`).
- `8e4adc46` — plugin: hngh-bridge source into the repo
  (`automation/omp-plugin/`, `scripts/hngh-omp-update.sh` install,
  drift gate in `tests/test-hngh-bridge-plugin.py`).
- `ad6f8c69` — governance: GOVERNANCE.md aligned with the federal
  charter and canon ethos (341 lines, 13 sections); NOTE this commit
  also carries the stage-2-exit ui work (dashboard-server.py
  `/operator-item/handle`, app.js handle/dismiss affordance,
  style.css mobile sweep, `automation/tests/test-dashboard-lifecycle.py`)
  — mis-attributed lane, content complete.
- `505b6afd` — docs: changelog + package pins (billion-context pin
  0.1.106 → 0.1.141).

Earlier defense run (pre-batch): `5aa431fd` home-path guard at
commit/push/gate; `deaf3e4c` `hngh: candidate 248e882f...`
(loop-history guard re-key across the path-scrub rewrite);
`1932062d` re-key record; `6ec28ed2` machine ledger sync.

Gates: kernel `make test` = `2934 checks passed.` (green at the
`8d38b48d` ceremony commit and per every lane record); automation
`make test` green (176.16s run at 21:05Z) including
`test-dashboard-lifecycle.py` 7/7 OK re-proven at handoff;
`lint-home-paths: clean` on every commit and push.

## Session-restore incident (2026-09-23)

Read `docs/agent-notes/briefs/2026-09-23-session-restore-forensics.md`.
Verdict (c): session-tree fork at `session_exit` `a7dd5546`
(18:34:58.351Z) — the 21:41:32Z reopen rebuilt one branch and
silently dropped the 271-record sibling (the whole evening batch).
Nothing to re-do: content is intact on disk and in git; the final
report is recovered in the forensics brief.

Rule for overnight work: prefer single-host session ownership (one
omp process per session file); if a session forks after a
`session_exit`, treat the sibling branch as invisible to restore and
re-orient from git + `docs/project/reports.md`, not from context.

## Residuals (from the forensics brief's Disposition)

- unsloth token file vs the 1Password source of truth:
  `automation/config.env:37-38`, `automation/jobs/manga-vision.py:35`,
  `automation/README.md:67-69` — record-only; operator call to retire
  the file path.
- crumbs-writer-flip parity clock started `0be14264` 2026-09-23
  21:06:43Z — queue row `crumbs-writer-flip` stays `queued` until
  >=1 clean day of parity, then flip with the parity evidence.
- vault-cutover `env_vars.sh` stub — operator-lane follow-through
  (`docs/records/2026-09-21-vault-cutover-freshness.md`).
- `automation/dashboard/` gitignore stacking: new files need a
  `!dashboard/<name>` whitelist entry in `automation/.gitignore`
  before `git add` will see them.

## Standing next work

- Roadmap working order step 2: stage-3 governed-fleet slices A–G in
  order (`docs/project/roadmap.md`).
- Queue Next = `pooled-hardware` (deps open: resource pool view,
  key-pin registry rung 12).

## Self-service recovery (if restore truncates again)

The session jsonl is ground truth. Recover a message's text by id:

```
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / ".omp/agent/sessions/-Projects-etc-hngh/2026-09-23T15-47-51-210Z_01a0cef3-ad2a-72f5-987a-72b8de0e3fc0.jsonl"
for line in p.open():
    if '"8b307f53"' in line:
        rec = json.loads(line)
        for c in rec["message"].get("content", []):
            if c.get("type") == "text":
                print(c["text"])
PY
```

(Substitute any message id; `git log`/`docs/project/reports.md` cover
whatever the transcript cannot.)
