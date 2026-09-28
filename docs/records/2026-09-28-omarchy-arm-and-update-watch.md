# 2026-09-28 — omarchy arm fix, distro update-watch, ISO scaffold

## Wicket arm fix (sudoers placeholder trap)

Phase-1 desk flow was blocked: the operator ran the pinned bootstrap
block verbatim, but `sudo -n -l -U bricker` still showed no wicket
grants and `automation/lib/privileged.sh wicket version` exited 3
(`wicket not armed:`).

Root cause: `automation/config/wicket.sudoers.example` granted a
placeholder user `hngh` (comment said "rename to the user the
automation tier runs as"), while the pinned bootstrap blocks
(privileged.sh `_pv_bootstrap_block`, dashboard-server.py
`DESK_BOOTSTRAP_PINNED`) install the example **verbatim** — no rename
step anywhere in the printed flow. Verbatim run arms nothing: the
drop-in grants a ghost user, the real operator's `sudo -l` never shows
wicket lines. Design trap, not operator error.

Fix: grants retargeted to `%wheel` (the operator group) — works
verbatim on this desktop, laptop deploy inherits it, no per-machine
rename step. Command scope unchanged (three exact
`/usr/local/lib/hngh/wicket.sh <action>` grants, no NOPASSWD:ALL).
`DESK_BOOTSTRAP_PINNED` trailing comment synced ("# grants %wheel").
test-wicket.sh template law green; full `make test` green (2954 checks,
rc 0) with the change in tree.

Operator state at record time: dispatcher + root manifest installed
(root-owned, verified), omarchy signing key
`40DFB630FF42BCFFB047046CF0134EE680CAC571` imported to the pacman
keyring; pending operator commands: re-run of the dispatcher+manifest
installs (root copies predate the deferral fix) and the sudoers
drop-in install. The `[omarchy]` repo append is deliberately deferred
to phase 2 (provider-configuration change on the certificate lane);
see the deferral section below. (Machine precedent for user-scoped
grants — the hngh-automation ufw grant — is operator-configured outside
the repo; the repo template needed the portable form.)

## Desk approval-chain fix (colon id vs SESSION_RE)

The phase-1 human gate was dead-on-arrival: run-phase-1 requires
`desk-authz:phase-1` in dashboard/operator-approved.json, but the only
verb that writes that ledger (`/operator-item/handle`) rejects colon
ids (SESSION_RE `^[A-Za-z0-9._-]{1,80}$`), so the desk Handle click
could never land the approval and run-phase-1 409'd forever. The
lifecycle suite masked the break: its approve() helper wrote the
ledger file directly, bypassing the verb. Renamed colon-free to
`desk-authz-phase-1` everywhere (constant, stage-authz identity/alert
text, gate check, desk-view.js/desk.html, test literals); regression
test `test_approval_via_handle_verb_gates_run_phase1` drives the real
chain (stage-authz → handle verb → gate past the approval 409).
Live flow re-staged under the new identity after this fix.

Phase-1 outcome (2026-09-28 ~20:10Z): operator approved in-channel;
the handle verb was POSTed with the literal id and run-phase-1
returned rc 0 — one `pacman -Sy --needed --noconfirm` transaction
landed the 18 CachyOS/extra packages (verified: hyprland 0.56.2-3.1,
uwsm, quickshell, foot, both portals, hyprland-guiutils, hyprpicker,
hyprsunset, grim, slurp, cliphist, wl-clipboard, wireplumber, pamixer,
brightnessctl); the omarchy-repo trio is correctly absent. Wayland
sessions now carry hyprland.desktop + hyprland-uwsm.desktop next to
plasma.desktop — Plasma remains the default session.

Known follow-up (surface, not gate): the newspaper feed's Handle
button posts the row's text-hash id, so it can never write the literal
`desk-authz-phase-1` key — the approval went through a direct verb
POST on the operator's in-channel consent. Proper fix when picked up:
a dedicated `POST /desk/approve` (token-gated, owed report row first,
atomic approved[DESK_AUTHZ_ID] write, mirroring `_handle`'s
fail-closed order) plus an Approve button in desk-view.js gated on
`!approved` and the same real-chain test. LANDED 2026-09-28 in
f6dc44b2 (verb, button, real-chain tests) — historical; the
feed-absence half stays open. The feed item was also absent from
operator-items.json (feed reads crumbs + digest bullets, not
report-queue rows; rebuild is a subhour beat) — same pickup.

## Omarchy-repo deferral in the dispatcher

The three `# omarchy-repo` manifest lines (hyprland-preview-share-
picker, owe, owe-lockfeed) previously entered wicket's single
`pacman -Sy --needed --noconfirm` transaction — which pacman refuses
WHOLE on "target not found" until the repo is configured, so phase 1
could never complete as landed. `_wicket_parse` now skips and counts
`# omarchy-repo` tails exactly like `# aur`; the empty-transaction rc 4
message reports both counts. The trio rides phase 2: repo-add first
(certificate lane), then the packages become installable.

Two adjacent defects fixed in the same slice: (1) the skip counts were
set inside a `$(...)` subshell and NEVER propagated — "aur skipped: N"
always printed 0; the parse loop is now inlined into
`_wicket_install_base` with counts surviving in the caller's shell.
(2) `desk_bootstrap_block()` rendered the whole 58-line example file
(the unreadable desk block the operator complained about) and fell
back to a DESK_BOOTSTRAP_PINNED constant that had drifted from
privileged.sh (manifest installed to /etc/hngh 0644 instead of
/usr/local/lib/hngh 0444 — would make wicket rc 4 fail-closed). The
pinned constant is now verbatim-aligned with the privileged.sh
`_pv_bootstrap_block` heredoc (the source of truth) and
`desk_bootstrap_block()` returns it unconditionally; the vestigial
WICKET_SUDOERS_EXAMPLE constant and its lifecycle-suite override are
deleted. Red→green: test-wicket.sh gained the omarchy-only and
mixed-manifest cases (5 failures before the fix → PASS, 46 ok);
lifecycle suite 79 OK; test-distro-update-watch.sh wired into
automation/Makefile:192 (had been missed).

## Weekly distro update-watch

`automation/cadence/calendar/weekly/31-distro-update-watch.sh` —
archlinux.org news feed, CachyOS + omarchy latest GitHub releases;
7-day last-seen dedup under `$HNGH_HOME_DIR/db/distro-watch/`;
per-source URL env overrides (`HNGH_DISTRO_{ARCH,CACHYOS,OMARCHY}_URL`);
NEW_CAP 5 rows; first sighting arms state only (sibling
28-omp-changelog-watch convention). Hermetic test (27 checks, stubbed
curl). Registered in `automation/cadence/README.md` weekly list.

## Live-ISO scaffold

`automation/iso/profile/` (mkarchiso releng shape, CachyOS kernel +
znver4 repos, `[omarchy]` repo last, omarchy session core mirroring
`config/omarchy-base.packages`, avoid-list intact) +
`automation/iso/build-live-iso.sh` wrapper (seams MKARCHISO_BIN /
ISO_PROFILE_DIR / ISO_WORKDIR / ISO_OUTDIR, artifacts under
`~/.hngh/db/iso`, never escalates). `automation/tests/test-iso-build.sh`
(11 checks, mkarchiso stub). Wired into automation/Makefile (bash -n
sweep + test target). archiso NOT yet installed on the host — building
a real artifact still needs `pacman -S archiso` (operator command).

## Jevify verdict (phase-1 manifest vs this desktop)

Deterministic pre-pass (pacman -Q + pacman -Si): 4 of 25 already
installed, 18 available from CachyOS znver4/extra repos, 3 only in
`[omarchy]` (hyprland-preview-share-picker, owe, owe-lockfeed). Judge
pass over 17 units: all additive (zero Conflicts/Replaces against the
installed Plasma stack), session_risk ≤ 0.54. Phase-1 set does not
touch the boot chain; Plasma X11 remains the default session.
