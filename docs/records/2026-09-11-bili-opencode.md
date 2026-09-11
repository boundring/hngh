# 2026-09-11 - bili compression on the opencode executor (clobber-safe integration)

## Question

Operator directive: "Let's get bili working with opencode, 100% support for
this. Delegate for it, prevent clobbering." Expected win (per
2026-09-11-ocgo-cost-tuning.md VIABLE-NEXT): the 391k cache-read tokens
(~35% of session cost) plus the cache-miss re-bills - the part prompt
discipline cannot reach.

## Clobber analysis (what `bili opencode` does to config) - evidence

`bili opencode` (billion-context 0.1.106 launcher) does three things, read
from the installed bundle (`~/.npm-global/bin/bili`, esbuild-dist source):

1. It spawns a fresh proxy and runs opencode with
   `HTTPS_PROXY + NODE_EXTRA_CA_CERTS + BILLION_CONTEXT_PROXY` (cert-MITM).
2. `resolveOpencodeConfigFile(env)` HONORS the inherited OPENCODE_CONFIG -
   bili reads our pinned
   `automation/config/opencode/opencode.jsonc` for upstream discovery.
3. `prepareOpencodeHttpRewrite` (bundle lines 66409-66444) seeds the temp
   config with a **strict `JSON.parse` of that same file** (66413-66414),
   then writes `mkdtemp("bili-opencode-")/opencode.json` and
   **replaces `env.OPENCODE_CONFIG` with the temp file** (66862).

The strict `JSON.parse` is the killer: our layer is `.jsonc` with
comments, so the parse throws, `root` stays `{}`, and the temp config the
session actually loads contains ONLY the injected `plugin` entry - the
secret-deny permission block, the executor/scout agent roles, the hngh MCP
registrations, and the small_model pin are all silently gone. That is
exactly the clobber the cost-tuning guard warned about ("must not silently
replace the hngh-owned OPENCODE_CONFIG layer"). Even with a parseable
config, the temp file would still REPLACE the pin (round-trip through
JSON.stringify, comments lost) - a merge-by-copy that depends on bili's
seeding staying correct across versions.

## Chosen shape: env-only MITM redirect (zero config writes)

launch-session.sh's opencode branch now rides a bili proxy via
environment only - nothing ever reads, rewrites, or replaces the hngh
config layer:

- Reuse a healthy proxy on `BILI_OCGO_PORT` (default 8787,
  `/__bili/health`); else spawn `bili start --host 127.0.0.1 --port N`
  with `BILI_MITM_DOMAINS=opencode.ai` (log:
  `$ROOT/logs/bili-ocgo-<ts>.log`), killed after the run.
- When wrapped, the child gets `HTTPS_PROXY` +
  `NODE_EXTRA_CA_CERTS=$XDG_DATA_HOME[:~/.local/share]/billion-context/ca/root-ca.pem`
  (the same CA file the upstream launcher hands to opencode;
  `resolveCaCertPath`). When NOT wrapped, any ambient
  HTTPS_PROXY/NODE_EXTRA_CA_CERTS inherited from a bili-wrapped parent is
  unset - a stale proxy env from a dying bili parent would otherwise
  break every direct session's fetch.
- Fail-open exactly like the omp branch: bili absent, proxy unreachable
  after ~10s of health probes, or the CA pem missing -> direct
  uncompressed launch with a visible `ocgo-executor` breadcrumb. The
  timeout stays OUTSIDE (timeout -> opencode directly; bili is a sidecar
  process, so exit-code and stdout/stderr semantics are untouched by
  construction - `--format json` and the R2 emitter flow unchanged).
- opencode itself is untouched: the built-in `opencode-go` provider keeps
  its own endpoint (`https://opencode.ai/zen/go/v1/chat/completions`,
  sink-probe verified), auth, and the mandatory session header; the proxy
  intercepts `opencode.ai` TLS only.

Why this shape cannot clobber: no file is ever read-and-rewritten, no temp
config exists, and no process wraps the client. The hngh layer is in
effect by construction - `OPENCODE_CONFIG` still pins the committed
`.jsonc` byte-for-byte (test: checksum unchanged after a wrapped run).

## Compression measurement (one real session, verified)

Probe session via the production launch path (`launch_session`,
executor=opencode, 2026-09-11T20:16Z, store
/tmp/bili-verify-store, rc=0, cause=unknown, ~8s):

- Tokens: 26,369 in / 73 out; cost $0.00475 (telemetry row `ocgo-agent`,
  identity `ses_f6de2c920ffeWQVF7LypSYJPMJ` - the emitter attributed the
  bili-wrapped session unchanged).
- bili log (`$ROOT/logs/bili-ocgo-20260911T161621.log`): MITM whitelist
  `+opencode.ai`, one `processTurn` line per request, upstream
  `forward POST -> /zen/go/v1/chat/completions`, context window resolved
  (968,000 tokens for glm-5.3-flash), session id derived from opencode's
  own session header, `[acp-usage] round 1 input=25557 cached=0`, then
  `round 1 input=26156 cached=25344 (cache hit 97%)` - bili synthesizes
  the `x-session-id` routing so upstream prefix caching already hits
  97% on turn 2.
- Compression itself did NOT trigger on the probe: usage 25,557/968,000
  = 3%, growth below bili's 20k floor ("max compressible 0 < threshold
  20000"). Honest read: a ~26k probe cannot demonstrate the 391k
  cache-read reduction; the expected win lands on long sessions (the
  same proxy + session identity serves them once engaged). The fresh
  input of this probe is dominated by the context pack, so it is not
  comparable to session 2's 144k baseline - what IS proven: the wire
  path, session identity, cache routing, and cost attribution all work
  through bili.
- The hngh config layer was in effect: `opencode debug config` under the
  exact launch env (OPENCODE_CONFIG pin) resolves the full layer - the
  copied secret-deny `permission.read` block verbatim, agents
  executor + hngh-scout, mcp hngh/misakanet/codegraph, small_model
  unsloth-local pin, model opencode-go/glm-5.3-flash.

## Incidental root-cause fix

`launch_store` was called without its slug argument at the launch-session
call site - a bare call loses the caller's positionals under `set -u`
(common.sh forces it), silently voiding the per-launch store dir and
falling back to the shared default store -> record-conflict refusals
(rc=75). Caught live by this verification run (first launch refused
rc=75); fixed by passing `"$slug"`.

## Residual risks

- A reused (operator-daemon) proxy may lack `opencode.ai` in its MITM
  whitelist - sessions then run uncompressed-but-working (blind tunnel);
  self-spawned proxies always whitelist it.
- Two bili instances share the sessions directory (bili warns #394) -
  the operator's own proxy on 40097 coexists; state isolation is per
  session id, so cross-talk is bounded.
- The spawned proxy's auto-update check runs inside the proxy process
  (ACP_AUTO_UPDATE untouched) - it can npm-install mid-session; the
  running process keeps the old code until restart.
- Compression effectiveness on long opencode sessions is asserted by
  proxy-mode semantics (server-side fold + `acp_summary` carrier), not
  yet measured on a real 100k+ session - next long session should be
  read off `[acp-usage]` lines in the bili log before claiming the
  391k-token win.

## Tests

- New in `tests/test-ocgo-launch.py`: bili present -> child runs under
  `HTTPS_PROXY` + `NODE_EXTRA_CA_CERTS` with the spawned stub proxy
  killed after the run and the config file byte-identical; exit-code
  passthrough under the wrap (rc=1 rides to LAUNCH_RC); bili absent ->
  `proxy=` empty with an ambient stale proxy env stripped from the
  child. Existing 12 tests unchanged and green.
- `make test` green (incl. lint-identifiers: HTTPS_PROXY /
  NODE_EXTRA_CA_CERTS / BILI_MITM_DOMAINS added to the env-contract
  ignore list, same class as the pre-existing OPENCODE_CONFIG entry).