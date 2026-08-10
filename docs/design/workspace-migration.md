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

## SEAM-FIRST (card 123 gap 3, seu 23:58 — 114's first deliverable)

The migration must NOT be a move that breaks hardcoded consumers.
Today three components hardcode the workbench root:
- src/plugins/dashboard-tui.lisp: *watch-root*, *seat-registry-
  path*, *owner-inbox-path*, *seat-lanes-root*,
  *claims-register-path* (all /home/bricker/.hngh-night/...)
- /home/bricker/.local/bin/hngh-watch: HNGH_HOME env with default
  /home/bricker/.hngh-night (SCHEDULES/CONTROL/OUTCOME_LOG under
  HNGH_WATCH_CONFIG)
- src/plugins/hngh-coord/coord.lisp: *lane-root*
  /home/bricker/.hngh-night

SEAM DESIGN (do this FIRST, before any file moves):
1. Introduce ONE config point: `*hngh-home*` (Lisp) /
   `HNGH_HOME` (env, already used by hngh-watch) resolved from:
   env > ~/.config/hngh/config (or ~/.hngh/config) > default
   (~/.hngh). Every consumer reads the seam; NO hardcoded paths
   remain in code.
2. The seam is a getter, not a constant — tests bind it to a
   scratch HOME (see fixture shape below), the real code binds it
   to the canonical root at startup. Same pattern as the
   configurable feed paths in the dashboard (already defvars).
3. Once the seam exists, the migration becomes a DATA move: point
   the seam at ~/.hngh, symlink the old roots for the 6-month
   compat window, verify every consumer still resolves.
4. Acceptance for the seam: `grep -rn '/home/bricker/.hngh-night'
   src/ ~/.local/bin/*.py` returns ZERO code hits (docs + lane
   history may retain them; code must not).

SCRATCH-HOME FIXTURE SHAPE (the migration harness):
- A fixture HOME (tmp dir) with a minimal ~/.hngh tree (state/,
  tasks/queue.lisp stub, registry/, sessions/) + symlinks
  night/day -> the fixture root.
- Tests bind *hngh-home*/HNGH_HOME to the fixture, then exercise:
  seat-up scratch spawn (already in 114 §Verification), lane-write
  via the append helper, dashboard render-to-string reading the
  fixture feeds, hngh-watch SCHEDULES/CONTROL resolution under the
  fixture config dir.
- The harness proves the move is SAFE on a fake root before any
  real ~/.hngh-night mutation (cibo 23:10 recommendation, agreed:
  scratch-HOME migration harness before the real move).

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
---

## Task deck (Seu decomposition, 2026-08-09 12:35 — card 112 step 1)

Ownership split per the card: SEU = coordination/deck/missions call,
CIBO = migration script + referencer updates, KILLY = verification.

T-SEU-1 (DONE, this section): mapping confirmed against live
inventory 12:35 — root/registry/sessions landing zones all present and
empty; ~/.hngh-day has artifacts/ + tasks/ beyond the doc's explicit
list (fold them with night -> history/ + tasks/day/). `night/datasets`,
`night/research` are EMPTY (0 bytes) — nothing to move; keep the dirs
or drop per owner, default DROP (git tracks the layout; empty dirs
vanish). `night/ralph-tasks/.done` (12K) = stable done-stack → keep as
`~/.hngh/ralph-tasks/` alongside tasks/ (persistent queue artifact, not
dated-session content). `tandem-live` symlink points at tandem-apollo
which is a CLOSED morning lane — Cibo: point it at nothing/remove, or
at the current active seat lane (killy) per the "live" concept; pick
killy, note in the script.

T-SEU-2: missions placement decision — active missions (crash-resume
for cibo/seu/killy) are SESSION content → land in
`~/.hngh/sessions/<ts>/missions/`; stable evergreen briefs (none today
except plan-2026-08-09) → `~/.hngh/prompts/briefs/`. Migration moment:
at the NEXT phase boundary per seat, so nobody loses their lane
mid-turn (owner's smooth-change rule). Until then missions stay put,
symlink keeps them resolvable.

T-CIBO-1: write scripts/hngh-workspace-migrate.sh for the mapping in
the design doc + the deltas above (day/artifacts, day/tasks,
ralph-tasks, tandem-live fix). Symlink ~/.hngh-night -> ~/.hngh and
~/.hngh-day -> ~/.hngh. Update the 19 script referencers + 13 design
docs. ALL moves guarded: refuse to move when a source path is a live
lane mid-turn (check tmux sockets), refuse to clobber an existing
destination. Test on scratch HOME first.

T-CIBO-2: referencer sweep acceptance — grep for ~/.hngh-night/day
must return only symlink definitions + this doc's history after the
migrate + referencer updates.

T-KILLY-1: verify post-migration: seat-up scratch spawn OK, lane-watch
reads seats via NEW paths, make test exit 0, ~/.hngh git (backup-
manager) shows one wave, ~/.hngh/sessions/<ts>/ has the dated lanes.

Owner-gated (no blocking): retire-old-roots at ~6mo; queue.lisp
contract until Day-Ralph authority.

ACK: seats were notified 11:52 (design doc) + this deck supersedes;
ack this in your lanes before running script on the real HOME.
