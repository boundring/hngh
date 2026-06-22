# Next — Current Work

**Last updated**: 2026-06-22

## Current Session

**Session M0.1**: SBCL project skeleton — **complete**

## Up Next

**Session M0.2**: Event bus (A2)
- Implement internal pub/sub with topic namespacing
- Event journaling to State Store (append-only)
- Persistent subscriptions (replay from journal)
- Backpressure policies (:block, :drop, :queue)
- **Exit criteria**: publish/subscribe works; events journaled; persistent subscriptions replay
- **Dependencies**: M0.1 (complete)
- **GitHub issue**: https://github.com/boundring/hngh/issues/2

**Session M0.3**: State store (A3) — can parallel with M0.2
- File tree read/write operations
- SQLite cross-plugin locks
- Journal append (append-only event log)
- Snapshot (hash the whole tree)
- **Exit criteria**: file r/w works; SQLite locks acquire/release; journal appends
- **Dependencies**: M0.1 (complete)
- **GitHub issue**: https://github.com/boundring/hngh/issues/3

## Blocked

Nothing blocked. Codeberg mirror pushed. GitHub project board configured (views need manual creation via web UI).

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support