# nl-tooling scratch lab — physical-line damage audit of record.lisp consumers

Parent node: `gap-shared-store-replay::close-run-newline-write-hole::line-tooling-damage::seed-9e8ebd4e`

## HARD CONSTRAINTS (every child obeys)
- Repo `~/Projects/etc/hngh` and kernel: strictly READ-ONLY. No edit/create/delete under the repo.
- NEVER write into `~/.hngh-automation` (read / `cp` from it is allowed).
- hngh kernel binary (repo `scripts/hngh`, `$HNGH_CLI`) may run ONLY with `--store=` pointing
  inside `~/.jcode/scratch/nl-tooling/harness/<child>/...`. Never the default store, never
  `~/.hngh-automation`. Prefer read-style subcommands.
- Do NOT run automation jobs end-to-end. Extract functions / monkeypatch / use env seams.
- ALL writes under `~/.jcode/scratch/nl-tooling/` only. English/ASCII output only.
- Damage scale: `silent-data-loss` / `cosmetic` / `unaffected`.
- Every verdict LIVE-VERIFIED (actually executed) against (i) a crafted fixture and
  (ii) the scratch copy of the real store, or marked NOT-LIVE-VERIFIED with reason.
- Evidence file per child: `evidence/<child-id>.md` (commands + trimmed outputs + verdicts).

## Layout
- `stores/overnight/record.lisp` — READ-ONLY scratch COPY of the live production store
  `~/.hngh-automation/store/overnight/record.lisp` (copied 2026-09-20; original mtime Aug 27 23:14).
  Never mutate this copy; make your own copies under `harness/<child>/`.
- `fixtures/crafted/` — canonical fixtures (below).
- `harness/<child-id>/` — per-child sandbox.
- `evidence/<child-id>.md` — evidence logs.

## CONFIRMED ground truth (overnight copy, verified 2026-09-20)
- 2747 bytes, 6 physical lines, 3 top-level records, EACH SPANNING 2 PHYSICAL LINES
  (embedded 0x0A inside the `:OBJECTIVE` string). Lines 1-2 = CREATION, 3-4 = ADMISSION, 5-6 = CLOSE.
- Every record: `(:IDENTIFIER "run-1" :KIND :X :STATE :Y :RUN (... :OBJECTIVE "<line1>\n<line2 rest>" ... :STATE :<inner>) :RECEIPT (... :FACTS ("identifier: run-1" "timestamp: <ts>")))`.
- Top-level `:IDENTIFIER`, `:KIND`, `:STATE` are on the record's FIRST physical line (grep: lines 1,3,5).
- The continuation line (2/4/6) carries the objective remainder + `:NON-OBJECTIVES ... :VERIFICATION ...`
  + the INNER `:RUN` `:STATE` + the `:RECEIPT` with its `timestamp:` fact.
- Top-level states: CREATED / CREATED / DEAD (newest = DEAD, terminal). All ids "run-1".
- UTF-8 multibyte present in missions (U+2192 arrow, U+2014 em dash). No CR bytes observed.
- `dos2unix`, `sort`, `uniq`, `od`, `node`, `python3` all installed.

## Fixtures (`fixtures/crafted/`)
- `baseline-store/` — 3 single-line records, same lifecycle shape (control).
- `multiline-store/` — production shape: 3 records x 2 physical lines, objective embedded LF,
  UTF-8 in mission, receipt `timestamp:` facts on continuation lines.
- `adversarial-inner-state/` — record A: top-level `:STATE :CREATED` (line 1) but INNER
  `:RUN ... :STATE :EVACUATED` (line 2); record B: top-level `:DEAD` (line 1) with inner
  `:STATE :CREATED` (line 2). Probes "last :STATE match in file wins" parsers.
- `cr-store/` — mission strings containing bare 0x0D and CRLF pairs.
- `utf8-store/` — multibyte mission (CJK, emoji, arrow, accents).

## Env seams (verified in source)
- `automation/jobs/agent-supervision.py`: `BRIDGE_STORE` = env `OMP_BRIDGE_STORE`
  (default `<jobs>/../bridge`); `HNGH_BIN`, `OMP_BRIDGE_BIN`, `SUPERVISION_REPORT_QUEUE`,
  `SUPERVISION_STATE`, `SUPERVISION_SOURCES` all env-overridable (selfcheck `selfcheck_replace`
  :452-489 proves stubbing works).
- `automation/scripts/email-digest.py open_runs` :466-489: store = env `HNGH_DIGEST_STORE_DIR`
  (default `~/.hngh-automation/store`), reads `store/*/record.lisp` — so the LIVE
  `store/overnight/record.lisp` IS in its production glob.
- `automation/config.env`: `HNGH_CLI=$HNGH_HOME/scripts/hngh`, `HNGH_STORE=~/.hngh-automation/store`.
  Repo CLI lives at `~/Projects/etc/hngh/scripts/hngh` (verify existence).
- `automation/lib/hngh-record.sh record_hngh_run` :26 passes the raw mission string as the
  create-run objective (the write-hole source). `hngh_run_count` :69 = `find -name record.lisp | wc -l`.
- `automation/lib/common.sh update_dashboard` :113 = same `find|wc -l`.

## Consumer inventory (cited regions)
| consumer | file:lines | mechanism | suspicion |
|---|---|---|---|
| bridge_sessions | automation/jobs/agent-supervision.py :153-198 | per-PHYSICAL-LINE regexes; needs `:IDENTIFIER` + `:STATE` on the SAME line; `:OBJECTIVE "([^"]*)"` truncates at embedded LF; `timestamp:` only read from the same line | objective truncation; ts missed -> mtime fallback; record invisible iff :STATE left line 1 |
| replace_stalled_bridge_run | same :262-306 | kernel close-run + rotate record.lisp + re-provision with parsed objective | re-provisions the TRUNCATED objective (mission loss); rotation itself is byte-intact |
| record.lisp writer | same :469 | selfcheck FIXTURE writer (single-line literal) | fixture-only, not production |
| find_transcript | automation/jobs/sessions-feed.py :82-91 | path resolution only | likely unaffected |
| transcript_tail | same :97-103 | whole file splitlines, last TAIL_LINES PHYSICAL lines, per-line redaction | tail starts mid-record -> broken fragment (cosmetic?) |
| enrich fallback | same :394-433 | uses the tail above | inherits tail damage |
| bridge_rows | same :440-459+ | per-line accumulate, LAST `:STATE`/`:OBJECTIVE`/`:IDENTIFIER` match wins ("newest line") | inner `:RUN` `:STATE` on line 2 overrides top-level state -> misclassification |
| time-ledger receipt pairs | automation/jobs/time-ledger.sh :128-175 | per-line `:KIND :CLOSE` + same-line `timestamp:`; whole-text `:OBJECTIVE` regex | receipt ts on continuation line missed -> run contributes no wall (silent metric loss) |
| email-digest open_runs | automation/scripts/email-digest.py :466-489 | per-line last-`:STATE`-wins over `store/*/record.lisp` | same inner-state override; objective `[^"]{0,70}` truncation |
| update_dashboard | automation/lib/common.sh :113 | `find|wc -l` counts FILES | line-insensitive (expected unaffected) |
| hngh_run_count | automation/lib/hngh-record.sh :69 | same `find|wc -l` | line-insensitive (expected unaffected) |
| dashboard tail render | automation/dashboard/sessions-view.js :461-465 | `<pre>` + highlight(d.tail) | renders mid-record physical-line fragment |
| glossary | automation/dashboard/index.html :168 | docs line only | not a consumer |

## Child roster
- `c1-state-claim` — verify/refute ":STATE always on first physical line for CLI-written records".
- `c2-agent-supervision` — bridge_sessions / replace_stalled_bridge_run / :469 writer.
- `c3-sessions-feed-digest` — sessions-feed + email-digest.
- `c4-shell-consumers` — time-ledger + find|wc -l counters.
- `c5-dashboard-render` — sessions-view.js tail render.
- `c6-mutation-hazards` — dos2unix / sort / uniq / UTF-8 / CR / od.