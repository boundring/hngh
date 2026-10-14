# 2026-10-14 — MiniMax becomes an hngh quota leg (99-QUESTIONS.md Q4)

## What shipped

`minimax_chat` in `automation/lib/model.sh`, `_minimax_leg` as its wrapper,
three rows in `automation/cadence-params.tsv` (`minimax-endpoint`,
`minimax-model`, `minimax-cap-day`), a row in
`automation/config/leg-budgets.tsv`, a `sweep_seam minimax` registration in
`automation/jobs/credential-health.sh`, and seam tests in
`automation/tests/test-model-loadctx.sh`.

**The leg ships UNARMED.** No credential was moved into hngh's namespace in
this session, and none should be inferred from the row existing. See
"Deliberately not done" below.

## The question

99-QUESTIONS.md:69-73, verbatim:

> **§3.2 — should hngh be able to call MiniMax at all?** The oh-my-pi side
> is done. The hngh side needs a `_minimax_leg` in `lib/model.sh` **and** a
> cap row in `automation/cadence-params.tsv` **in the same commit**, because
> the pacer fails open on a missing cap. If the answer is 'no, oh-my-pi is
> the only MiniMax caller', say so and the work is simply not done.

The question is now answered by construction: hngh **can** call MiniMax, and
the code is in place. Whether it **should** spend is the operator's, and it
currently spends nothing.

## Where it sits in the ladder

`zai -> xiaomi -> ocgo -> kimi -> minimax -> remote -> ollama -> deck`.

After the three proven quota legs, before budget-gated paid OpenRouter. The
reasoning is a risk argument, not a cost ranking: a provider that has never
run through this chain must not displace quota capacity already being spent,
but provider-credit legs belong ahead of paid-per-token remote. Unarmed, the
leg costs one `stat` per call and falls through.

No `MODEL_PIN=minimax` value exists, matching xiaomi, the other unpinned-tier
quota leg.

## Measured provider facts (live API, 2026-10-14)

Verified with the oh-my-pi credential. Three findings changed the
implementation, and two of them are the kind that a code review would not
have caught.

**1. The credential is live, and it was reported dead four weeks ago.**
`GET https://api.minimax.io/v1/models` returns HTTP 200 with `MiniMax-M3`,
`MiniMax-M2.7`, `MiniMax-M2.7-highspeed`, `MiniMax-M2.5`,
`MiniMax-M2.5-highspeed`. But `docs/records/2026-09-21-vault-cutover-freshness.md:42`
lists MINIMAX among "5 dead (ELEVENLABS, MOONSHOTAI, KIMI_AI, AGENT_MAIL,
MINIMAX — all 401)". Do not cite that 401 as current: the key has been
rotated or reissued since.

**2. MiniMax-M3 inlines its reasoning into the completion, and ignores the
cross-provider thinking flag.** With `chat_template_kwargs.enable_thinking:
false` — the flag `_json_body` already emitted — the reply came back as:

```
<think>
The user is asking me to say "ok". This is a simple
```

with `completion_tokens: 8`, all of it reasoning, and **no answer**. So the
existing helper argument is not a cross-provider switch. The same request
with the provider's own `{"thinking":{"type":"disabled"}}` returned `"ok"`
with `completion_tokens: 1`.

This is why `_json_body` grew a 6th argument (`native_think`), defaulting to
`0` so no existing caller's request body changes. The naive alternative —
reusing the existing thinking argument — would have shipped a leg that
quietly returns only reasoning traces into hngh's documents.

**3. The `<think>` strip that looks correct is a silent no-op on jq 1.8.2.**
Measured on this box:

| filter | result on `"<think>\nabc\n</think>\nxy"` |
|---|---|
| `test("^\\s*<think>")` | `true` |
| `sub("^\\s*<think>.*?</think>\\s*"; "")` | unchanged |
| `sub("^\\s*<think>.*</think>\\s*"; "")` | unchanged |
| `sub("^\\s*<think>[^<]*</think>\\s*"; "")` | `"xy"` |

`test()` agrees with a pattern that `sub()` will not act on, so a
reviewer checking that the guard matched would have seen a green test and
shipped a no-op. The leg uses `[^<]*`. This is recorded in the code comment
at `lib/model.sh:1068-1075` because it is not a discoverable fact.

## Four things the test suite caught that reading did not

Every one of these would have shipped broken.

1. **`$6` unbound under `set -u`.** The test harness runs with `set -u`, and
   the five existing callers (`unsloth_chat`, `ollama_chat`, `remote_chat`,
   `deck_chat`, `xiaomi_chat`) all pass exactly five arguments. A bare `$6`
   broke all of them. Fixed to `${6:-0}`.
2. **Double-escaped jq.** The filter lives in bash single quotes, so `\\s`
   in the file reaches jq as `\s`, which is right — but the first draft
   wrote `\\\\s`. The strip assertion failed and showed the raw `<think>`
   block still in the reply.
3. **A missing leg-budget row.** `tests/test-leg-budgets.py` derives the
   required leg set from the `<name>_chat()` definitions in `model.sh` and
   fails any leg without a row in `automation/config/leg-budgets.tsv`. This
   guard exists precisely to stop an un-budgeted leg entering the chain, and
   it fired on the new leg exactly as designed. Row added at
   `leg-budgets.tsv:37`.
4. **`shellcheck` noise is pre-existing.** The four warnings on the touched
   files are identical before and after (verified by stashing the diff and
   re-running: 7 finding locations both ways). None are from this change.

## Deliberately not done

The credential was **not** copied into hngh's namespace. The live key lives in
`~/.config/omp/agent.env` (mode 600), which exports both `MINIMAX_API_KEY` and
`MINIMAX_CODE_API_KEY` with the same value; `~/.config/jcode/minimax.env`
carries a differently-named variable (`MINIMAX_IO_API_KEY`) under the same
key prefix. There is no `minimax` entry in `~/.hngh-automation/`,
`~/.config/hngh`, or `~/.config/environment.d/`, and no systemd unit
references one.

Copying a working credential between namespaces is the operator's line, and
`automation/lib/secrets.py:34`'s `'MINIMAX_API_KEY': 'MiniMax'` is a
secret-scanner LABEL mapping, not a seam. The three options put to the
operator:

1. Token-only seam at `~/.hngh-automation/minimax.token`, mode 600, matching
   the `~/.config/hngh/zai-key` convention and the token-only credential-seam
   rule. **Recommended.**
2. Wire it fail-closed with no credential — which is what this commit ships.
3. Declare oh-my-pi the only MiniMax caller and do not do the work at all.

Also undecided, and flagged in the cap row: `minimax-cap-day 40` is the
quota lane's established default, chosen because MiniMax meters prompt +
completion tokens against an account balance rather than call count. **A call
cap is a spend proxy.** It should be recalibrated once the leg is armed.

## Verification

- `automation/tests/test-model-loadctx.sh` — all cases pass, including the
  new minimax block (fail-closed when unarmed, one POST when armed, native
  thinking flag in the body, `<think>` stripped from the reply, key never on
  a curl or report-queue argv, cap 0 blocks).
- `automation/tests/test-quota-routing.sh` — ALL PASS.
- `automation/tests/test-model-pin-routing.sh` — all pass.
- `automation/tests/test-credential-health-argv.sh` — all pass.
- `automation/tests/test-leg-budgets.py` — 5 tests, OK.
- `cd automation && make test` — exit 0, 4m54s.
- `make test` (kernel) — exit 0, 2957 checks.
- `python3 automation/scripts/lint-home-paths.py` — clean.