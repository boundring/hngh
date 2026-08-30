<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-08-30 — evening selfdev

Autonomous evening wave while the operator is away. Operator
authorization: operator away 2026-08-30 ~19:30Z–late evening UTC,
pre-authorized autonomous normal-risk development in this session;
critical-class work parks with operator-facing alerts.

Sources: docs/records/2026-08-30-lessons-and-foldback.md (lessons 1–4,
fold-back edits, the two hallucinated research lines as the named
anti-pattern), docs/project/roadmap.md Next working order 1–5 and the
stage table (stages 2/3 landing, 4/5 queued), backlog rows night-agent
plan authoring + alert→plan-candidate routing + documentation-sync +
ebook-longform/public-surface/royalty-pipeline/funding-rails + node-lattice
+ device-fleet + config-manager, docs/project/master-plan.md §4
(alt=ernation rule and research backlog), docs/project/roguelike-agentic.md
(death-and-replacement, handoff briefs, steer-vs-die),
docs/project/reports.md (live alert classes),
docs/project/operating-precepts.md, docs/project/queue.md rotation state,
docs/research/2026-08-30-delegation-lane-parallelism-*,
docs/research/2026-08-30-ceremony-cost-reduction-*,
docs/research/2026-08-30-alert-to-work-routing-*, and the operator's
explainer suite ~/Projects/etc/20260830 (00-introduction.md…09-runbook.md
+ README/CHANGELOG; audited via 2026-08-30-lessons-and-foldback —
operator-authored framing material only; its day-set numbers and
unverified mechanics are deliberately NOT imported into repo docs).

Autonomy rule (standing, from the 2026-08-28 evening-selfdev plan):
hngh docs changes land via certificate ceremony with a green `make test`;
hngh kernel src/, tests/, Makefile, hngh.asd changes are FORBIDDEN to
machine sessions — park them with an alert row instead. hngh-automation
script work lands as plain commits gated by hngh-automation `make test`.
Never touch provider or credential configuration, systemd unit lifecycle
beyond an already-installed unit, tracked deletions outside the 48h
prune, or secrets.

Paced-cadence contract: beats are bounded at ≤ ~60m wall each; strict
grow↔research alternation per master-plan §4 (a grow beat may not
follow a grow beat, a research beat never writes code); this plan must
not run empty — the parked section names follow-on candidates so the
plan queue stays fed (foldback lesson 1). Every step names its own
verification and is executable by a bounded delegated session with no
human present.

Grounding corrections already applied to this plan (evidence over
brief): the self-supervision tick does not exist as code (only named in
roadmap stage 3 / backlog rows), so the seeded-stall flag check parks.
`scripts/omp-bridge` supports `--orient/--register/--note/--task/--ceremony`,
`--run-start SESSION OBJECTIVE`, and `--run-end RUN DISPOSITION`; from
`:created` the only legal close is `cancelled` (the kernel refuses
illegal transitions by design, proven live 2026-08-27) — the first live
wrapped delegation is scoped to exactly that surface.

Parked (not in this plan, recorded for the operator; follow-on
candidates for the next plan's author):
- Kernel-side config-manager/stage-4 work, self-supervision tick
  (kernel src/tests/Makefile/hngh.asd), DelegationQueue sharpening in
  bridge internals that needs kernel contracts — forbidden by the
  autonomy rule. Parks with alert rows when a beat reaches for them.
- OpenRouter remote GLM budget leg (token file is operator-only).
  Operator-critical. Parks.
- Any critical-class work (provider/credential config, systemd
  lifecycle beyond an installed unit, non-prune deletions, security
  posture). Parks.

## Steps

- [x] 1. Gate baseline — RUN BY THE AUTHOR at authoring time
      (2026-08-30 evening): `make test` green, 2,855 checks, wall
      ~34 s, exit 0; hngh-automation `make test` exit 0. Recorded here
      and in the RECORD. Tree note from the doc-sweep relay: the live
      autonomous loop's own writes (docs/journal/2026-08-30.md,
      docs/project/reports.md, docs/project/ui-grades.md,
      docs/design/ui-evolve/current-overlay.json) are machine-
      maintained append paths — LEFT ALONE; every ceremony candidate
      list in this plan names only this plan's own files.
      Verification (met): both gates exit 0; kernel prints
      `2855 checks passed`.

- [x] 2. Docs-sync fold-in — relay received and folded in by the
      author before landing. Sweep verdict: 7 findings, all docs-only,
      everything else clean (links, stage-status consistency, 19
      verbs, doc-numbers guard rc=0, read-order 0–11, all 12
      README-referenced files present, no TODO/orphans). Applied:
      (a) docs/project/roadmap.md:27 stage-0 row corrected "six use
      cases" → "seven" (select-course, 2026-08-27; the foldback record
      fixed the Now section but missed this table row) — this fix
      rides the step-9 ceremony; (b) the three untracked 2026-08-30
      research docs received the grounded rewrite pass (crystallized
      → committed stall of foldback lesson 3, live):
      ceremony-cost-reduction stripped to the batching conclusion
      grounded in the dogfood ceremony (scripts/hngh,
      scripts/ceremony-drive, `make test`) and the observed batched
      precedent; alert-to-work-routing stripped of all Linux-kernel-
      module/Netlink/sysfs mechanics and reframed to the real alert
      surface (reports.md rows, flap-suppressed oversight, backlog
      routing row, foldback lesson 2) with recommendations in Hngh's
      shape (alerts → parseable plan-step candidates, outcome tracked
      by plan checkbox ticks + reports rows);
      delegation-lane-parallelism's fabricated file references removed
      and its minimal-DelegationQueue conclusion grounded in
      scripts/omp-bridge's actual delegation path. All three carry
      Grounding sections of verified paths. No CHANGELOG line: no
      contract doc substantively changes (a one-word route-table
      correction is not substantive).
      Verification (met pre-landing): roadmap.md:27 reads "seven";
      no PR/CI/Sphinx/Netlink mechanics remain outside explicit
      anti-pattern mentions; `make test` green (2,855 checks) with the
      fixes in the tree.

- [ ] 3. RESEARCH BEAT (never code): handoff-brief schema. Crystallize
      one scoped parseable doc into docs/research/
      (2026-08-30-handoff-brief-schema.md) defining the minimal
      failure-informed handoff brief: fields (objective, lane, budget
      spent, what landed, what is uncommitted, failure mode, correction,
      replacement instruction), each field grounded in a real producer —
      active-work.md lane lines, the watchdog handoff ledger
      (hngh-automation/agent-handoffs.md) and scripts/omp-bridge's
      --orient/--run-start brief. Grounding section lists verified
      paths read in this repo; no repo facts asserted beyond those
      anchors; if evidence is thin for a field, frame it "not
      established" (the delegation-lane line's framing is the model).
      Secondary citation: operator suite 09-runbook.md (audited via
      lessons-and-foldback) if its framing matches. The beat plans its
      own landing: an unchecked docs-ceremony step appended to this
      plan or the overnight plan (batched landing per
      ceremony-cost-reduction's directional conclusion).
      Verification: the doc exists under docs/research/ with a
      Grounding section naming only paths verified to exist
      (`test -f` each); `make test` still green (docs land in a
      ceremony).

- [ ] 4. GROW BEAT (development, normal-risk only): first live wrapped
      delegation per roadmap stage 3, scoped to what scripts/omp-bridge
      actually supports. One bounded real delegated session does ONE
      named small task (a docs check or a single-step automation task
      with a plain commit), wrapped as: `scripts/omp-bridge --run-start
      <session> "<objective>"` → the session works → observatory shows
      it `working` → `scripts/omp-bridge --run-end <run> <disposition>`
      with an honest disposition (`cancelled` is the legal close from
      `:created`; refusal of an illegal disposition is the contract
      working). Witness the full cycle as reports.md/active-work rows
      named in the step's own record. If the bridge refuses start or
      end for a cause not listed above, record the refusal as an alert
      row and park the sub-step — do not widen scope into kernel
      changes.
      Verification: reports.md gains a row (or rows) witnessing
      run-start → work → run-end for the named session; the run's
      ledger state (hngh present / bridge store) shows the closed run;
      `make test` green; no kernel file touched.

- [ ] 5. RESEARCH BEAT (never code): steer-vs-die threshold. Crystallize
      docs/research/2026-08-30-steer-vs-die-threshold.md: the judgment
      rubric from roguelike-agentic.md ("is this agent learning, or just
      burning?") made into a scoped parseable table — signals (loop
      repetition, unrecovered error, tool-calling spiral, procedural
      hook availability, budget burn rate) each with an observable
      trigger and the response (steer | procedural hook | die+replace),
      grounded in the alert classes actually filed in
      docs/project/reports.md (agent-stall, loop-signal, slow-unit,
      tree-skew) and hngh-automation/jobs/agent-watchdog.sh.
      Grounding section: verified paths only; "not established" framing
      for anything thin. Batched-landing note as in step 3.
      Verification: doc exists with Grounding section; each table row's
      trigger cites an alert class or watchdog behavior verifiable in
      the named files; `make test` green.

- [ ] 6. GROW BEAT (development, normal-risk only): config-backup →
      config-manager, automation-side declarative config-lane listing.
      Grounded: hngh-automation/jobs/config-backup.sh exists with a
      LANES block (agent-configs, hermes-mcp-proxy, hermes-nous-off)
      and the 30m drop-in cadence/30m/20-config-backup.sh is landed.
      Add ONE declarative lane-list surface: a machine-readable lane
      manifest (e.g. config-lanes.tsv, lanes as data, operator-editable)
      that config-backup.sh reads instead of the in-script case block,
      plus the parity proof per lane in its existing --dry-run mode.
      Plain commit in hngh-automation gated by `make test`. If any
      sub-step would require hngh kernel src/tests/Makefile/hngh.asd
      changes (governed update lanes are kernel-side), that sub-step
      PARKS per the autonomy rule with an alert row.
      Verification: `cd hngh-automation && make test` exits 0;
      `jobs/config-backup.sh <lane> --dry-run` parity-proofs each lane
      listed in the manifest against gbd HEAD; removing a lane from the
      manifest removes it from the run (behavior visibly data-driven).

- [ ] 7. RESEARCH BEAT (never code) — SHRUNK by the doc-sweep relay:
      the routing-table design already landed as the grounded rewrite
      of docs/research/2026-08-30-alert-to-work-routing-* (its mapping
      table routes the observed alert classes to candidate step
      shapes; landed in step 9). This beat shrinks to resolving that
      doc's two open threads — where draft plan-step candidates stage
      (plans-directory file vs queue-ledger column) and how dedup
      windows interact with an open plan step — by appending a
      resolution to the same doc. Docs only: implementing the mapping
      as automation-side routing is a follow-on grow beat (it writes
      hngh-automation code), parked until the resolved doc is priced.
      Verification: each open thread in the research doc carries a
      resolution or an explicit "parked, needs X" note; no code
      written this beat; `make test` green.

- [ ] 8. RESEARCH BEAT (never code): publication-pipeline grounding pass.
      Crystallize docs/research/2026-08-30-publication-pipeline-grounding.md:
      inventory what scripts/generate-publication (--ebook/--site)
      actually consumes (crystallized docs/research/ lines) and what the
      self-funding backlog rows (ebook-longform, public-surface,
      royalty-pipeline, funding-rails) need next, as a priced parseable
      decision per master-plan §4's gate. Grounding section lists
      scripts/generate-publication, the docs/research/ inventory, and
      the four backlog rows; no pipeline mechanics asserted beyond
      those reads.
      Verification: doc exists with Grounding section; `test -x
      scripts/generate-publication` passes; every claim about the
      pipeline cites a read file; `make test` green.

- [ ] 9. Batched docs ceremony (the ceremony-cost-reduction conclusion
      applied live — its grounded rewrite's F3 records this as the
      precedent): ONE certificate ceremony through scripts/ceremony-
      drive / scripts/hngh landing exactly: both 2026-08-30 plan
      files, docs/records/2026-08-30-evening-selfdev-plan.md,
      docs/project/roadmap.md (step-2 fix), and the three rewritten
      research docs. `make test` green immediately before; candidate
      paths are docs files only — the live loop's dirty files
      (journal, reports.md, ui-grades.md, current-overlay.json) are
      NOT candidates. Steps 3/5/8's new research docs join the NEXT
      batch (the overnight plan's ceremony step) rather than widening
      this one.
      Verification: one ceremony commit; `git show --stat` matches the
      seven-file candidate list; `make test` green immediately before
      issue-cert; ceremony exit 0; push to origin succeeds or the push
      failure is recorded as an alert row.

- [ ] 10. Wrap: lessons harvest into docs/project/lessons-2026-08-30.md
      (does not exist yet — the 09:00Z auto-harvest did not create it;
      create per lessons-2026-08-29.md's shape, sources cited),
      queue/backlog sync (mark completed rows, add candidates the
      beats surfaced), tick this plan's checkboxes and front-matter
      status as steps complete, and write the RECORD
      docs/records/2026-08-30-evening-selfdev-plan.md. Journal:
      RE-SCOPED per the doc-sweep relay — docs/journal/2026-08-30.md
      is dirty with the live autonomous loop's writes and is
      machine-owned tonight; this wave leaves it alone and the RECORD
      notes that. Land any straggler docs in a second batched ceremony
      in the step-9 style.
      Verification: docs/project/lessons-2026-08-30.md exists with
      sources cited; the RECORD exists; journal untouched by this
      wave; `make test` green at close.

## Verification summary

- Kernel gate: `make test` green (2,855 checks as of the 2026-08-30
  evening baseline, wall ~34 s) before every hngh ceremony landing;
  plan files and this evening's docs land via ceremony.
- Automation gate: hngh-automation `make test` green before every
  plain automation commit.
- Alternation held: grow (4) ↔ research (3/5/7) ↔ grow — no two
  consecutive same-kind beats; research beats never write code; grow
  beats never touch kernel src/.
- Paced cadence: each beat ≤ ~60m wall; a beat that cannot meet its
  verification parks with an alert row rather than forcing through.
- No provider/credential work, no systemd changes beyond an installed
  unit, no deletions outside the 48h prune; critical-class parks.
