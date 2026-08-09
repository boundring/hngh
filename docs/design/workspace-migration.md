# Workspace migration: ~/.hngh-night + ~/.hngh-day → ~/.hngh/ (existing canonical root)

Status: DESIGN v2 (Sanakan 2026-08-09 12:00; owner-directed, live seats
execute the plan in action).
Owner: "night" never meant night — background queue work done whenever.
Merge day/night workbenches INTO the existing ~/.hngh/ root (already
git-tracked by backup-manager, already holds tasks/queue.lisp, agents/,
state/, journal/). Date-time-tagged subdirectories for session work;
stable paths for persistent state. Live seats organize their own
moves as ordered parts of the plan.

## Ground truth (inventory 2026-08-09 12:00)

EXISTING root `~/.hngh/` (git: backup-manager hourly auto-commit):
- tasks/queue.lisp (73.6K — machine-readable runner queue)
- tasks/night/, tasks/.done/, tasks/.blocked/
- agents/{1,2,3}/transcript.lisp  (session transcripts)
- state/ (hardware.lisp, mc-layout.lisp, locks/, plugins/, observations/)
- journal/ (coord/, events/, hnghbeats/)
- config/, plugins/, knowledge-base/, prompts/, runs/, secrets/
  (vault.lisp), sources/, sessions/ (EMPTY — the landing zone), tests/

TO MIGRATE (workbench content):
- ~/.hngh-night/tasks/ → ~/.hngh/tasks/night/ merge (dedupe, one deck)
- ~/.hngh-day/tasks/ → ~/.hngh/tasks/day/ (staged queue; per its
  QUEUE.md contract, becomes queue.lisp when Day-Ralph authority lands)
- ~/.hngh-night/artifacts/ → ~/.hngh/artifacts/history/
  (608K dated research/design artifacts)
- ~/.hngh-night/runs/ → ~/.hngh/runs/history/
- ~/.hngh-night/prompts/ sources/ tests/ → corresponding ~/.hngh/
- ~/.hngh-night/seat-names.md → ~/.hngh/registry/seat-names.md
  (registry/ exists, empty — landing zone)
- ~/.hngh-night/tandem-*/ (session lanes) → ~/.hngh/sessions/<ts>/
  (sessions/ exists, EMPTY — the designed landing zone)
- ~/.hngh-night/missions/ → ~/.hngh/sessions/<ts>/missions/ per session
  OR ~/.hngh/prompts/briefs/ (stable) — seat decides per content
- ~/.hngh-night/{benchmark-log,crash-recovery,plan-*,tandem-breadcrumbs,
  worklog, ralph logs, QUEUE.md} → ~/.hngh/sessions/<ts>/
- ~/.hngh-day/{QUEUE.md, day-ralph.log, supervisor_log.md,
  day-ralph.lock} → ~/.hngh/queue/, ~/.hngh/daemon/ respectively

COMPATIBILITY: until the migration wave completes, keep
`~/.hngh-night -> ~/.hngh` and `~/.hngh-day -> ~/.hngh` as symlinks so
live seats + scripts that reference old paths keep resolving. Retire
symlinks after ~6 months (owner option, default).

## Migration steps (executed by live seats as the plan's ordered work)

Owner 11:55: "live seats make live changes in an organized manner: we'll
have them handle this as orderly parts of the design's progression, its
plan in action."

1. SEU (coordinator): turn this doc into ordered subtasks with
   ownership — the deck. Confirm the target mapping above; anything
   ambiguous gets decided documentation-first (read the root's git log
   + file headers before choosing).
2. CIBO (coder): write the migration script `scripts/hngh-workspace-
   migrate.sh` — moves content per the mapping, creates symlinks,
   updates the 19 script referencers (seat-up, lane-watch, seat-steer,
   apollo-up, tandem-*, day-ralph, hngh-status, squad-*) to the new
   stable paths, and the 13 design-doc references. Test on a scratch
   HOME (bad idea to churn the real one) → verify → then run for real.
3. Both: post-migration, verify seat-up still spawns (scratch), lane-
   watch reads seats, make test green, seats' lanes resolve via new
   paths, backup-manager git commit captures the change.
4. SUPPORT: after the move, seat briefs (missions/*) point at new
   paths; update the breadcrumbs + future briefs to the canonical
   layout so no future session starts from stale paths.

## Verification (all must pass)
- ~/.hngh/sessions/<ts>/ contains dated session lanes from night/day.
- registry/seat-names.md exists; tasks deck merged with no dupes.
- old paths resolve via symlink; new paths work direct.
- make test exit 0; seat-up scratch spawn OK.
- git status of ~/.hngh shows the migration as one backup-manager wave.

## Coordination rule (owner: "smooth change")
- Never rename a lane mid-turn. Moves happen at phase boundaries only.
- The seats were already notified (inbox, 11:52). They ack in outbox;
  the migration proceeds per their phase rhythm.

## Owner decisions (defaults noted)
- Retire old roots after symlink stabilizes: DEFAULT keep ~6mo, then
  delete (ask owner at that time).
- Unified queue contract: sea/deck merge ≡ queue; queue.lisp stays the
  runner's machine form. Day QUEUE.md's staged-only contract holds until
  Day-Ralph authority lands.

Attribution: Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09.