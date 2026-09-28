# 2026-09-27 — omarchy-readiness beat

Daily calendar-tier beat `automation/cadence/calendar/daily/31-omarchy-readiness.sh`
gives the future dashboard installation desk (and the operator) one
identity-deduped progress row per day (`omarchy-readiness:<UTC-date>`,
7d window) describing omarchy-on-CachyOS phase-1 readiness:

- `a` — upstream clone present (`$OMARCHY_UPSTREAM_DIR`, default
  `~/Projects/etc/omarchy-upstream`, needs `.git`)
- `b(n)` — `automation/config/omarchy-base.packages` non-empty; n =
  uncommented lines
- `c` — `pacman -Q hyprland` exits 0
- `d` — session desktop staged in `$OMARCHY_SESSIONS_DIR` (default
  `/usr/share/wayland-sessions`): `hyprland-omarchy.desktop` or
  `hyprland.desktop`
- `e` — `automation/jobs/pins-drift.py --json` says ok:true (`ok`) /
  ok:false (`drift`); module missing or any error → `unknown`
  (never coerced to false)

Alert channel: exactly one condition — `c=yes d=no` files
`omarchy-ready:phase1-pending` (7d window) naming the missing session
file ("packages in, session not staged"). The beat reports, never acts.

Test: `automation/tests/test-omarchy-readiness.sh` — hermetic sandbox
(stub pacman, stub pins-drift, fixture clone/manifest/desktop per
case), 17 checks covering all-yes, each boolean flipping, both alert
polarity cases, same-day identity dedupe, and comment-only manifests.
Registered in `automation/Makefile` after `test-arc-to-slice.sh`.
