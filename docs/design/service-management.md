# Service management — design contract for managing installed software

Status: DESIGN — operator-directed 2026-09-03 (directive 1: local
Unsloth hosting is recognized; long-run Hngh manages Unsloth AND
software generally — stopping/starting services, config and update
management). Nothing here is landed; this contract names the closed
surfaces the implementation slices must obey.

Cross-links: [credentials-posture.md](credentials-posture.md) (the
secrets these services consume),
[ledger-and-records-spec.md](ledger-and-records-spec.md) (evidence
patterns), [../../project/roadmap.md](../project/roadmap.md) stage 4,
[../../project/backlog.md](../project/backlog.md) rows config-manager
and package-manager.

## 1. Recognition (read-only probe surface)

Hngh must first SEE installed software before it manages any of it.
The recognition surface is read-only and lands in hngh-automation as
`jobs/service-state.py` (sibling slice 2026-09-03 — **declared, not
yet visible on disk at authoring time 2026-09-04**; verify on
arrival).

- **Unit facts** (read-only): for each tracked unit —
  `systemctl --user is-active`, `is-enabled`, and the unit-file state
  from `list-unit-files`. Observed 2026-09-04 (read-only checks):
  `llama-server.service` disabled, `unsloth-warm.service` disabled,
  `unsloth-studio.service` enabled; all three inactive at that moment.
- **Port-vs-unit correlation**: a service is not "up" because its unit
  is active. The probe pairs unit state with an HTTP reachability
  check per known endpoint — `127.0.0.1:8080` (Unsloth/llama-server,
  health) and `127.0.0.1:11434` (Ollama). Observed 2026-09-04: :8080
  returned 000 (down) while :11434 returned 200 (up) — exactly the
  divergence the correlation exists to catch.
- **Alert classes** (closed list):
  1. `port-down-unit-active` — the 2026-09-03 classic: unit claims
     active, endpoint unresponsive. Highest priority; feeds recovery.
  2. `port-down-unit-inactive-installed` — installed but not running;
     recoverable by the control surface (start), see §2/§4.
  3. `port-down-unit-missing` — software not installed at all;
     operator setup item, never a machine action.
  4. `port-up-unit-inactive` — something answers without the unit
     (foreign process, stale socket); record, do not touch.
  5. `unit-failed` — systemd reports failure; recoverable by restart
     after the failure is read (journalctl unit slice, read-only).

## 2. Control surface (`scripts/service-ctl.sh` — closed lists)

Lands as `scripts/service-ctl.sh` (sibling slice 2026-09-03, same
verify-on-arrival caveat). Two closed lists define the entire
authority:

- **Units (closed allowlist)**: exactly `llama-server`,
  `unsloth-warm`, `unsloth-studio`. Nothing else is ever addressable;
  a request outside the list is refused by name, not guessed at.
- **Verbs (closed)**: `start`, `stop`, `restart`, `status`.
  `status` is read-only and always available. `enable`, `disable`,
  `mask`, and any unit-file edit are REFUSED by the script itself —
  they are critical-class (see §3).

Every mutating action (start/stop/restart) is logged — timestamp,
unit, verb, exit code — and appended as a progress row to the report
queue, so the operator digest carries service history the same way it
carries ceremony history. Every action is reversible by construction
(start reverses stop and vice versa; restart is idempotent over a
running unit and recoverable over a stopped one).

Refusal taxonomy (fail closed, echoing the kernel's refusal
vocabulary):

| Refusal | Trigger |
|---|---|
| `unit-not-allowlisted` | unit outside the closed list |
| `verb-not-admitted` | verb outside the closed list |
| `lifecycle-class-critical` | enable/disable/mask/unit-file edit requested |
| `unit-missing` | unit not installed — recognition's class 3 |
| `action-unlogged` | log/progress-row write failed → action NOT taken |

## 3. Governance amendment (the 2026-09-03 operator grant)

Recorded here and in the capabilities plan + record; the standing rule
docs are NOT silently edited.

Under the operator grant of 2026-09-03 (directive 1), **start / stop /
restart of an ALLOWLISTED, ALREADY-INSTALLED user unit is
normal-risk** — ordinary gated machine work. Everything else about
systemd remains **critical-class and parks**:

- `enable` / `disable` / `mask` (changes what runs at boot);
- unit-file edits (changing what a unit IS, not whether it runs now);
- anything touching the security posture (firewall, secrets, keys —
  see [credentials-posture.md](credentials-posture.md)).

This is consistent with the kernel's standing rule ("critical = systemd
unit lifecycle beyond an already-installed unit"): an installed unit's
start/stop is lifecycle WITHIN an installed unit, so the rule stays
intact, letter and spirit.

Boundary, stated honestly: **Hngh runs no service of its own.** No
daemon, no watcher, no self-authored unit, no process Hngh invented.
Hngh MANAGES existing installed software — the operator installed
llama-server, Unsloth Studio, and Ollama; Hngh keeps them serving.
Every control action is logged and reversible; the allowlist is closed
and grows only by a new operator grant (which extends this document
first, the script second).

## 4. Update handling (halt → restart → re-validate)

Unsloth hosting is up ~99% of the time and occasionally halts for
updates (operator observation, 2026-09-03). The update loop is:

1. **Detect**: recognition's `port-down-unit-active` class, or the
   unit itself reporting a maintenance state, or the daily recovery
   sweep (`cadence/day/11-service-recovery.sh`, sibling slice
   2026-09-03, same verify-on-arrival caveat) finding :8080 down while
   the software is installed-but-inactive.
2. **Restart after update**: `service-ctl.sh start` (allowlisted,
   normal-risk). The daily recovery path is: :8080 down +
   installed-but-inactive → start → re-probe. If the halt is a genuine
   in-progress update (studio UI announcing it, or repeated
   crash-loop), the sweep records and waits rather than fighting the
   updater — detection of "update in progress" vs "halted" is a
   recognition duty, not a guess.
3. **Bench re-validation gate before the model lane returns**: a
   restart is not recovery until the fleet proves itself. The model
   lane (lib/model.sh chain: unsloth :8080 → ollama :11434 →
   archive-only) only re-admits :8080 after the next model-bench probe
   run scores the returning endpoint at the standing gate (5/5 local
   lane, per the 2026-09-01→03 bench history where
   unsloth/Ornith-1.0-35B-GGUF held 5/5 all three days). Until then
   the lane keeps falling back — paid fallback is a serving problem,
   not a capability problem.

This step ties directly to the stage-4 backlog rows: package-manager
(update inventory → certificate-gated upgrades) handles the "update"
half; this contract handles the "service came back" half.

## 5. Config management trajectory (config-manager, first declared lane)

Backlog row `config-manager` ("system configuration is edited in
place; rollouts are...") gets its first concrete instance here. The
observed gap: `llama-server.service` carries a bare
`ExecStart=/usr/bin/llama-server` with **no model arguments** — the
unit as installed cannot host the 35B fleet without launch
configuration that exists nowhere declarative today. That bare
ExecStart is exactly the config-lane gap.

Trajectory: declare `unsloth/llama-server launch config` as the FIRST
config lane (a config.env-driven launch: model path, context, port —
declaratively listed, version-controlled in the automation repo,
backed up on cadence per the stage-4 exit criterion). The research
step "what config.env-driven launch config llama-server.service
needs" is staged in the capabilities plan; the kernel stage-4 row
(config lanes declaratively listed and backed up on cadence) is the
destination. Unit-file edits themselves remain critical-class — the
config lane is designed so the unit references a config file Hngh
may manage, keeping the critical boundary intact.

## 6. Provenance and sources

- Operator direction 2026-09-03 (directive 1), recorded in
  [../records/2026-09-03-capabilities-direction.md](../records/2026-09-03-capabilities-direction.md).
- Read-only evidence gathered 2026-09-04: `systemctl --user
  list-unit-files` / `is-active` for the three units (states quoted
  in §1); `curl` health checks :8080 (000) and :11434 (200);
  `~/.hngh-automation/` secret-file listing (paths + modes only).
- Sibling automation slice 2026-09-03: `jobs/service-state.py`,
  `scripts/service-ctl.sh`, `cadence/day/11-service-recovery.sh`,
  queue-progress telemetry in `scripts/email-digest.py` — declared by
  the slice, NOT yet observed on disk at authoring time; every cite
  above is verify-on-arrival.
- lib/model.sh chain comment ("unsloth (401 auto-refresh + empty-
  content retry) -> ollama -> archive-only"), hngh-automation, read
  2026-09-04.
- Bench history: `hngh-automation/stats/model-bench-2026-09-0{1,2,3}.jsonl`
  (5-probe runs; per-model results as cited in §4 and in the
  2026-09-03 staging notes).
- Not established: actual `service-ctl.sh` behavior (file absent);
  whether the sibling slice's refusal taxonomy matches §2 exactly
  (design intent here, to be reconciled on arrival).
