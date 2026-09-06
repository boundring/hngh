<!-- plan: status=accepted risk=normal accepted=2026-09-06T01:01:30Z -->
# 2026-09-04 — notifications, QoL, and extended documentation

Authorization: operator-directed 2026-09-04, recorded faithfully in
docs/records/2026-09-04-operator-landscape-notes.md — (1) email
notifications are live and confirmed; make them maximally
functional/readable with section summaries, adversarially review
operator-facing surfaces, and give Hngh cyclical routines for regularly
optimizing notifications; (2) dashboard QoL: attention for QoL
features, operator-facing presentation, and interfaces for Hngh's
management of system-harness concerns (package updates, configuration
management); (3) logs QoL: operator-gated dismiss-able entries need
attention; logs simpler to understand at a glance while keeping
key/related info; (4) extended documentation: as complexity grows,
simply-communicated docs matter more; research a navigable "wiki" to
accompany the GitHub repo; (5) long-absence posture: the operator is
away for a LONG stretch and relies on email (+SMS?) notifications —
regular-cadence meaningful reports plus immediate notifications for
important-enough matters; SMS is not available yet, so the sanctioned
routes are email (live) and the browser-relay channel (Route A
prototype pending QR pairing — capabilities plan step 7). Normal-risk
autonomous work is pre-authorized; critical-class work parks with
operator-facing alerts.

Sources: docs/project/plans/README.md (the contract this file obeys);
docs/research/2026-09-04-operator-interface-landscape.md (the
interface-landscape record this plan implements — the direct answer to
the operator's interface question, the 1Password SDK answer, and the
SMS critical-class reasoning); docs/design/interface-grading.md (the
grade loop the notification surfaces should join); docs/design/
knowledge-base-spec.md + docs/research/2026-08-31-wiki-viewer-QoL-
comparison.md (the wiki precedent and the voided first attempt — the
new feasibility beat supersedes the void line); scripts/
generate-publication (the --site engine, read 2026-09-04); docs/
project/plans/2026-09-01-operator-items.plan.md (its 9 steps own
push-on-demand, the notification-channel survey step 2, the digest
wiring step 3, the cost model — none duplicated here); docs/project/
plans/2026-09-03-staging.plan.md (step 3 owns the stage-2/3 exit-
criteria sweep; step 6 owns the stage-4 governed-upgrade runbook this
plan's step 4 feeds); docs/project/plans/2026-09-03-capabilities.plan.md
(steps 6–7 own the browser-messaging admit gate and prototype; step 5
owns the credential seam — NOT duplicated); docs/project/reports.md
row 61f0a1e1 (email channel live 2026-09-04T21:30:15Z, credential
source file-fallback); the sibling notification slice (hngh-automation
scripts/email-digest.py — sections present on disk 2026-09-04; the
digest restructure + importance rubric + cadence/day/13-email-qa.sh QA
drop-in declared as landing TODAY — every step touching them is
verify-on-arrival).

Grounding notes (evidence over brief, checked 2026-09-04):
- scripts/email-digest.py exists with section-gather structure
  (## Commits — kernel, ## Plan progress, ## Operator items awaiting
  you, …) but NO TL;DR header and NO importance rubric as of
  2026-09-04 evening; cadence/day/13-email-qa.sh does NOT exist yet.
  Steps 1 and 3 are verify-on-arrival: if the sibling slice has not
  landed by execution time, record the exact gap and park, never
  duplicate its work.
- The digest channel is LIVE (reports.md 61f0a1e1), so "send one real
  digest" is a normal-risk verified send, not a dormant-mode probe.

Autonomy rule (standing): hngh docs changes land via certificate
ceremony with a green `make test`; hngh kernel src/, tests/, Makefile,
hngh.asd changes are FORBIDDEN to machine sessions — park them with an
alert row instead. hngh-automation script work lands as plain commits
gated by hngh-automation `make test`. Never touch provider or
credential configuration (an SMS gateway is exactly this — critical-
class park, see the landscape record §3), systemd unit lifecycle
beyond the allowlisted normal-risk verb, tracked deletions outside the
48h prune, or secrets. Machine-owned dirty paths (docs/journal/
current days, docs/project/reports.md, docs/project/ui-grades.md,
docs/design/ui-evolve/current-overlay.json, .omp/, untracked routed
plans and research docs, queue.md) are never ceremony candidates for a
plan step — the machine's own steps land those.

Paced-cadence contract: beats are bounded at ≤ ~60m wall each; strict
grow↔research alternation per master-plan §4 (a grow beat may not
follow a grow beat, a research beat never writes code); every step
names its own verification and is executable by a bounded delegated
session with no human present; blockers surface as lessons + tuning
first, then take priority over later work; this plan must not run
empty — the parked section names follow-on candidates and step 9
authors the next plan so the queue stays fed (foldback lesson 1).

## Steps

- [ ] 1. GROW — sibling digest restructure verified live. Confirm the
      sibling notification slice's digest restructure + importance
      rubric are on disk (scripts/email-digest.py TL;DR/section-
      summary structure, cadence/day/13-email-qa.sh). Then send ONE
      real digest to the operator over the live channel and confirm
      the received email shows a TL;DR/summary header, section
      summaries, and the importance rubric marking. If the sibling
      slice has not landed, record the exact gap and park this step's
      remainder as a verify-on-arrival note (never duplicate the
      sibling's work).
      Verification: a report row or breadcrumb naming the sent digest
      timestamp and each observed digest property (TL;DR present,
      sections summarized, rubric applied) — or the parked gap note
      naming the missing file; no second send; kernel `make test`
      green.
- [ ] 2. RESEARCH — adversarial operator-facing review of the email
      digest + dashboard System and Logs tabs (the operator's ask):
      read the latest sent digest and the System/Logs tab rendering,
      then review as a hostile reader: density, jargon, missing
      context, reading order, anything that requires memory of a prior
      digest to understand. Produce a findings table (surface ×
      finding × severity) and select the top-5 improvements as
      plan-step candidates for the next plan's author.
      Verification: docs/research/2026-09-04-adversarial-notification-review.md
      exists with the findings table, the quoted evidence per finding
      (digest sections, tab renderings), and the ranked top-5
      improvement list; kernel `make test` green.
- [ ] 3. GROW — digest improvement increment + QA dry-run. From step
      2's top-5, apply the digest-side improvements the automation
      repo's conventions support (smallest diff to
      scripts/email-digest.py or its cadence wrapper — e.g. the
      TL;DR polish, section-summary wording, rubric thresholds), and
      run the sibling QA drop-in cadence/day/13-email-qa.sh once
      (verify-on-arrival: if absent, record the gap and apply the
      digest-side change only). One improvement commit; one QA run;
      no repeated sends to the operator beyond step 1's.
      Verification: the hngh-automation commit hash for the digest
      change, the QA script's output recorded (or the absent-script
      gap note), hngh-automation `make test` green, kernel `make
      test` green.
- [ ] 4. RESEARCH — package-updates + config-management surfaces for
      the dashboard System tab. Map the governed lanes to a view: what
      an operator needs to SEE to approve and witness a governed
      upgrade — the package inventory feed (system-ops v1, landed),
      the certificate binding the exact package list, the fresh-
      evidence recheck moment, the supervision gate, and the rollback
      note; same for config-manager declared lanes (backlog row
      config-manager). Ground in the roadmap stage-4 row, backlog
      config-manager, and docs/project/plans/2026-09-03-staging.plan.md
      step 6's runbook (this step feeds it, does not duplicate it —
      the runbook owns the execution sequence; this step owns the
      dashboard VIEW of it). Design only; no package command is run.
      Verification: docs/research/2026-09-04-system-tab-governed-lanes-view.md
      exists with the System-tab view sketch (what each panel shows,
      its exact spine source) and an explicit no-package-command-run
      statement; kernel `make test` green.
- [ ] 5. GROW — dashboard Logs-tab QoL increment. FIRST ground in the
      dashboard code: identify which repo serves the Logs tab
      (hngh-automation dashboard/ — if the tab is automation-side,
      this step's implementation lands there; kernel-side stays
      design). Then design + implement the smallest dismiss-able
      operator-gated entries surface the automation repo supports:
      each log row shows one glance-readable line (what happened, when,
      severity per the importance rubric), with a dismiss action that
      records the dismissal in the report ledger rather than deleting
      evidence. Keep key/related info reachable (a collapsed detail
      line is enough).
      Verification: the implementation commit hash in the owning
      repo, a screenshot or rendered output of the Logs surface
      before/after, hngh-automation `make test` green, kernel `make
      test` green; if the tab turns out kernel-side, the design note
      is parked in the research doc and no kernel file is touched.
- [ ] 6. RESEARCH — navigable wiki feasibility. Ground in scripts/
      generate-publication (the --site static publisher — read its
      build_site and corpus): can it serve as the wiki engine for a
      navigable docs site accompanying the GitHub repo? Compare
      GitHub wiki vs an in-repo generated docs site (tradeoffs:
      discoverability, ceremony-gating of content, branch discipline,
      search) and what the knowledge-base precedent offers
      (knowledge-base-spec.md §2 viewer index, §3 flexibility rule,
      §4 publisher candidates MkDocs/Quartz/Wiki.js — the decision was
      deliberately deferred to the first real publication). Conclude
      with a priced recommendation: which engine, what it costs, what
      the first slice is. Note: the 2026-08-31 wiki-viewer-QoL line
      was voided on access grounds; this beat supersedes it with real
      grounding.
      Verification: docs/research/2026-09-04-navigable-wiki-feasibility.md
      exists with the engine comparison table, the priced
      recommendation, and the first-slice outline; kernel `make test`
      green.
- [ ] 7. GROW — long-absence notification posture increment. The
      operator is away for a LONG stretch: configure/verify the
      regular-cadence meaningful report (the digest already runs
      daily — verify the cadence day wrapper sends it to the live
      channel and that its operator-items section carries the pending
      decisions), and verify immediate alerts for important-enough
      matters ride the same live channel (the alert→notify path,
      evidence: reports.md alert rows). Design (do not implement)
      the browser-relay fallback trigger: when email fails N times,
      Route A becomes the notification route — cite capabilities step
      7 as the pending prototype. SMS stays parked critical-class
      (landscape record §3).
      Verification: a breadcrumb or report row recording the verified
      daily-digest cadence and alert path (with the live-send
      evidence), plus the written relay-fallback trigger rule; no new
      message channel is configured; kernel `make test` green.
- [ ] 8. RESEARCH — cyclical notification-optimization routine design.
      The operator asked for Hngh to have cyclical routines for
      regularly optimizing notifications: design the routine (cadence
      tier, what it inspects: digest open-readability per step 2's
      rubric, rubric threshold drift, alert volume/flap rate,
      dismissal stats once step 5's surface lands) and where it
      plugs into the grade loop (interface-grading.md — the digest
      and Logs surfaces as gradeable targets alongside
      dashboard-tui/dashboard-readout). Design only; the routine
      itself is a later slice.
      Verification: docs/research/2026-09-04-notification-optimization-routine.md
      exists with the cadence proposal, the inspection checklist, and
      the grade-loop admission sketch; kernel `make test` green.
- [ ] 9. GROW — wrap, lessons, author-next-plan (the plan-supply
      law). Land this plan's lessons into the foldback/lessons path,
      and author the next plan file (docs/project/plans/<date>-<slug>.plan.md,
      status=proposed) covering the parked follow-ons below plus the
      newest executed evidence, so the queue never runs empty (fold-
      back lesson 1). Fold in the operator's extended-documentation
      direction: if step 6 recommends an engine, the next plan's
      first slice builds the smallest navigable docs increment.
      Verification: the next plan file exists with contract-valid
      front-matter (first line `<!-- plan: status=proposed risk=normal
      accepted=- -->`) and every unchecked step carrying an indented
      Verification line; kernel `make test` green.

Parked (not in this plan, recorded for the operator; follow-on
candidates for the next plan's author):
- SMS gateway entirely — critical-class (provider/credential
  configuration); requires an operator-granted provider account stored
  via the credentials-posture seam. The landscape record §3 prices
  what "SMS yet?" requires.
- The Logs-tab dismissal surface if it turns out kernel-side — design
  parks until the kernel boundary allows machine sessions.
- GitHub-wiki publishing (if step 6 recommends it) — first
  publication is deliberately deferred per knowledge-base-spec §4;
  the recommendation prices the decision, the operator grants the
  publish target.
- The 1Password vault migration (unsloth token-pair + SMTP
  credential) — back-burnered with the capabilities plan's parked
  candidates; blocked on the desktop-app integration answer recorded
  in the landscape research (reboot-window test first).
