# Next — Current Work

**Last updated**: 2026-06-22

## Current Session

**Sessions M0.2 + M0.3**: Event bus + State store — **complete**

## Up Next

**Session M0.4**: Plugin host (A1)
- CL plugin loading, manifest parsing, package-level isolation
- One test plugin (first-party tier)
- **Exit criteria**: load/unload CL plugin; package isolation works; hot-reload works
- **Dependencies**: M0.2 (Event Bus), M0.3 (State Store) — both complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/4

**Session M0.5**: Supervisor (A6) — can parallel with M0.4
- Restart policies, health checks, component registration
- **Exit criteria**: register component; restart on failure; escalate after N failures
- **Dependencies**: M0.2 (Event Bus) — complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/5

**Session M0.6**: Scheduler (A5) — can parallel with M0.4
- Timers, basic scheduling, cancel/list
- **Exit criteria**: schedule timer fires event; cancel works
- **Dependencies**: M0.2 (Event Bus) — complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/6

## Blocked

Nothing blocked. Codeberg mirror pushed. GitHub project board configured (views need manual creation via web UI).

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support