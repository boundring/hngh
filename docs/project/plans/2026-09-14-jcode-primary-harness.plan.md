<!-- plan: status=complete risk=normal priority=high accepted=2026-09-14 completed=2026-09-14 -->
# 2026-09-14 — Jcode primary harness: staged integration plan

Operator-directed 2026-09-14. Companion record:
`docs/records/2026-09-14-jcode-primary-harness-admission.md` (rationale,
architecture constraint, unknowns). This plan is dependency-ordered like
the 2026-09-09 omp plan; each step verifies on its own surface. All code
is edge-tier (`automation/`); the kernel never learns Jcode exists.

## Steps

- [x] 1. **Orientation artifact for Jcode sessions.** A repo-root-facing
      `AGENTS.md` addendum + a `~/.jcode`-side rules/skills package
      giving any Jcode session in this repo the same orientation the omp
      plugin provides (omp-bridge --orient, MCP tools, ceremony
      awareness). Verification: a fresh `jcode -p` session in this repo
      answers three orientation questions correctly without re-walking.
      **Verified 2026-09-14:** artifact landed at
      `docs/agent-notes/jcode-orientation.md`, imported via an
      `@`-import line appended to repo-root `AGENTS.md`. Headless
      verification (`jcode run`) answered all three orientation
      questions correctly after one `--orient` tool call. Note:
      headless `jcode run` surfaces the AGENTS.md context but a
      no-tool-call variant could not answer state questions, so the
      verification leaned on the one allowed tool call (expected:
      orientation content is static; queue state is not).
- [x] 2. **Transport verification + worker driver choice.** Verify the
      local Jcode build's SDK surface (launch/connect, spawn depth,
      swarm behavior) with a throwaway Node probe; decide SDK (Node shim
      in `automation/`) vs direct CLI spawn for the worker driver, with
      the decision recorded. Verification: probe script asserts one
      launched session runs a prompt to `turn_done` and `close()` reaps.
      **Verified 2026-09-14:** probe passed end to end (launch →
      createSession → run → `text: OK` → getRuntimeInfo proto v1 healthy
      → close reaped). Operational finding: a fresh `jcodeHome`
      auto-updates the binary and restarts the daemon mid-session,
      severing the SDK connection (probe failed twice before the update
      was pinned). Worker-driver requirement: pre-seed the instance home
      with update disabled (config `update.auto: false`) or use a fixed,
      maintained home; never a bare temp home. Also confirmed: a home
      already running a server rejects a second launch for the same
      runtime dir ("Another jcode server process is already running"),
      so each worker lane needs its own runtime dir. Decision: the
      worker driver uses the Node SDK in a small `automation/` shim
      (`launch()` with a fixed pre-seeded per-lane home), not raw CLI
      spawn — the SDK's permission events and structured errors are the
      certificate bridge's surface.
- [x] 3. **Governed Jcode worker lane.** Driver in `automation/` wrapped
      `--run-start` → observatory `working` → `--run-end`; bounded
      read-only task class first (same rung-18 shape as the omp lane);
      spawn depth budget declared; fail-closed on undeclared paths.
      Verification: one witnessed cycle in the run ledger; seeded stall
      auto-replaced per governed-fleet §4.
      **Progress 2026-09-14:** shim (`automation/jcode/worker.mjs`),
      wrapper (`automation/lib/launch-jcode.sh`), and hermetic tests
      (`automation/tests/test-launch-jcode.sh`, wired into the
      automation `make test` gate) landed, plus the cadence-params
      `session-executor` row documenting the `jcode` option. Live smoke
      passed (one orient turn through the shim). Remaining for this
      step: wire `launch_session`'s executor selector to dispatch
      `jcode` → `launch_jcode_worker`, then the witnessed-cycle +
      seeded-stall exit evidence.
      **Reconciliation 2026-09-14:** the executor selector was already
      wired 2026-09-13 (aa12fc1) as a direct `jcode run` CLI branch with
      zai pacing and a standalone wrapper (`lib/jcode-delegate.sh`,
      omp `hngh_jcode` tool) — the paced delegation lane. The SDK shim
      (worker.mjs + launch-jcode.sh) is the permission-safe driver the
      CLI branch lacks (deny-by-default permission bridge, pinned
      instance home); plan step 4 builds the certificate bridge on it.
      Both paths pass the automation gate. Step 3's remainder narrows
      to the witnessed-cycle + seeded-stall exit evidence.
      **Witnessed cycle 2026-09-14T18:45Z:** one bounded read-only
      delegation through `lib/jcode-delegate.sh` (zai leg, 5-min cap):
      clean rc 0, disposition cancelled, bridge run-1 closed, budget
      row `model=jcode/zai` written, and the session answered the
      orientation question correctly (queue-next node-lattice-admission).
      Remaining: seeded-stall auto-replace evidence (governed-fleet §4),
      which the watchdog respawn path owns.
      **Seeded-stall evidence 2026-09-14:** hermetic respawn test added
      (`test_jcode_stall_death_respawns_once_via_jcode_executor`): a
      jcode session death classified bad-execution (rc=124, the
      transient stall class) respawns exactly once through the one
      gated launcher with the corrective brief; suite 9/9 green.
      **Hermeticity incident (same beat):** the test suite runs under a
      live jcode session, so an inherited `HNGH_SESSION_EXECUTOR=jcode`
      made every pre-existing respawn test silently spawn a real
      `jcode run` child against the zai subscription (several stray
      legs found and killed; the env is now scrubbed per-test unless
      pinned). Lesson recorded: test envs must be scrubbed of
      executor-selection variables before asserting hermeticity.
      **SDK-shim witness + stall evidence (2026-09-14T19:00Z):** a
      parallel lane witnessed the bounded read-only SDK cycle through
      the wired `launch_session` jcode branch (budget row
      `overnight|jcode-witness | session-run | model=jcode/zai/sdk`,
      rc 0, correct read-only answer, log
      `automation/logs/overnight-jcode-witness-*.log`), and the
      seeded-stall auto-replace ran against the live supervision stack
      (real close-run dead + real `auto-replace` run-start, stubbed
      report queue; landed `agent-supervision` default-path fix).
- [x] 4. **Permission bridge.** `permission_request` events routed to the
      certificate loop: default deny; allow only against a live mutation
      certificate naming the action class; `autoApprove` forbidden
      outside certificate-scoped lanes. Verification: forced permission
      request in an uncertified lane is denied and logged; certified lane
      allows exactly the named action.
      **Verified 2026-09-14:** `lib/launch-jcode.sh` refuses
      `JCODE_WORKER_APPROVE=1` unless a readable `JCODE_WORKER_CERT`
      scope file (JSON `{"actions": [...], "expires": "<ISO-8601>"}`)
      parses, declares a non-empty action list, and is unexpired —
      rc 75 before any child spawns. `jcode/worker.mjs` re-validates the
      scope (defense in depth), denies every `permission_request` in an
      uncertified lane (never parks), allows exactly the tool names in
      the certified action list, and writes an allow/deny audit line to
      stderr per decision; blanket `autoApprove` is gone from the run
      path. `tests/test-launch-jcode.sh` cases 8-13 (approve-without-cert
      / expired / malformed / empty-actions -> 75; valid cert passes;
      audit-line source greps) green inside the automation `make test`
      gate (rc 0). Commit 4eaf1f0 (changelog 485a0a2).
- [x] 5. **Observatory surface.** Nerve-center Sessions preview of Jcode
      sessions via `connect()`/`peekSession`. Verification: preview
      renders a live session transcript without attaching.
      **Witnessed 2026-09-14:** already landed by the universal
      session-registration commit (aa12fc1, 2026-09-13):
      `sessions-feed.py jcode_rows` reads `~/.jcode/sessions/`
      transcripts (fixture-first tests, 6/6 green) and the live feed
      returned 24 jcode rows on witness. Note: file-transcript parsing
      was chosen over a live `connect()` bridge — read-only, no
      daemon dependency, same preview-without-disturb property.
- [x] 6. **Config lane + installer option.** `~/.jcode` declared in the
      governed-fleet config lanes on the 30m cadence; Hngh installer
      gains a Jcode install option (deferred to the OS-harness
      installer-skeleton rung, 2026-09-11 ladder). Verification: config
      lane lands in the cadence matrix; installer option specified (not
      necessarily built).
      **Landed 2026-09-14:** `config-lanes.tsv` agent-configs lane now
      carries `.jcode/config.toml`; new `jcode-skills` lane covers
      `.jcode/skills` + `.jcode/mcp.json`; all lane sources verified
      present on the host; cadence wiring (30m/20-config-backup)
      unchanged and picks the rows up automatically. Installer option
      remains specified-not-built, per the OS-harness ladder trigger.
      **Bootstrap check landed 2026-09-14 (d1c3933):** `bootstrap.sh
      --check/--install` now reports jcode as an optional harness
      (presence + version, or degradation note plus the three operator
      install routes); never auto-installed — the official installer is
      curl|bash, which bootstrap doctrine forbids. The interactive
      installer-option rung itself stays behind the OS-harness ladder.
- [x] 7. **Omp coexistence review.** Inventory omp surfaces vs Jcode
      equivalents; retirement is a named record per surface, never a
      default. Verification: inventory table in a record.
      **Landed 2026-09-14:** `docs/records/2026-09-14-omp-coexistence-review.md`.
      Disposition: no retirement yet — gaps named (spend pacing, plan
      proposal, lessons append) with retirement order for when they
      close; MCP and observatory are shared surfaces that never retire.

## Priority

Steps 1-2 precede discretionary queue work (operator directive 2026-09-14).
Steps 3-4 double as governed-fleet stage-3 exit evidence (one witnessed
delegation cycle with a seeded stall auto-replaced), so they advance stage
3 rather than preempt it.
