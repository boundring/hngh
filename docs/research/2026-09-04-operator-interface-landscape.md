# Operator interface landscape — the primary interface, and every option on the table

Status: RECORD/RESEARCH — answers the operator's direct question
(2026-09-04): *"What does the roadmap currently plan as Hngh's PRIMARY
operator interface, and are multiple interaction options included?"*

Evidence cited per claim; admits no runtime capability. Where the
roadmap does not establish something, that is said plainly ("not
established"). All observations checked 2026-09-04.

## 1. The direct answer

**The PRIMARY operator interface is the nerve center webapp** — roadmap
stage 2 ("One interface", state: **landing**,
[project/roadmap.md](../project/roadmap.md) stage table): formal tabs
with **Schedule as the default tab**, then Sessions, System, Research,
Logs; the session transcript observatory; a unified schedule over the
system backdrop; window tiling + spawn; and the operator-item lifecycle
(open → handled → dismissed). Stage 2's exit criteria gate it: every
tab renders at desktop + mobile widths, cold deep-links mount, and
operator items flow open→handled→dismissed.

The webapp is not a lone surface — it is the GUI face of the **command
center family**: one presentation spine with a CLI beside it
([design/command-center.md](../design/command-center.md) S1–S8; both
documents' shared terminology note: "nerve center" names the webapp,
"command center" the CLI+GUI family it belongs to). **Multiple
interaction options are explicitly part of the plan** — the full list
is in §3.

Honest framing: stage 2 is *landing*, not *landed* — the 2026-09-03
staging plan (step 3) owns the tab-by-tab exit-criteria verification
sweep that will let the roadmap table flip states on evidence. Until
that sweep runs, "landing" is the roadmap's own word, and the per-tab
status is **not established** here beyond what the roadmap table
states.

## 2. Why the webapp is primary (evidence)

- The roadmap stage table (project/roadmap.md, stage 2 "One
  interface") names the nerve center and its five formal tabs as the
  stage whose consolidation is the current frontier; the roadmap's
  working order item 1 is "Land stage 2 (nerve-center consolidation is
  in final verification)".
- The interface plan ([project/interface-plan.md](../project/interface-plan.md))
  is the needs-first *contract* for exactly this surface: ranked
  operator needs, an awareness contract sourcing every readout from the
  existing spine (`system.json`, `data.json`, `readout.json`, the
  report ledger), and a control contract where every GUI button routes
  through the same command underneath as the CLI verb — "there is no
  second core: the command center is presentation plus dispatch over
  the kernel, nothing more" (command-center.md Vision).
- The single-verdict rule (interface-plan §2, M1/7): the dashboard
  shows ONE health line first, then numbers — counts are secondary,
  never the headline. Freshness stamping (`stale (Nm)`) applies to
  every at-a-glance readout.
- Stage 6 then grows the same surface graphically (QoL & graphic
  evolution: widget grid, uPlot charts, themes) — the webapp is the
  substrate that QoL evolves, not a surface to be replaced.

## 3. The full option list — every surface, its stage, its gate

### Command center family (CLI + GUI over one spine)

| Surface | Roadmap stage | Gate / exit criteria | State |
|---|---|---|---|
| Nerve center webapp (tabs Schedule/Sessions/System/Research/Logs; observatory; tiling; operator-item lifecycle) | **2 — landing** | every tab renders desktop+mobile; cold deep-links mount; operator items flow open→handled→dismissed | contract set (command-center.md S1–S8), landing |
| CLI verbs (`scripts/hngh`) | **0 — done** | `make test` green; certificate-bound commits | 19 verbs live (usage block in `src/main.lisp` `command-usage`: create-run, admit-transport, arm-run, start-run, checkpoint, close-run, propose, issue-cert, mutation-check, present, review, terminal, fetch-evidence, verify-attestation, list-pins, wake-peer, run-worker, select-course, status) |
| Command-center S-slices S1–S5 (truth-telling dashboard, System panel, `status` verb, live roster, summon) | P3 DEV riding stage 2 | command-center.md control/awareness contracts; each slice a small commit against an existing rung | design contract; per-slice state not established |
| S6–S8 (consider/expedite/ripple, pause+label, Hngh-as-app OMP bridge + hosted interface) | P4 DEV | S8 is the only slice where a daemon may be justified (on-demand session host) | design contract |

### Secondary faces (operative layer)

| Surface | Roadmap stage | Gate | State |
|---|---|---|---|
| dashboard-tui (terminal panels) | stage 2 family | the grade loop: `scripts/grade-interface` screenshots + local vision rubric → `docs/project/ui-grades.md` ledger | graded surface today (interface-grading.md: targets `dashboard-tui` / `dashboard-readout`) |
| dashboard-readout watch mode (operative above the readout) | stage 2 family | same grade loop | live (assistant-interface.md "Current state") |
| OSD operative (Plasma 6 overlay, qml6 standalone window) | stage 6 (QoL & graphic evolution) | one graded QoL change per cycle, revertible, before/after evidence (stage-6 exit criterion) | researched design (assistant-interface.md) |
| Pixel-RPG buddy (summoned, non-nagging overlay menu) | stage 2/6 family | buddy-menu-spec; display register law | design spec ([design/buddy-menu-spec.md](../design/buddy-menu-spec.md)) |
| Voice (piper/kokoro TTS, whisper STT) | later QoL | "speech is a surface, never a gate" (assistant-interface.md) | direction recorded |

### New async channels (the operator-away surfaces, 2026-09-04)

| Channel | Belongs to | Gate / exit criteria | State 2026-09-04 |
|---|---|---|---|
| **Email** (daily digest + immediate alerts via notify-email) | stage 1 self-watch → feeds the operator-item lifecycle | reports.md rows are the evidence surface | **LIVE and operator-confirmed** (reports.md row 61f0a1e1, 2026-09-04T21:30:15Z: "email channel live; credential source: file-fallback (1Password locked — op signin pending, migration deferred)"); digest restructure + importance rubric landing via sibling automation slice (verify-on-arrival — see plan Deliverable 2 step 1) |
| **Browser-relay** (Route A prototype: Google Messages web via Playwright persistent context; omp browser-relay architecture studied in docs/research/2026-09-04-browser-relay-architecture.md) | capabilities plan step 7 (browser-messaging prototype) | step 6 ADMIT verdict landed 2026-09-04 (playwright 1.62.0 + chromium 151 smoke-launched); step 7 gates the first send | **pending QR pairing** — if messages web demands pairing, step 7 parks with the pairing step quoted as the one human step |
| **SMS** | not on the roadmap as a channel | — | **Not available — by design, not by omission.** An SMS gateway means provider/credential configuration (a paid provider account, API keys, phone-number verification): that is critical-class park under the plans contract, exactly like any provider/credential configuration. The same operator reach (phone-number notification) is achieved procedurally by the browser-relay route (GMessages web over the paired relay) with zero new credentials. What "SMS yet?" would require: an operator-granted provider account + credential storage via the credentials-posture seam, then a normal-risk slice. Not established until the operator grants the provider. |

### The 1Password desktop-app ↔ SDK question (recorded answer)

Operator question: *can the SDK interface with the desktop app if the
CLI can't?* **Answer: NO.** On Linux, the 1Password SDKs (JS/Go/Rust/
Python) and the CLI share the same desktop-app integration plumbing —
the same local socket to the desktop app — so an SDK integration
inherits the CLI's failure mode, it does not bypass it. The documented
bypasses that skip the desktop app are: CLI-only `op account add`
(sign-in without desktop-app integration), or a 1Password Service
Account if the plan tier allows one. This is why the email channel
went live via the file-fallback credential path (reports.md row
61f0a1e1) rather than waiting on the app integration. Recorded leads
for later: a stale `op-daemon.sock` from 13:25 (pid 4035) — a restart
after the operator's pending reboot window is the cheap first test;
the vault migration remains an upgrade path, not a dependency. The
1Password troubleshooting itself is **back-burnered** (operator
decision 2026-09-04, recorded in
[records/2026-09-04-operator-landscape-notes.md](../records/2026-09-04-operator-landscape-notes.md)).

## 4. Where notification QoL plugs in

- The grade loop ([design/interface-grading.md](../design/interface-grading.md))
  currently grades `dashboard-tui` / `dashboard-readout` screenshots
  into the ui-grades.md ledger. The notification surfaces — the email
  digest, alert formatting, and the Logs-tab dismissal surface — are
  the natural next entries: each is a renderable operator-facing
  surface that can be captured, critiqued against the rubric, and
  ledgered. That admission is staged as plan
  [2026-09-04-notifications-and-qol.plan.md](../project/plans/2026-09-04-notifications-and-qol.plan.md)
  (adversarial review step, then the digest QA cycle using the sibling
  `13-email-qa.sh` drop-in once it lands).
- The operator-item lifecycle (open→handled→dismissed) is stage 2's
  exit criterion for dismiss-able entries; the Logs-tab QoL increment
  is where dismissal becomes visible per-entry.
- Stage 4's governed upgrade lanes (package inventory →
  certificate-gated upgrades, config-manager declared lanes) surface
  in the System tab; the "what an operator needs to see to
  approve/witness a governed upgrade" mapping is staged as a research
  step in the same plan (feeding staging plan step 6's runbook).

## 5. Not established (honest framing)

- Per-tab live status of the five nerve-center tabs beyond the
  roadmap's "landing" state — the 2026-09-03-staging plan step 3 sweep
  owns that evidence; it has not run yet.
- Whether S1–S8 slices are individually landed — the command-center
  contract is ceremony-ready design; per-slice state is not
  established in kernel docs.
- Any end-to-end browser-relay send — not established (no real message
  sent; capabilities step 7 pending QR pairing).
- SMS entirely — not established, and deliberately parked
  critical-class.

## Sources

- docs/project/roadmap.md (stage table, working order, design-pressure
  paragraph)
- docs/design/command-center.md (S1–S8, control/awareness contracts,
  terminology note)
- docs/project/interface-plan.md (needs-first contract, single-verdict
  rule)
- docs/design/assistant-interface.md, docs/design/buddy-menu-spec.md,
  docs/design/operative-frames.md (secondary faces)
- docs/design/interface-grading.md (grade loop, ledger)
- docs/design/presentation-boundary.md (renderer limits)
- docs/design/knowledge-base-spec.md (vault canon, viewer, publishers)
- docs/project/plans/2026-09-03-capabilities.plan.md (steps 6–7:
  browser probe + prototype; step 5: credential seam)
- docs/project/plans/2026-09-03-staging.plan.md (step 3 sweep, step 6
  runbook)
- docs/research/2026-09-04-browser-relay-architecture.md (relay
  mechanism, Route A state)
- docs/project/reports.md row 61f0a1e1 (email live, credential source)
- `src/main.lisp` `command-usage` (the 19 verbs, read 2026-09-04)
- scripts/generate-publication (the `--site` static publisher — the
  wiki-feasibility input, priced in the plan)