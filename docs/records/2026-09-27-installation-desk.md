# 2026-09-27 -- installation desk: the operator's fail-closed phase-1 surface

Design + implementation record for the Installation Desk in the hngh
automation dashboard (dashboard/desk.html, served at 127.0.0.1:8890):
the page from which the operator advances Omarchy-on-CachyOS phase 1
(session stack install) through explicit authorization steps. It
consumes the wicket seam (docs/records/2026-09-27-wicket-privileged-
channel.md) and the pins-drift comparator
(docs/records/2026-09-27-pins-drift-checker.md) and creates nothing
privileged of its own. Files: automation/dashboard-server.py (state +
verb endpoints), automation/dashboard/desk.html / desk-view.js /
desk.css (newspaper UI, broadsheet.css shared idiom),
automation/tests/test-dashboard-lifecycle.py (class Desk, 13 cases).

## 1. Routes

GET:

- `/desk.html` — the page (added to both serve tuples, like
  console.html / broadsheet.html).
- `/desk-state.json` — live state assembly, cached ~30s
  (TELEMETRY_TTL_S) with the research-routes fail-soft pattern (last
  good payload served on probe failure; cold-start failure raises 500).

POST (token-gated by the existing dispatch):

- `/desk/stage-authz` — body `{phase:"1"}`, 400 on anything else.
- `/desk/run-phase-1` — no body needed.

## 2. The desk-state contract

One JSON document, everything the UI needs to render the gate
honestly; every probe is read-only and routes through one
monkeypatchable seam (`_run_ro`, single subprocess runner):

    clone:      {present, ref}            # OMARCHY_UPSTREAM_DIR env,
                                          # default ~/Projects/etc/
                                          # omarchy-upstream; .git isdir
                                          # + `git -C rev-parse --short HEAD`
    manifest:   {present, count, aur_count,
                 pkgs:[{name, installed}]} # config/omarchy-base.packages
                                           # (`name # aur` marks AUR);
                                           # installed = pacman -Q rc
    wicket:     {armed, reason}           # `sudo -n -l -U <user>` output
                                          # contains
                                          # "wicket.sh install-base";
                                          # any failure -> armed:false +
                                          # first output line as reason
    drift:      {ok, count} | null        # jobs/pins-drift.py --json
                                          # passthrough; absent file or
                                          # nonzero rc -> null
    approvals:  {"desk-authz:phase-1": bool}  # operator-approved.json
    phase1_ready: bool                    # non-aur manifest non-empty
                                          # AND every non-aur pkg
                                          # installed
    generated:  ISO-8601 UTC stamp

`phase1_ready` is derived display state, NOT a run gate — the gate
chain below is the only thing that can start phase 1.

## 3. POST /desk/stage-authz

Files the operator authorization request as ONE operator item, using
the exact creation channel the operator verbs already use: a
report-queue `alert` row with identity `desk-authz:phase-1` and the
7-day window (604800s) that operator-item.sh dedupes on. The row text
IS the remediation: the wicket bootstrap block, quoted verbatim from
config/wicket.sudoers.example when present (else the pinned block in
dashboard-server.py), followed by the approve-this-item instruction.
A handoffs line records the filing. Idempotent within the window
(report-queue dedupe marks a repeat with an xN suffix). 201
`{ok:true, identity}`; 400 on any phase other than "1"; 500 if
report-queue refuses the row (fail closed — the handoffs line is
written only after the row lands).

## 4. POST /desk/run-phase-1 — the fail-closed order

Validations run in THIS order; each failure is 409
`{ok:false, error, remediation}` where remediation is printed
verbatim by the UI:

1. desk-authz:phase-1 is in the approved ledger (dashboard/
   operator-approved.json, the same reader the operator verbs use).
   Remediation: "Stage authorization, then approve the
   desk-authz:phase-1 item".
2. The wicket is armed (same probe as desk-state). Remediation: the
   bootstrap block, verbatim.
3. The upstream clone (.git present) AND the manifest file exist.
   Remediation names the missing path (clone remediation mentions
   OMARCHY_UPSTREAM_DIR as the override).

Only then: `bash automation/lib/privileged.sh wicket install-base`
(PRIVILEGED_SH module constant, 900s timeout), output tail = last
~40 lines of combined stdout+stderr. 201 `{ok, rc:0, tail}` on
success; rc != 0 -> 502 `{ok:false, rc, tail}`; timeout/exec failure
-> rc:null with 502. A handoffs line records the attempt either way.
The server never inspects install output beyond the tail and never
retries: one operator click is one privileged attempt.

## 5. The page

Newspaper idiom on the shared broadsheet stylesheet: masthead
"THE INSTALLATION DESK" with dateline (state stamp + phase1_ready
syn badge), five live state cards (clone / manifest / wicket / drift
/ authorization) fed by the 30s poll chain, a phase table (phase 1
actionable; phases 2 config adopt, 3 bins, 4 look port rendered as
honest scheduled rows "requires phase 1 landed" — never clickable),
and the operator-verb button idiom: each button prints its outcome
line before it is clicked. "Stage authorization" shows the filed
identity; "Run phase 1" renders rc + tail, and a 409 prints the
remediation block verbatim in a double-rule box. Buttons disable
with a reason line whenever their precondition is unmet — the gate
is visible, not hidden. Ghost links from the broadsheet and console
toolbars. Single column below 720px.

## 6. Tests

automation/tests/test-dashboard-lifecycle.py, class Desk (the
privileged channel is a stub script that logs its argv; pacman/git/
sudo probes are a faked _run_ro; no test installs a package or runs
sudo for real): desk page + token meta; desk-state shape +
fail-closed defaults; installed-mapping + phase1_ready; 30s cache;
drift passthrough; stage-authz 201 (row + handoff) / 400 wrong
phase / 500 report-queue refusal fail-closed; run-phase-1 409
unapproved (exact remediation) / 409 armed-missing (bootstrap
remediation) / 409 missing clone / 409 missing manifest / 201 happy
path (stub argv + handoff) / 502 on stub rc 2; 403 without token on
both POSTs. Full suite 46 green.
