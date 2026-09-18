# G2 telemetry-vs-STATE.md reconciliation (2026-09-18)

Ground truth: `automation/STATE.md` (120,065 lines; breadcrumb ledger).
Telemetry: `~/.hngh/db/telemetry.db`, table `events` (kind=model rows only).
No live kimi probe was run.

## Reconciliation table (STATE.md as ground truth)

| source | telemetry kind=model rows | STATE.md ledger signal | verdict |
|---|---|---|---|
| unsloth | 1249 (2026-09-08T18:01:44Z .. 2026-09-18T22:34:45Z; newest `33-research-beat.sh` / `unsloth/Qwen3.8-27B-GGUF`) | NO success breadcrumb exists: 1440 `| model | unsloth` rows are all retry/fail markers (e.g. `automation/STATE.md:211` first empty-content retry, `automation/STATE.md:120041` latest). Success is silent on the ledger. | Telemetry is the ONLY success counter. Keep `_model_emit unsloth` as-is (model.sh:970,982). Optional: add one success breadcrumb per call. |
| kimi | 199 (2026-09-08T04:01:51Z .. 2026-09-16T07:49:27Z; newest `33-research-beat.sh` / `k3-256k`) | NO success breadcrumb: 610 `| model | kimi` rows are 403/400/defer/fail markers (e.g. `automation/STATE.md:76382` first 403 in sample, `automation/STATE.md:120052` latest 403). Ledger goes 403-only after 2026-09-16 while telemetry stops at 2026-09-16T07:49:27Z. Consistent: key dead, no successful calls to emit. | No correction to `_model_emit kimi` (model.sh:745). Ledger and telemetry agree the leg is dead. |
| zai | 40 (2026-09-14T05:35:19Z .. 2026-09-18T21:04:22Z) | 1032 served-success markers (`served via bili proxy` / `served direct`; e.g. `automation/STATE.md:60790-60791` first pair, `automation/STATE.md:119897-119898` latest pair) vs 40 telemetry rows = ~26 ledger successes per telemetry row. Markers fire per attempt inside `zai_chat` (model.sh:827,843); `_model_emit zai` fires once per successful leg (model.sh:856). | UNDER-COUNT in telemetry relative to ledger success markers, but markers are per-attempt (proxy then direct fallback can double-emit per call: note paired identical timestamps at 60790-60791). Verdict: do NOT "correct" `_model_emit` upward; instead treat ledger served-markers as attempt-level and telemetry as call-level. Optional fix: dedupe paired served markers. |
| ocgo | 10 (2026-09-14 .. 2026-09-16) | 14 `| model | ocgo` rows, all defer/HTTP markers; no success breadcrumb. | Consistent with low call volume. No correction (model.sh:757). |
| ocgo-agent | 118 (2026-09-11 .. 2026-09-17) | No `_model_emit ocgo-agent` call site in model.sh (only pace-window accounting at model.sh:552-564,702); rows attributed externally (executor-internal spend). | No correction inside `_model_emit`; attribution lives outside model.sh. |
| ollama | 6 | 5 `| model | ollama` rows. | Roughly consistent. No correction (model.sh:1005). |
| deck | 0 (by design: no emit) | 23 `| model | deck` rows (HTTP markers). | Consistent by design: `_deck_leg` emits no telemetry (model.sh:858-866 comment). No correction. |
| remote/openrouter | counted under source=remote via `_model_emit remote` (model.sh:908,921,999); lobehub 2 | 2 `| model | remote` rows. | No correction. |

## Verdict on correcting `_model_emit` (model.sh:714-741)

Do NOT change emit counts. The apparent gaps are category mismatches, not
under-emission: STATE.md `| model |` rows are dominated by per-attempt
diagnostic breadcrumbs (retries, HTTP codes, pace defers), while `_model_emit`
writes exactly one kind=model row per successful call. The two real
observations: (a) unsloth/kimi successes are ledger-silent, so telemetry is
the only success record; (b) zai served-markers double-fire per call
(paired timestamps), so the ledger over-counts calls ~26x, not telemetry
under-counting. If a follow-up is wanted: add a single success breadcrumb at
each `_model_emit` site, and dedupe the zai paired served markers. Neither
changes `_model_emit` itself.
