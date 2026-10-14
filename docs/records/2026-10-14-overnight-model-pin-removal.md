# 2026-10-14 — the OVERNIGHT_MODEL pin is removed

## What was removed

The `OVERNIGHT_MODEL` environment override and the `|env` rung of
`select_model`. Operator decision, 2026-10-14: the concept was leftover from
hngh's earlier development and had outlived its purpose.

## Why it went

The pin was a legitimate cost lever when it was written. A drop-in carried
"operator authorization 2026-09-09: prefer GLM 5.3 Flash for cost", and
`docs/research/2026-09-10-cost-landscape.md:129` credits it with the spend
trajectory falling from $10.9/day to roughly $0.5/day. Three measurements on
2026-10-14 say the lever had stopped working while continuing to look
authoritative.

**1. The pinned value was discarded before the call.**
`automation/scripts/overnight-cycle.sh` set `SESSION_MODEL` from the pin, but
`automation/lib/launch-session.sh:315-318` prefers the opencode-go route and
takes its model from `cadence-params.tsv` (`opencode-model`), overwriting
`SESSION_MODEL` without restoring it. `SESSION_MODEL` survives only on the
omp fallback path (`:418`, `:496`, `:501`, `:504`). Two of our own logs
disagree about the same session, written in the same minute:

```
automation/agent-handoffs.md:6723  model=openrouter/z-ai/glm-5.3-flash(env)
automation/logs/budget.md:809      model=opencode-go/glm-5.3-flash | source=env
```

(slug `2026-09-16-routed-ui-audit-axe-color-contrast-3|run-1`, 2026-10-14T12:42:05Z).
So did the attribution: 206 `source=env` rows in `automation/logs/budget.md`
were all served by the opencode-go quota leg, because `launch-session.sh`
sets an explicit `--source` for the kimi and zai legs and nothing for
opencode-go, so `ocgo-attribution.py:202` falls back to its `ocgo-agent`
default. This is the same seam as the earlier attribution finding, and
removing the pin removes one of its two causes.

**2. It shadowed the whole ladder while being shadowed itself.** The `|env`
rung returned before the bench rung (`:188`), the quota rung (`:206`) and
the paid fallback (`:234`). `docs/research/2026-09-10-morning-observation.md:138`
already observed that "Bench branch execution requires ENV ABSENCE, which
does not occur under current config", and `:164` called the daily bench
"harmless dead-weight computation". The bench was in fact alive — the
2026-10-14 run benched 7 models in 21min31s and produced three 5/5 rows —
so the pin was suppressing a working, free rung in favour of a paid one.

**3. The pinned leg had no credential.** No OpenRouter key exists anywhere
in the automation userspace (`~/.hngh-automation/`, `~/.config/hngh`,
`~/.config/environment.d/`). The only file is `~/.config/jcode/openrouter.env`,
which belongs to jcode's own tooling. The omp fallback path for that slug
had no key behind it, and the 25 sessions that fell through to
`|env-all-demoted` in `automation/logs/budget.md` were failures —
`automation/agent-handoffs.md:6526` records `rc=127`, command not found.
(Not attributed: 2026-10-13 was the shim-relocation day, so a missing
binary is at least as likely a cause. Unverified either way.)

## What the ladder does now

With no env rung, T1 pins `local-bench`, T2 walks quota row > local-bench >
paid fallback, T3 leaves the ladder alone and files its operator-item.
Measured with the pin still in place, the rung that was being shadowed and
is now reachable: `automation/stats/model-bench-2026-10-14.jsonl` carries
three 5/5 rows, and with `unsloth/Ornith-1.0-9B-GGUF` demoted,
`best_bench_model` returns `bartowski/Qwen3.8-27B-GGUF` — local, free. The
quota rung is armed off (`session-model-quota-keys=0`), so in practice
T2 resolves to that local bench model unless the operator arms a quota
preference row. Strictly cheaper than the slug it replaces.

`OVERNIGHT_PAID_MODEL` is untouched and still the paid-fallback knob.
`MODEL_PIN` is a different, live concept (the research rotation, set by
`automation/cadence/hour/33-research-beat.sh`) and was not touched.

## The guards had to be inverted, not deleted

`automation/tests/test-unit-model-env.sh` asserted that every unit able to
reach `overnight-cycle.sh` *did* carry the env — it existed to prevent the
2026-09-10 flap, where one unit had the drop-in and a workbeat session
silently fell to a different model. That failure mode is now structurally
impossible: there is no lane-dependent env left to drop. The guard asserts
the inverse (no unit re-pins, and the selector does not read the variable),
so the concept cannot creep back through a unit file. The two
`test-quota-routing.sh` cases that asserted env precedence now assert that a
stale export is inert. Two `run_cycle` tests had passed
`OVERNIGHT_MODEL="stub-model"`; that stub is gone.

## What was left alone, and why

`docs/research/2026-09-10-*.md` and the `docs/project/plans/*.plan.md`
entries that mention the pin are dated observations of what was true then
and are left as history. Only the two normative design docs
(`docs/design/cost-tiering.md`, `docs/design/value-add-routing.md`) claimed
env precedence as current policy, and those were corrected.

## Not done here

`automation/logs/budget.md` and `automation/agent-handoffs.md` still carry
`env` and `env-all-demoted` rows from before this change. Rewriting
historical log rows is not worth the audit damage. Anyone reading the
`source=` column should know that `env` there meant "the pin was set",
which after 2026-10-14T19:2xZ did not mean "this session ran that model".
