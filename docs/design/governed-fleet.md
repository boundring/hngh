# The Governed Fleet -- stages 3+4 consolidated

> **RATIFIED, PENDING LANDING -- 2026-09-13.** The operator ratified
> this consolidation and accepted all four section-9 losses, with one
> amendment: slice G (operations knowledge-graph surface) is the
> operator-directed replacement for the demoted visibility framing.
> Written by the roadmap-consolidation session under explicit operator
> authorization to reorganize, combine, and filter the current stage
> designs. Landing rides the certificate ceremony under plan
> governed-fleet-consolidation. Edits target docs/project/roadmap.md;
> every other existing document stays untouched.
> Slices reference the bili integration decision document (to be filed
> as docs/records/2026-09-13-bili-hngh-integration.md).

Grounding reads: roadmap (../project/roadmap.md), master-plan
(../project/master-plan.md), descent (descent.md), plans contract
(../project/plans/README.md), ceremony contract
(autonomous-development-control.md), backlog (../project/backlog.md).

## 1. Intent

The Governed Fleet is where everything the harness leans on outside the
kernel -- model-chain legs, companion services, agent CLIs, credential
seams, spawn paths, and, at the close of the stage, one lattice peer --
becomes admitted surface: declared in a registry, enforced by a guard,
watched by a patrol, and mutated only through the certificate loop.

Former stage 3 ("Roguelike delegation live") and former stage 4
("System harness D/E") merge into this stage. Grounding:

- Stage 3's governed-delegation essence is built (rung 14-18 worker
  landed 2026-08-25; run-start/observatory/run-end wrapping live;
  watchdog, supervision, and respawn guarded). What remains is the
  witnessed cycle and the seeded-stall auto-replace: behavioral proof,
  not new surface.
- Stage 4 as written is host-centric (config-manager, package-manager,
  maintenance routines, CachyOS-first), but the interim stream that
  actually accumulated was fleet-centric: model providers and quotas,
  credential seams, the bili context proxy, agent CLIs, companion
  services. The registries already exist; the stage codifies them and
  finishes two live proofs.
- This is where internal federation begins: the registry/guard/patrol
  triad is the meta-kernel's admission layer, and a lattice peer is
  admitted through exactly the gates a local leg or service passes.

## 2. The one pattern

One shape re-emerged across every domain landed 2026-09-12/13:

1. Nothing is used that is not declared.
2. Nothing is declared that is not guarded.
3. Nothing declared goes unwatched.
4. Nothing mutates without a certificate.

| Registry | Declares | Guard | Patrol |
| --- | --- | --- | --- |
| automation/config/leg-budgets.tsv | one row per model-chain leg: curl --max-time + bounded max output ("no declared pair, no chain admission") | automation/tests/test-leg-budgets.py | budget/session-budget (day) |
| automation/config/hngh-services.tsv | one row per companion service: role, install-method, start-command, health-url, managed-by, disposition | automation/tests/test-hngh-services.py + test-service-ctl.py | services/service-health + service-children (day) |
| automation/config/hngh-packages.tsv | one row per collected CLI/package: upstream, install-path, update-mechanism, follow-feed, disposition | automation/tests/test-hngh-packages.py (ghost-row: in-use install-path must resolve on host) | packages/package-ghosts (day) |
| automation/cadence-params.tsv | one row per loop tunable: key, value, provenance, note; env overrides | per-consumer leg tests (test-quota-routing.sh, test-model-demote.sh, per-leg tests) | budget/session-budget (day) |
| automation/config/patrol-routes.tsv | one row per patrol: surface, check, freq-tier, finding-class | automation/tests/test-patrol.py | executed by jobs/patrol.py (30m + day tiers); FAIL -> identity patrol:<id> + digest/PATROL-<date>.md |
| automation/jobs/config-lanes.tsv | declarative config backup lanes | lane catalog checks | 30m cadence timer (hngh-cadence-30m.timer, hngh-automation 34cd275) |
| credential seams | token-only, fail-soft (reviewer token confined to one curl Authorization header) | test-credentials.py, test-credential-kimi.sh, test-notify-seam.sh, test-doc-secrets.py | security-check.sh seam checks |
| spawn paths | compression/telemetry matrix: which launch paths get bili MITM, which legs stay direct | test-bctx-launch.py, test-session-launch.py, test-ocgo-launch.py, test-context-pack.sh | security-check bili=$b_ok breadcrumb |

The certificate gate: scripts/omp-bridge --ceremony wraps
scripts/ceremony-drive -- create-run, admit-transport, propose
(ten-principle verdict), issue-cert + mutation-check prepare-candidate,
issue-cert + mutation-check commit, certificate-gated push; the commit
message is the certificate content hash. Doctrine 2026-09-12: LARGE vs
SMALL. Doctrine 2a (2026-09-13): kernel src mutations with a certificate
path need no separate operator stall; only actions with no certificate
path park. The 2026-09-13 :wake-mutation admission
(src/adapter/mutation.lisp +mutation-actions+) retired the operator
stall class for wake.

## 3. What it absorbs, what it filters

Absorbs:

- From stage 3: delegation wrapping (run-start budget loadout ->
  observatory working -> run-end disposition), self-supervision tick +
  stall auto-replace, gantt actual-vs-estimate bars, per-lane medians
  (as ledger rows), session observatory.
- From stage 4: governed package upgrade through the certificate loop;
  config lanes declarative + backed up on cadence (already live --
  kept as a standing invariant); managed-service lifecycle (already
  registry + patrol + service-ctl allowlist, 2026-09-03 operator
  grant).
- From the interim stream (2026-09-06..13): bili S1/S2/S3 (context
  proxy); quota-tightest-window pacing (kimi/zai/ocgo/remote caps in
  cadence-params.tsv); the spawn-path matrix; the :wake-mutation lane
  (landed 2026-09-13); hngh-services.tsv + service-ctl (2026-09-12);
  leg budgets ("no declared pair, no chain admission").

Filtered or dropped, with reasons:

- Maintenance routines (orphans, caches, journal vacuum): host hygiene,
  not fleet admission; rides the day cadence as ordinary SMALL
  automation; not a stage exit.
- "CachyOS first, per-host orientation generalizes": federation-era;
  this host is the only managed host in this stage; generalization
  belongs to stage 7.
- Visibility framing as stage-defining content: observatory/gantt/
  medians demote from stage-3 framing to scoped work inside the
  witnessed-cycle proof; nothing is dropped, but nothing is
  exit-bearing either (see section 9.1).
- One-shot chain beats through the bili proxy: never. Compression is
  pressure-gated and beats pay per-call tool-def injection they cannot
  use (bili decision doc section 3.2). Chain legs stay direct;
  tokens_cached telemetry is the integration surface.
- Full emergence as an authority source: refused. Emergence is a
  description of observed behavior over certified transactions, never
  the certified thing itself (section 5.1).

## 4. Invariant exit criteria

The stage is done when all ten hold under the standing gates. The
roadmap bar applies unchanged: done means the exit criteria hold under
standing guards and patrols, not a demo.

| # | Invariant | Guard | Patrol / evidence |
| --- | --- | --- | --- |
| 1 | every remote chain leg budget-declared | test-leg-budgets.py | leg-budgets.tsv complete; "no declared pair, no chain admission" |
| 2 | every managed service registered + health-polled | test-hngh-services.py, test-service-ctl.py | services/service-health + service-children patrols silent |
| 3 | every credential seam token-only, fail-soft | test-credentials.py + per-leg seam tests + test-doc-secrets.py | security-check seam checks green |
| 4 | every delegated spawn path in the compression/telemetry matrix | test-bctx-launch.py, test-session-launch.py, test-ocgo-launch.py, test-context-pack.sh | tokens_cached rows present per matrix path; bili=$b_ok breadcrumb |
| 5 | every in-use package resolves on-host | test-hngh-packages.py | packages/package-ghosts patrol silent |
| 6 | every quota window declared + paced | cadence-params caps consumed by test-quota-routing.sh, test-model-demote.sh | budget patrol silent; no leg exceeds declared caps |
| 7 | one witnessed delegation cycle; a seeded stall flagged and auto-replaced, no human | watchdog + supervision + respawn guards | ledger/dashboard record: run-start -> observatory working -> run-end with injected stall replaced |
| 8 | one governed package upgrade start-to-finish through the certificate loop on this host | ceremony | certificate + "hngh: candidate <hash>" commit in git log |
| 9 | config lanes declaratively listed, backed up on cadence | config-lanes.tsv + lane checks | already green; standing invariant since hngh-cadence-30m.timer |
| 10 | one lattice peer admitted through the same gates | pins + verified attestation; :wake-mutation ceremony | peer admission record + one wake/worker cycle across hosts |

Criterion 7 closes former stage 3's exit; 8 closes former stage 4's
exit; 10 is the federation exit (node-lattice admission -- the queue
ledger's Next pointer already names it).

## 5. Node-lattice and the mirror principle

Admission is one shape at every level:

| Level | Admitted by |
| --- | --- |
| run | create-run + four closed admission facts |
| transport | admit-transport, closed kinds |
| peer key | pinned keys + verified attestation |
| service | registry row + health-url + patrol |
| chain leg | budget pair (max-time, max-output) |
| kernel mutation | certificate (ten-principle verdict) |

A lattice peer repeats the same act one level out: registered like a
service (endpoint + health), keyed like a transport (pins +
attestation), budgeted like a leg (wake/worker budgets), certified like
every mutation. When the second node orients, admits, and backs up
through these gates, internal federation has begun. That scale-out is
stage 7; this stage admits one peer to prove the mirror.

### 5.1 Design pressure: the sensorimotor memo (2026-09-13)

Operator-supplied memo on "Sensorimotor Mechanisms of Decisions and
Actions" (T.W. James, preprint 2025-07-11,
doi:10.20944/preprints202507.0979.v1; full text
agent://sensorimotor-paper). Three durable constraints, draft inputs
for ratification:

1. The meta-kernel carries reference signals, not verdicts (Powers'
   perceptual control theory; memo claims 3+6). Domain kernels
   coordinate through setpoints in shared feedback loops --
   invariants, alert thresholds, patrol feedback -- never through a
   top-down dispatcher. Restated: the registry/guard/patrol triad is
   the meta-kernel's admission layer, and the meta-kernel distributes
   reference inputs; it is a constraint-checker, not a decider. No
   design doc may describe it as deciding.
2. Emergence is legitimate only as descriptions of certified
   transactions, never as the thing certified (memo claim 4
   inverted). An emergent verdict could never carry a content hash
   because there is no physical transaction it IS; certificate-
   binding an emergent property is a category mistake. Emergence
   lives in observed system behavior -- candidate generation, drift
   signals, cross-kernel message flow, loop-closure timing -- which
   sharpens, not softens, the refusal in section 3.
3. Conflict between feedback loops is where emergence must be
   refused: no loop resolves another loop's contradictory setpoints.
   Escalation to certificate on conflict is a reference-signal-
   violation tripwire, the only locatable resolution. The certificate
   is the DESCRIPTION of a transaction completed within reference
   bounds, not a deliberation stage that causes the action --
   anything else re-imports the sense-think-act sandwich the paper
   calls a category mistake.

Boundary note, kept honest: the paper is a philosophy-of-science
critique with no empirical mechanism for arbitration; it constrains
vocabulary (reference inputs vs homunculus, descriptions vs
mechanisms) more than it decides federation mechanics. Typed messages,
content hashes, conflict verdicts, and review remain engineering
choices. "Emergent selection among certificate-eligible actions" is
defensible only if "selection" means loop-closure timing, not a
mechanism. This reinforces descent's escalation-to-certificate rule;
it contradicts nothing currently landed.

## 6. Sequencing

Already green (G0, no work): the six registries with their guards;
config-lanes 30m tier; system-ops v1 package inventory; the
:wake-mutation lane; the rung 14-18 bounded read-only worker; quota
pacing; credential seams.

Slices, in order:

- A -- bili integration S1 -> S2 -> S3 (absorbs the context proxy).
  S1 tokens_cached capture: automation/jobs/telemetry.py FIRST
  (DATA_FIELDS + INSERT + help + ALTER TABLE events ADD COLUMN
  tokens_cached INTEGER), then automation/lib/model.sh _post_chat jq
  extraction + _model_emit --data; model.sh emit rejects unknown keys
  fail-closed, so telemetry.py must land first or every model row
  fails. S2: hngh-services.tsv billion-context row + security-check.sh
  bili=$b_ok breadcrumb. S3: the decision-doc record. Free-commit.
- B -- spawn-path matrix completion: the matrix (interactive omp/pi,
  machine-launch omp, opencode executor env-only MITM, jcode stdio;
  chain beats and local legs direct) promoted into this doc + tokens
  _cached backfill across legs. Free-commit.
- C -- the witnessed delegation cycle + seeded stall auto-replace
  (former stage-3 exit): one real cycle with run-start -> observatory
  working -> run-end, plus an injected stall flagged and replaced by
  watchdog/supervision. Free-commit + one witnessed run.
- D -- governed package upgrade through the certificate loop (former
  stage-4 exit): System-view trigger lands, one upgrade runs propose ->
  certify -> commit. The ceremony is the exercise; kernel src
  untouched. Certificate-path slice.
- E -- credential-seam sweep + freshness: token-only verified per seam,
  pinned-key freshness wiring for peer admission, model-tier refresh
  cadence (follow-feeds + research lane on route/cost drift).
  Free-commit.
- F -- node-lattice admission (federation exit; the queue ledger
  already points here): peer registration, pins + evidence-freshness/
  key-rotation rung, one wake cycle through :wake-mutation, one
  read-only worker across hosts. Certificate path only if a new kernel
  action is needed (none expected).
- G -- operations knowledge-graph surface (operator-directed
  replacement for the demoted gantt/medians visibility framing; NOT
  exit-bearing -- the ten invariants of section 4 stand unchanged):
  an interactive 3D graph of hngh's operations in the existing
  dashboard. Nodes are the registries, chain legs, services, packages,
  credential seams, sessions, and research lines; edges are the
  admission/consumption relations of the section-2 table. Fed live
  from the registries and the telemetry db; WebGL/three.js-class
  rendering with a graceful 2D/static fallback when WebGL is
  unavailable.

A, B, E are free-commit automation; C is a witnessed run; D and F
exercise the certificate loop end-to-end; G is operator-directed
visibility surface and is never exit-bearing.

## 7. Roadmap.md revision proposal (ratified 2026-09-13; applied at landing)

One row replaces the two former rows. Numbering 0-3 and 5-7 stays (the
gap at 4 is honest history; renumbering would break descent,
master-plan, and records cross-references).

| **3 -- The Governed Fleet** (absorbs former stage 4; ratified 2026-09-13) | delegation wrapping closed (run-start budget loadout -> observatory working -> run-end; self-supervision tick; gantt actual bars; per-lane medians in the ledger); the registries (leg-budgets, hngh-services, hngh-packages, cadence-params, patrol-routes, config-lanes) with their guards and patrols; bili/context-proxy integration (tokens_cached telemetry, managed service, spawn-path matrix); credential seams token-only; governed package upgrades through the certificate loop; config lanes backed up on cadence; node-lattice admission as the federation exit | the ten invariants of this doc (section 4) hold under the standing guards and patrols -- including one witnessed delegation cycle with a seeded stall auto-replaced, one governed package upgrade start-to-finish through the certificate loop on this host, and one lattice peer admitted through the same gates | **landing** |

Footnote under the table: "Former stage 4 (System harness D/E) merged
into stage 3 on 2026-09-13 (docs/design/governed-fleet.md); stages 5-7
keep their numbers."

Now section, one added paragraph (after the existing items):

"The Governed Fleet (stage 3, absorbing former stage 4 on 2026-09-13):
the route is the slice list in docs/design/governed-fleet.md section 6
-- bili telemetry/registry first, then the witnessed cycle and the
governed upgrade, credential sweep, node-lattice admission as the
federation exit. Slice G (operations knowledge-graph surface) rides
alongside as operator-directed visibility -- never exit-bearing."

Next section, working-order edits:

- Item 1 unchanged: Land stage 2 (final verification; config-backup
  lanes on the 30m tier; self-improvement cadence routine).
- Item 2 becomes: "Open the governed fleet: bili S1/S2/S3 (telemetry.py
  before model.sh), then the witnessed delegation cycle with a seeded
  stall auto-replaced."
- Item 3 (stage 4 spikes in parallel) becomes: "Governed package
  upgrade through the certificate loop and the credential-seam sweep
  run in parallel once the cycle is witnessed; slice G (operations
  knowledge-graph surface) renders in the existing dashboard off the
  live registries."
- Items 4-5 unchanged (5/6 alternation; third-evening intake).

Explicitly untouched: stages 0-2 rows and the Completed history
(2026-06 through 2026-09); stages 5-7 rows verbatim (7 gains only the
footnote); the direction paragraphs; the alternation rules; the
no-daemon line (kept -- the compliant service posture remains transient
per-run lifecycles, registry rows, health patrols, service-ctl
allowlist; never a daemon class).

## 8. Backlog triage (interim + planned items)

Classifications: ABSORB = folds into this stage's slices; DEFER = stays
queued for stages 5-7 or named lanes; DROP = out of stage doctrine
(flip done / ordinary SMALL matter / superseded -- the row is resolved,
not deleted from the append-only backlog).

ABSORB (slice in parentheses):

- Pi read-only delegation spike -- superseded by the rung 18 worker;
  its open remainder is the witnessed cycle; flip done at slice C. (C)
- Bridge-backed continual worker (worker-rung candidate). (C)
- Self-supervision tick. (C)
- Session observatory. (C)
- Cascading gantt: run estimates + parallel cascade. (C scope; 9.1)
- Config manager -- governed update lanes; backup already live. (D)
- System controls -> governed package operations. (D)
- Security manager -- split: key/pin freshness -> E/F; patch-state ->
  already system-ops v1; secret hygiene -> already guarded. (E, F)
- Credential rotation automation -- token seams + model-leg refresh;
  the bulk-password Keyring stays its own design pressure (DEFER). (E)
- Model-tier refresh cadence. (E)
- Node-lattice admission rung (implementation). (F)
- Evidence-freshness + key-rotation rung. (F)
- Push self-sufficiency -- verify and flip done (16-remote-push.sh
  live); standing invariant thereafter. (G0)

DROP (from stage doctrine; resolve the row):

- Governance vocabulary -- landed by usage; naming is done.
- Cadence continuum / Activity cadence rows -- landed (stage 0/1
  scope); flip done.
- Kernel gate watch-test load flake -- test-infra SMALL fix on the
  free-commit lane; not stage doctrine.
- One-shot chain beats through the bili proxy -- refused by design
  (bili decision doc 3.2).

DEFER (target in parentheses):

- Stage 7 (federation scale-out): node lattice rung (megastructure
  mesh), ambient-free tunnel keepalive, resource pool view, device
  fleet bring-up, host orientation pass, Syncthing fleet manager
  (Portage P2).
- Stage 5 (research/evidence alternation): DSSE envelope export
  serializer, governance-benchmark research lane, night-agent plan
  authoring (plan-supply), machine-steered backlog, CI governance
  gate, documentation-sync loop, report-ledger retention policy.
- Stage 6 (surfaces/QoL): gantt ports, interface mocks, operative
  overlay, operative voice, pixel-agent assets, widget grid,
  Emacs-style configurability, browser notification surface,
  interface plurality, agent live view, research-lines user controls,
  research precedence, memory surface (llm-wiki), startup launch flow,
  webapp dashboard, command center, hosted agentic interface
  (+navigable refinement), OMP-Hngh bridge plugin, surface evolution
  loop, self-optimization continuum, notify agent, dancing interfaces,
  project journal.
- Stage 5/6 publications lane: long-form ebook, book-machine inputs,
  publication-lines contract, self-hosted public surface, royalty
  pipeline, funding rails, royalty catalog APIs, social read layer,
  social post layer (gated), OSS contribution candidates.
- Operator-directed design pressures, own lanes (2026-09-07 Mirror +
  Keyring, Portage P1 takeout): operator-coherence layer,
  credential-rotation harness, takeout ingest.
- Structural, operator decision: repo topology consolidation, clean
  reorientation track A, interactive installer maturity, OS-harness
  knowledge tracks (back-burnered per the 2026-09-11 admission).

## 9. Contradictions and honest losses

Where the consolidation would lose or weaken written criteria --
named, not hidden:

1. Visibility de-pinned. Stage 3's written scope "gantt renders actual
   bars beside estimates; per-lane medians" becomes non-exit scope.
   The written stage-3 EXIT survives intact (witnessed cycle + seeded
   stall), so nothing exit-bearing is lost -- but the gantt/medians
   bullets lose their stage anchor and could rot. Mitigation proposed:
   medians are ledger rows (stage 1 consumes them anyway); gantt
   actual bars stay slice C scope. The operator accepts this demotion
   explicitly or restores them.

   ACCEPTED 2026-09-13, with one amendment: the operator trades the
   demoted gantt/medians anchor for a modern operations-visibility
   surface -- slice G, an interactive 3D knowledge graph of hngh's
   operations (nodes = registries, chain legs, services, packages,
   credential seams, sessions, research lines; edges = the section-2
   admission/consumption relations), fed live from the registries and
   the telemetry db in the existing dashboard, WebGL rendering with a
   2D/static fallback. Slice G sits in stage 3's slice list (section
   6), not the stage-6 QoL lane: it visualizes exactly the registries
   this stage admits, so it belongs where they are defined. It is NOT
   exit-bearing.
2. Stage 4 scope loss. "Maintenance routines (orphans, caches,
   journal vacuum)" and "CachyOS first, per-host orientation
   generalizes" are dropped from the stage. The governed-upgrade exit
   is kept; the rest defers to stage 7 / SMALL lanes. A real
   narrowing of written stage 4.
3. Stage 4's exit "config lanes declaratively listed and backed up on
   cadence" is already satisfied (config-lanes.tsv +
   hngh-cadence-30m.timer, hngh-automation 34cd275). Carried as a
   standing invariant (section 4.9), not forward work -- an exit
   criterion that is already true stays visible so the stage cannot
   claim it as new progress.
4. Stage 7 boundary moves. Stage 7's exit -- "a second host orients,
   admits, and backs up through the same gates" -- keeps its wording,
   but the admission half now has a predecessor in this stage (one
   peer admitted). Honest reading: stage 7 loses the first-admission
   claim, keeps orient + backup + fleet scale-out. Ratifying the merge
   ratifies moving that line.
5. roadmap.md:171-174 history line ("the worker-driver E2E and
   node-lattice amendments roll into stage 3 and stage 7") goes
   stale: the admission amendment lands in stage 3 entirely. The line
   is already marked as history; the section 7 footnote supersedes it.
   superseded 2026-09-24 - see roadmap.md:25-33
6. master-plan.md section 5 P-phases are not renumbered. The merge
   pulls P5-adjacent lattice work (admission, key rotation) earlier;
   master-plan is a dated planning artifact (2026-08-26) and needs a
   one-line amendment at ratification, not a rewrite. Not edited here.
7. No-daemon line tension. The Governed Fleet runs managed services
   (comfyui, ollama rows; bili on 8787). The compliant posture --
   practiced since 2026-09-12 -- is transient per-run lifecycles,
   registry rows, health patrols, service-ctl allowlist; never a
   daemon class. The line stays; every new service in this stage must
   keep that posture or the stage violates its own roadmap.
8. Nothing in stages 0-2 or 5-7 exits is weakened by the merge. The
   only weakened item is stage 7's first-admission precedence
   (item 4).

## 10. Ceremony-ready plan stub

The operator ratified on 2026-09-13 (all four section-9 losses
accepted, plus the slice-G amendment). With that explicit go, the
executing session runs scripts/omp-bridge --propose with this stub and
lands the record and the roadmap edit through the certificate
ceremony.

- slug: governed-fleet-consolidation
- file: docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md
- front-matter: <!-- plan: status=proposed risk=normal accepted=- -->
- title: The Governed Fleet -- ratify and land the stages 3+4
  consolidation

Steps:

- [ ] Ratification record
      docs/records/2026-09-13-governed-fleet-consolidation.md; edit
      roadmap.md per section 7 (kernel docs; ceremony commit; make
      test green)
- [ ] Flip absorbed/landed backlog rows per section 8 (automation
      free commit)
- [ ] Slice A: bili S1 telemetry (telemetry.py FIRST, then model.sh),
      S2 registry row + patrol breadcrumb, S3 record
- [ ] Slice B: spawn-path matrix promoted + tokens_cached backfill
- [ ] Slice C: witnessed delegation cycle + seeded stall auto-replace
      (evidence: ledger/dashboard record)
- [ ] Slice D: governed package upgrade through the certificate loop
      (evidence: certificate + commit in git log)
- [ ] Slice E: credential-seam sweep + model-tier refresh cadence
- [ ] Slice F: node-lattice admission -- one peer admitted through the
      same gates (federation exit)
- [ ] Slice G: operations knowledge-graph surface in the dashboard --
      3D WebGL view of the section-2 registries, live-fed, 2D/static
      fallback (NOT exit-bearing)
- [ ] Roadmap stage 3 row flips to done when all ten invariants hold
      under standing guards and patrols

risk=normal: no provider/credential configuration, no systemd
lifecycle beyond already-installed units, no deletions, no
security-posture changes. Registry-row edits and the telemetry column
are automation commits; roadmap/docs land via the standard ceremony
(proposed normal-risk plans auto-accept when verification steps are
runnable and both repos' gates are green).
