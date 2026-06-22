# Next — Current Work

**Last updated**: 2026-06-22

## Current Session

**Sessions M0.4 + M0.5 + M0.6**: Plugin host + Supervisor + Scheduler — **complete**

## Up Next

**Session M0.7**: dbus bridge (B13)
- systemd session bus subscription, basic event translation
- **Exit criteria**: systemd signals appear on internal bus
- **Dependencies**: M0.4 (Plugin Host) — complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/7

**Session M0.8**: Dashboard TUI (B9) — can parallel with M0.7
- Minimal TUI: status display, event feed, basic navigation
- **Exit criteria**: TUI starts, shows status, live event feed
- **Dependencies**: M0.4 (Plugin Host) — complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/8

**Session M0.9**: System daemon (C1) — can parallel with M0.7/M0.8
- C skeleton, dbus method (InstallPackages), systemd units
- **Exit criteria**: daemon starts as root, installs packages via dbus
- **Dependencies**: Session 0B (build system) — complete
- **GitHub issue**: https://github.com/boundring/hngh/issues/9

## Blocked

Nothing blocked. Codeberg mirror pushed. GitHub project board configured (views need manual creation via web UI).

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support