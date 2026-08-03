# Squad Automation Bootstrapping — Plan

**Date**: 2026-08-03
**Author**: PM (z-ai/glm-5.2, Hermes harness)
**Status**: Active — design delegation to Designer in progress

## Goal

Automate squad startup end-to-end. The PM's first prompt is procedurally
generated from project/system/OptMem context. Per-role prompts are seeded
by the PM after orientation. Squads self-orient, self-journal, and feed
hngh's self-improvement loop. This is M9 Wave 3 (C7 self-written prompts,
C4 start-now defaults) plus the supporting infrastructure (file-change
notification, test-count lint).

## Waves

### Wave 0: Procedural test-count lint (no LLM)

Stop using LLMs to update test counts. Build a lint that runs `make test`,
parses the "Did N checks" line, scans docs for `N/M` patterns, reports
mismatches. Exit 1 on stale, 0 on fresh. Wire into `make check`.

**Files**: `scripts/lint-test-counts.sh`, `Makefile`
**Acceptance**: `make lint-counts` exits 0 with fresh counts, 1 with stale.
**Tests**: fixture-based — synthetic docs with known counts.

### Wave 1: C7 PM-first-prompt generator

Procedurally assemble the PM's first prompt from:
- AGENTS.md discovery/merge (C1, built)
- Plans and design docs in the working directory
- System context (GPU, local models, systemd units)
- Roadmap status
- OptMem recent notes
- Squad intent (goal string, lifetime policy)
- Per-role model config

**Files**: `src/plugins/hngh-up.lisp` (extend), `src/plugins/squad-up.lisp` (new or fold into hngh-up)
**Acceptance**: `hngh up "review plugins" --dry-run` prints a PM-first-prompt containing AGENTS.md sections, plan summaries, system context, roadmap state, and OptMem notes. No static prompt strings.
**Tests**: fixture-based — synthetic project dir with AGENTS.md, plans, roadmap; assert prompt contains expected sections.

### Wave 2: File-change notification system

Generalize config-watcher into a registered-path file-change bus. Plugins
register interest in paths. Watcher emits `file.changed` events with path
+ diff summary. For daemon mode: systemd `.path` units (gbd pattern). For
local mode: mtime-poll fallback.

**Files**: `src/plugins/config-watcher.lisp` (extend or new `src/plugins/file-watcher.lisp`), `data/hngh-file-watcher.path` (systemd template)
**Acceptance**: Plugin registers interest in `docs/project/roadmap.md`. File is touched. Event bus receives `file.changed` with the path. Squad members subscribed to the path receive the event.
**Tests**: fixture-based — synthetic file, registered watch, event assertion.

### Wave 3: Squad journal lifecycle

Wire journaling into squad startup, ongoing work, and shutdown:
- Startup: `-projected.md` with goal, roles, models, planned work
- Ongoing: PM writes to `-actual.md` triggered by file-change events
- Shutdown: `-fragment.md` (C5, built) with unfinished work, resume hints

**Files**: `src/plugins/fragment-journal.lisp` (extend), `src/plugins/hngh-up.lisp` (extend), `~/.local/bin/squad-up` (extend)
**Acceptance**: `hngh up "test goal" --dry-run` shows projected journal path. `squad-up --stop` writes fragment journal. PM-first-prompt includes journal directive.
**Tests**: fixture-based — synthetic squad, assert projected/fragment journals contain expected fields.

### Wave 4: squad-up integration

Wire the PM-first-prompt generator into `squad-up`. The PM seat gets the
generated prompt instead of a static string. Other seats get role-specific
prompts seeded by the PM after orientation (PM writes to AGENTS.md or
OptMem, other seats pick it up on startup via their own context gathering).

**Files**: `~/.local/bin/squad-up` (extend), `~/.hngh-night/squad-seats.conf` (update)
**Acceptance**: `squad-up pm` launches PM with a procedurally-generated prompt containing repo context, plans, system state, and OptMem notes. No static `SEAT_PROMPT[pm]` string.
**Tests**: integration — run `squad-up --dry-run pm`, assert prompt output contains expected sections.

### Wave 5: Self-improvement loop bootstrap

The recursive cycle: hngh's roadmap → task decomposition → squad dispatch →
squads work on hngh → results feed back into roadmap. Wire the first real
iteration: a squad that reads the roadmap, identifies the next wave, and
dispatches itself.

**Files**: `src/plugins/hngh-up.lisp` (extend), `src/plugins/agent-platoons.lisp` (new or extend)
**Acceptance**: `hngh up "next roadmap wave" --auto` decomposes the roadmap, identifies the next unstarted wave, and generates a squad spec for it.
**Tests**: fixture-based — synthetic roadmap with wave statuses, assert spec is generated for the next unstarted wave.

## Dependencies

```
Wave 0 (lint)           → independent
Wave 1 (C7 generator)   → depends on C1 (done)
Wave 2 (file-change)    → depends on config-watcher (done)
Wave 3 (journal)        → depends on Wave 1 + C5 (done)
Wave 4 (squad-up)       → depends on Wave 1 + Wave 3
Wave 5 (self-improve)   → depends on Wave 1 + Wave 4
```

Wave 0 and Wave 2 can run in parallel with Wave 1. Wave 3+4 after 1.

## Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Designer — GLM-5.2 via openrouter (design doc pending).
Worker/Coder — local/free models (implementation pending).
