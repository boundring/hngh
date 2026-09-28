# 2026-09-28 -- desk: wiring the AUR add-ons lane into the installation desk

Implementation record for POST /desk/run-aur, the desk's third gated
action: the manifest's aur-marked lines (hyprland-preview-share-picker,
owe, owe-lockfeed) become one Run button each on desk.html, driving
jobs/aur-build.sh through the dashboard server. Files:
automation/dashboard-server.py (AUR_BUILD_SH, AUR_PKGS, the endpoint),
automation/dashboard/desk.html + desk-view.js (AUR add-ons section),
automation/tests/test-dashboard-lifecycle.py (DeskAur cases).

## 1. Why a lane at all

aur-build.sh (2026-09-28, wicket slice) already automates the user-
session AUR build: RPC lookup, repo-dep gate, verified-origin clone,
makepkg --noconfirm, stage via privileged.sh wicket stage, and prints
the exact operator follow-up (`wicket install-file <name>`). What was
missing was the sanctioned trigger surface: the operator should not
shell in to build; the desk is where phase state lives, so the lane
hangs off the desk behind the SAME phase-1 gates as install-base.

## 2. The gate chain (fail closed, in order)

Validations mirror run-phase-1 exactly wherever the stakes match:

- 400: body not a JSON object, or pkg not a non-empty string.
- 400 {"error": "unknown aur package", "known": [...]}: off-manifest
  names are refused BEFORE any gate probing — AUR_PKGS is parsed once
  at import (partition('#') rule shared with _desk_probe_manifest;
  OMARCHY_MANIFEST overrides the source manifest). An unreadable
  manifest parses to the empty set: the lane refuses everything.
- 409 "phase 1 not authorized" + 409 "wicket not armed": identical
  wording/remediation to run-phase-1 — the AUR lane deliberately does
  not open before the session stack's gate does (the staging half of a
  build lands in the wicket's staging dir, so an unarmed wicket makes
  the lane useless anyway).
- 409 "an aur build is already running": module flag, one build at a
  time (check-then-set is fine: the desk serves one operator).
- Then `bash jobs/aur-build.sh <pkg>`, timeout 900s, output tail (last
  ~40 lines) — the same run-and-tail pattern as run-phase-1. 201
  returns {"ok": true, "pkg", "tail", "follow_up"} where follow_up is
  the printed `wicket install-file` line verbatim (null when absent);
  rc != 0 / exec failure / timeout -> 502 {"ok": false, "rc", "tail"}.

## 3. What this lane does NOT do

- NEVER root, NEVER pacman install: the job is user-session makepkg;
  the only privileged step is the wicket stage inside the job.
- No install: the follow-up command is printed for the operator, not
  executed. The desk renders it verbatim.
- No handoffs line: unlike run-phase-1 nothing durable lands beyond the
  wicket's own audit log and the staging dir; the response carries the
  evidence.

## 4. Desk surface

desk-state.json gains "aur" {"pkgs": sorted names, "running": bool}
inside the existing 30s fail-soft cache. desk.html adds the AUR
add-ons block under the phase ledger; desk-view.js builds one
choice-row per package (broadsheet esc()/textContent law), disables
all rows with a printed reason while unauthorized / unarmed / in
flight (the server's chain, mirrored client-side), and renders 201
tail + follow-up, 409 error + remediation, 502 rc + tail into the
existing remediation block. Rows rebuild only when the pkg set
changes, so in-flight outcome text survives the poll chain.

## 5. Tests (hermetic — no network, no pacman, no sudo, no root)

DeskAur(Lifecycle) in automation/tests/test-dashboard-lifecycle.py:
the job is a stub script logging argv and printing canned staged +
follow-up lines (HNGH_STUB_AUR_LOG / HNGH_STUB_AUR_RC seams). Cases:
token 403; bad body 400; unknown-pkg 400 with the known list asserted;
unapproved 409; unarmed 409; 201 happy path with follow_up extraction;
rc-4 502; in-flight 409; desk-state aur key; the parser against the
real omarchy-base.packages (exactly the three aur names, comment
section excluded); the OMARCHY_MANIFEST override (subprocess import);
and a regression case pinning stage-authz + run-phase-1 behavior
alongside the new overrides.
