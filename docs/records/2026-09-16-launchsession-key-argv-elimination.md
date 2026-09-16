# 2026-09-16 — launch-session opencode branch: provider key never on
# an argv (e1 finding #3)

## The finding

The opencode executor branch of `automation/lib/launch-session.sh`
spawned the child as

```
env "$key_arg" OPENCODE_CONFIG=... timeout "$TIMEOUT_S" "$oc_bin" ...
```

with `key_arg="OPENCODE_API_KEY=<value>"` (and the per-provider
`KIMI_API_KEY=` / `ZAI_API_KEY=` variants). That placed the provider key
VALUE on `/usr/bin/env(1)`'s argv.

Severity framing (gate's dynamic probe, correcting e1): `/proc/<pid>/`
`cmdline` shows the assignment only for env(1)'s brief pre-exec
lifetime — env(1) applies assignments to its own environment and execs
with a clean argv, so the child never carries the secret on argv. The
exposure window is per spawn, not the spawn lifetime. It is nevertheless
a real argv transit of a credential and a regression against the
documented seam: the branch's own comments and
`automation/lib/ocgo-delegate.sh` ("child sees KIMI_API_KEY only",
"env-only") promise the value reaches the child through the environment,
never as a command-line word.

## Decision

The spawn is now a LITERAL shell prefix assignment per provider:

```
KIMI_API_KEY="$oc_key" \
  OPENCODE_CONFIG="..." \
  "${oc_cmd[@]}" >"$ROOT/$log.json" 2>&1
```

with the command (timeout, oc_bin, flags, body) built once into the
array `oc_cmd`. Two properties make this correct:

1. A prefix assignment puts the value straight into the child's
   environment; no intermediate process exists, so no argv ever carries
   the secret. (Verified in the gate's dynamic probe: the child's argv
   is clean from process start.)
2. Quoted array words (`"${oc_cmd[@]}"`) are never re-parsed as
   assignments, so only the literal prefix is an assignment. The
   previous design temptation — passing `KEY=VALUE` as an expanded
   word to env(1) or to a helper's `"$@"` — is exactly what fails:
   expanded words are inert data, not assignments.

Rejected alternatives:

- `env KEY=VALUE ...` (the bug): argv transit, fixed here.
- A subshell `( export KEY=...; exec ... )`: keeps argv clean but
  forks; and any export-based scheme that leaks into the launcher's own
  shell would mutate the environment shared by the other legs (omp,
  jcode) in the same process.

## Test

`automation/tests/test-ocgo-launch.py` gains an `ENV_STUB` on the
sandbox PATH that records env(1)'s argv verbatim (the only observable
surface of the leak) and faithfully emulates env(1)'s contract
(`NAME=VALUE` words exported, `-u NAME` unset, `--`), then execs — so
the oc stub still runs under it exactly like under the real env binary.
`OcgoLaunch._assert_key_never_on_argv` drives all three provider legs
(opencode-go via a 600 key file, kimi via `KIMI_AI_KEY`, zai via
`Z_AI_API_KEY`) and asserts:

- the key VALUE appears on no argv anywhere (env stub's recorded argv,
  child argv dump);
- the key still REACHES the child environment (length probes
  `keylen=` / `kimilen=` / `zailen=`) — the guard must not break
  delivery.

Test-first: with the old `env "$key_arg"` spawn temporarily restored,
all three tests fail on `envargv=...KIMI_API_KEY=kkkk...` (red); with
the prefix assignment they pass (green). Full automation gate run
before commit.

## Scope

`automation/lib/launch-session.sh` (spawn only; branch wiring,
pacing, bili wrap, attribution untouched),
`automation/tests/test-ocgo-launch.py` (stub + three tests),
`CHANGELOG.md`.
