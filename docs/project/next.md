# Next — Current Work

**Last updated**: 2026-06-22

## Current Session

**Session 0B**: Build system + CI scaffolding — **complete**

## Up Next

**Session M0.1**: SBCL project skeleton
- Create `src/packages.lisp` (package definitions for all core components)
- Create `src/main.lisp` (entry point with start/stop/main)
- Create `hngh.asd` (ASDF system with dependencies)
- **Exit criteria**: `./hngh` starts, logs "Hngh starting...", exits cleanly
- **Dependencies**: Session 0B (complete)
- **GitHub issue**: https://github.com/boundring/hngh/issues/1

Note: M0.1 is partially complete (packages.lisp and main.lisp exist as stubs from 0B).
The M0.1 session will flesh them out with proper initialization, logging levels,
and configuration loading.

## Blocked

Nothing blocked. Codeberg mirror pushed. GitHub project board configured (views need manual creation via web UI).

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support