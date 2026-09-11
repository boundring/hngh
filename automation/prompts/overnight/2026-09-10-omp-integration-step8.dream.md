# Dream pre-flight: step 8 context-seeding (omp-hngh integration)

Dream pass per docs/research/2026-09-10-forethought-and-decomposition.md section 2.
Read-only simulation; no code changed. Doc evidence: omp://extensions.md (read
2026-09-10) + one bounded print-mode probe (see section 5).

## Requirements

- Plan step 8 (verbatim): "Context-seeding: make `omp-bridge --orient` run
  automatically for every omp session entering this repo (extension
  session-lifecycle event in the `hngh-bridge` plugin, or a rulebook
  `condition` rule if events cannot inject). Orientation output stays
  read-only and small."
- Every omp session entering the repo receives the orient brief with no
  operator action; logs show ONE orient call per session start (dedup).
- Output read-only: orient runs with no flags that mutate; injected content
  must not trigger writes.
- Small: measured `scripts/omp-bridge --orient` = 14 lines / 377 bytes
  (2026-09-11 probe). Bound stays <= ~1 KiB.
- Mechanism per omp://extensions.md: `pi.on("session_start", handler)`
  (event surface, "Session lifecycle" section); inject via
  `pi.sendUserMessage(brief, { deliverAs: "nextTurn" })` or
  `pi.appendEntry("com.hngh.orient", data)`.
- Pitfall (omp://extensions.md:62-66, 734): runtime action methods
  (sendMessage etc.) THROW during extension load
  (`ExtensionRuntimeNotInitializedError`) -- orient call must live inside
  the session_start handler, never the factory body.
- Pitfall (lines 220-241, 251): extensions run in-process with no
  isolation; use ctx.setTimeout for the bounded spawn or fail-open.
- Pitfall (lines 592-594): print/headless/subagent paths give ctx.hasUI
  false and ctx.ui methods no-op -- ride the message/entry path, never
  ctx.ui.

## Capability verdict (doc evidence + probe)

- `session_start` exists and is a registered extension event
  (omp://extensions.md:77-79, 279) -- capability real, not assumed.
- Print mode: docs only document `ctx.hasUI == false` with no-op ctx.ui
  (lines 592-594); whether session_start fires in `omp -p` was flagged
  UNVERIFIED by the design doc. The one authorized probe settles it:

  `omp -p -e /tmp/dream-probe.ts` (temp extension, session_start handler
  appends to /tmp/dream-probe-marker, timeout 30): marker written
  `fired hasUI=false cwd=/tmp`, exit 0, 6.4 s.

  VERDICT: print mode DOES fire session_start. No rulebook fallback needed;
  keep the rulebook `condition` rule only as the named fallback if a
  future omp version changes behavior (plan's conditional already encodes
  this).

## Failure modes

- [missing-design] ctx.ui no-op in print mode: orient brief routed through
  ctx.ui.notify silently vanishes in `omp -p`. Check: probe asserts the
  brief reaches the message/entry path (sendUserMessage/appendEntry), never
  ctx.ui.
- [missing-design] load-time throw: orient call placed in factory body
  throws ExtensionRuntimeNotInitializedError, plugin fails to load.
  Check: action calls live inside the session_start handler; a load smoke
  (`omp --no-extensions` diff vs normal load, or plugin list) shows no
  load error.
- [bridge-refused] orient subprocess nonzero (house exit 1/2/3), missing
  python3, or scripts/omp-bridge absent from cwd -- must not break or log-
  spam session startup. Check: handler try/catch fail-open; kill the bridge
  path in a scratch test and confirm session still starts, single error log.
- [loop-recognition] dedup: session_start (or resume/branch in the
  session_before_switch family) re-fires and re-orients every turn/switch,
  burning context. Check: guard to one orient per session (per-session
  flag via pi.appendEntry state, see omp://extensions.md:601-623
  reconstruction pattern); listen to session_start ONLY, not the
  before_switch family; logs show exactly one orient per fresh session.
- [slow-unit] orient subprocess hang (bash, python import stalls) blocks
  the in-process start path -- the whole session hangs. Check: bounded
  spawn (ctx.setTimeout or exec timeout signal, ~10 s, fail-open);
  measure orient wall time (0.19 s observed) and assert headroom.
- [missing-authority] plugin file lives OUTSIDE the repo
  (~/.omp/plugins/hngh-bridge): executor may lack authority/commit path
  there. Check: confirm edit surface is the deployed plugin dir; record
  deployment in the plan's verify, not a repo commit.
- [obsolete] cwd gating: plugin is global; orient must fire only for THIS
  repo (cwd or ~/Projects/etc/hngh), else every omp session anywhere gets
  spammed. Check: gate on ctx.cwd matching the repo root before spawning;
  probe from a foreign cwd shows no orient.

## Surfaces

- ~/.omp/plugins/hngh-bridge/src/index.ts -- currently a CustomToolFactory
  only (hngh_propose; no lifecycle hooks registered yet; repo root via
  bridgeCandidates(cwd) = [cwd, ~/Projects/etc/hngh], existsSync-filtered).
  Step 8 adds `pi.on("session_start", ...)` registration alongside.
- ~/.omp/plugins/hngh-bridge/package.json -- manifest currently declares
  only tools ("pi.tools"/"omp.tools"); extension entry discovery for
  plugins uses omp.extensions/pi.extensions entries
  (omp://extension-loading.md:51-57) -- verify the plugin's tool entry
  already loads through the extension pipeline (it does: tools are an
  extension capability) and whether a separate extensions entry is needed.
- scripts/omp-bridge --orient -- read-only subprocess; 14 lines / 377 B
  output, 0.19 s wall.
- Timeout seam: the orient spawn inside the handler (ctx.setTimeout or
  signal with ~10 s budget), not global config.
- Fallback surface (only if capability verdict had been no): a rulebook
  `condition` rule in .omp/rules/ -- NOT needed per probe; do not write it.
- Tests: repo has no plugin tests (plugin is repo-external); verification
  is the fresh-session orient observation named in the plan, plus a
  foreign-cwd no-orient check.

## Split

1. **Capability probe (done by this dream; executor re-confirms with the
   real inject API).** Minimal session_start handler using
   sendUserMessage(..., {deliverAs: "nextTurn"}) -- ONE bounded `omp -p`
   probe (timeout 30) asserting the entry/brief appears. SERIALIZES
   everything: its outcome selects extension-event vs rulebook surface.
2. **Real orient wiring.** session_start handler: cwd gate -> spawn
   `scripts/omp-bridge --orient` (bounded ~10 s, fail-open try/catch) ->
   sendUserMessage/appendEntry the brief. Serial after (1) -- same file,
   depends on the chosen surface.
3. **Dedup + hardening.** One-orient-per-session guard (appendEntry state
   or per-process flag), foreign-cwd no-op check, log line per orient.
   Serial after (2) -- same file, same handler.

All three touch one file (plugin src/index.ts) -> fully serial. No
parallel lanes; the step is one small patch, the risk is capability, and
the capability is now settled.

## Sanity-checks (executor verifies BEFORE first edit)

1. Print-mode session_start firing CONFIRMED (this dream's probe: fired,
   hasUI=false; re-run one bounded probe with the real inject API before
   any wiring is written). Fallback (rulebook condition rule) only if this
   fails.
2. Orient output <= 1024 bytes (measured 377 B) and exit 0 with no args
   that mutate; `python3 scripts/omp-bridge --orient` runs clean from repo
   root.
3. No daemon, no background process spawned by the handler; orient is one
   synchronous bounded subprocess per session start.
4. Orient call sits inside the session_start handler, never the factory
   body (load-time throw pitfall).
5. cwd gate proven: a session in a foreign directory emits no orient call.
6. Dedup proven: one fresh `omp -p` session -> exactly one orient log
   line.
7. Timeout proven: with the bridge path broken or hung, session still
   starts within the bound (fail-open beats fail-hung).
