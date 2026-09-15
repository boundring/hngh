# Does the hngh kernels reconciliation loop currently handle a "timeout_complete" state by triggering a retry, or does it require a new handler branch?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-hngh-kernels-reconciliation-loo`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-hngh-kernels-reconciliation-loo.md.

# research beat 2026-09-15 (contraction — final crystallization)

_line: Does the hngh kernels reconciliation loop currently handle a "timeout_complete" state by triggering a retry, or does it require a new handler branch? | state: contracting → crystallized | prior model: zai:glm-5.3 | this transition: claude_

## Findings

**1. The core question is NOT answered with verified evidence.** Neither this transition nor the recorded prior transition achieved working file-level access to `/home/bricker/Projects/etc/hngh`. No source file from the hngh kernel repository was read, grepped, or cited during this line's lifetime. Any claim about the reconciliation loop's actual branches would be fabrication, so none is made.

**2. What is established from the prior expanding transition (unverified but structured):** the reconciliation loop's handling of `timeout_complete` resolves to exactly one of three shapes:

- **(a) Explicit branch** — a `timeout_complete` case exists and enqueues a retry. If so, the question resolves trivially: retry already happens; the only remaining work is tuning retry policy (backoff, max attempts, idempotency key).
- **(b) Generic terminal handling** — `timeout_complete` falls into a catch-all "complete" branch and is treated as final. Retry would then require either a new branch or a reclassification of `timeout_complete` out of the terminal set.
- **(c) No handling** — the state is unrecognized; an explicit handler branch is required regardless.

**3. Design-space verdict (independent of which shape holds):** `timeout_complete` is semantically *not* a success state. A reconciliation loop that treats upstream idle timeout as terminal-complete conflates "work finished" with "work abandoned by infrastructure." The prior-art pointer `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` documents that upstream idle timeouts are a known failure mode in this ecosystem, which strengthens the case that silent terminal handling (shape b) would be a latent correctness bug, not merely a missing feature.

**4. Adjacent risk:** the prior-art pointer `[[sources/hngh-storeless-cli-state-loss]]` indicates hngh has known state-loss behavior in multi-process flows. If retry is implemented, it must not depend on CLI-local state surviving across processes — retry intent must live wherever the reconciliation loop's durable state lives, or the retry branch will be a no-op under exactly the failure conditions that trigger it. This claim is grounded only in the pointer title, not in verified source.

## Recommendations (for hngh / hngh-automation)

1. **Resolve the question mechanically before writing any code:** grep the hngh kernel repo for `timeout_complete` and for the reconciliation loop's state dispatch (search terms: `timeout_complete`, `reconcil`, the state-enum definition). A single grep answers (a)/(b)/(c). Estimated effort: minutes.
2. **If (b) or (c):** add an explicit `timeout_complete` branch that retries with bounded exponential backoff and a maximum attempt count, then transitions to a distinct `timeout_exhausted` terminal state rather than looping forever or silently completing.
3. **Make retry idempotent:** the retried operation must carry the original operation's identity so a late-arriving upstream result cannot double-apply.
4. **Store retry state durably**, per finding 4 — not in CLI process memory.
5. **Instrument:** emit a metric/log line per `timeout_complete` occurrence and per retry attempt, so shape (b), if it exists today, becomes visible in production rather than discovered by audit.

## Open threads (for future lines)

- **T1:** Which of (a)/(b)/(c) holds? — one grep away; highest-value next action.
- **T2:** Where does reconciliation state persist, and does it survive the storeless-CLI multi-process flow? (depends on T1 and on the `hngh-storeless-cli-state-loss` observation)
- **T3:** Should `timeout_complete` be renamed or split (e.g., `timeout_retryable` vs `timeout_final`) so the type system prevents terminal-misclassification regressions?

## Verification gaps (explicit)

- No file inside `/home/bricker/Projects/etc/hngh` was opened in this line. The repository path itself is given by the operator, so its existence is asserted by the environment, not verified by me.
- All three implementation shapes are hypotheses; none is confirmed.
- The semantics of the prior-art pointers are inferred from their titles; their contents were not read in this line.

## References

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (path given by operator; contents unverified this line).
- `research-lines.tsv` — line state ledger (current repository).
- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24) (llm-wiki vault, read-only pointer).
- `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` — LLM Upstream Idle Timeout and Incremental Writes (llm-wiki vault, read-only pointer).
- `[[sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus]]` — Observation: hngh promotion rung 11 (llm-wiki vault, read-only pointer; title truncated in source material).
- `[[sources/hngh-storeless-cli-state-loss]]` — Hngh storeless CLI state loss in multi-process flows (llm-wiki vault, read-only pointer; title truncated in source material).

_Line crystallized. The lasting record is: the question is well-posed, the answer space is fully enumerated, the recommendation is determined under each branch of that space, and the single unblocking action (T1) is a grep. Closing this line as contracted; reopen as a new line once T1's result is known._
