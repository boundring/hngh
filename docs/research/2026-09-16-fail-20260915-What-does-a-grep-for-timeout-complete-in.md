# What does a grep for `timeout_complete` in the hngh kernel repository reveal about the current state dispatch logic?

Status: crystallized 2026-09-16 from research line `fail-20260915-What-does-a-grep-for-timeout-complete-in`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-What-does-a-grep-for-timeout-complete-in.md.

# Final Structured Summary — `timeout_complete` Grep as State-Dispatch Probe

**Line:** What does a grep for `timeout_complete` in the hngh kernel repository reveal about the current state dispatch logic?
**Lifecycle:** contracting → **closed (crystallized)**
**Verification status:** No filesystem or shell access to `/home/bricker/Projects/etc/hngh` was available in any beat on this line. All findings are structural and methodological; none are observed facts about the repository's contents.

---

## Findings

### F1 — The grep is a four-class probe, not a hit counter

A raw `grep -r timeout_complete` against the hngh kernel tree yields hits that fall into exactly four syntactic classes:

| Class | Role | Syntactic signature (assumed match-based router) |
|-------|------|---------------------------------------------------|
| 1 — Declaration | Enum variant, const, or literal defining the state | `TimeoutComplete` in an `enum`, `const TIMEOUT_COMPLETE`, etc. |
| 2 — Entry site | Transition that *sets* the state | `= timeout_complete`, `State::TimeoutComplete` on the RHS of an assignment |
| 3 — Dispatch arm | The central match/router that *serves* the state | `timeout_complete => { … }` or equivalent arm in a dispatch function |
| 4 — Test / assertion | Reference in test fixtures, integration tests, or docs | Hits under test directories or in assertion contexts |

The **class distribution** is the finding; the raw hit count is not. A single hit in class 3 with zero hits in class 2 means the arm exists but nothing ever routes into it. Three hits in class 2 and zero in class 3 means the kernel can enter the state with no code to serve it.

### F2 — Two diagnostic asymmetries, one worse than the other

- **Unreachable state** (present in 1 + 3, absent in 2): The dispatch arm is dead code. This is a compile-time or review-time concern; it does not corrupt runtime behaviour unless a future transition accidentally lands there.
- **Dispatch hole** (present in 2, absent in 3): The kernel *can* enter `timeout_complete` but has no arm to serve it. If the dispatcher has a catch-all (`_ => …`), the state is silently swallowed; if it does not, the process panics or hangs. This is the worse failure because it surfaces at runtime under load, not at build time.

The dispatch hole is the finding that matters for hngh specifically: a timeout-completion state with no serving arm means upstream idle timeouts (see F4) complete without any downstream effect — the request is neither cancelled, retried, nor logged as timed out.

### F3 — Test-only references are evidence of harness reachability, not live-path reachability

If class 2 is empty in kernel source but populated in test fixtures, `timeout_complete` is reachable only inside the test harness. The state is exercised by tests but never by the live dispatch path. This is a weaker form of the unreachable-state problem: the arm may exist (class 3 present) and be tested, but no production transition ever fires it. Flagging this distinction prevents false confidence from green test suites.

### F4 — Probable domain context: upstream idle timeout completion

The vault pointer `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` indicates that timeout handling is an active concern in hngh. If `timeout_complete` is the terminal state of an upstream idle-timeout sequence, a dispatch hole (F2) means timeouts complete silently: the incremental-write stream stops, no cancellation propagates, and the analytics/guardrail layer (cf. `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`) may never observe the timeout event. **This cross-link is inferred from vault titles only; I have not read the contents of either document and cannot confirm the semantic relationship.**

### F5 — The finding is a probe design, not an observation

Every claim above specifies what the grep *would* reveal under each class distribution. No beat on this line executed the grep. The hngh kernel's language (Rust? Go? C?), dispatcher shape (match-based? table-driven? callback-registered?), and state enum contents are all unverified. The four-class framework is robust to those unknowns (the classes apply to any named-state system), but their syntactic signatures must be re-derived once the actual source is read.

---

## Recommendations

**R1 — Run the classified grep as the first action on this line.**
When shell access to `/home/bricker/Projects/etc/hngh` is available, execute:

```bash
grep -rn 'timeout_complete\|TimeoutComplete' --include='*.rs' --include='*.go' --include='*.c' --include='*.h' .
```

(Adjust `--include` filters to the kernel's actual language.) Bucket every hit into classes 1–4 by file path (test directories → class 4) and line pattern (RHS assignment → class 2; match-arm position → class 3; enum/const definition → class 1). Report the distribution, not the count.

**R2 — Encode both asymmetries as standing lint rules in hngh-automation.**
Once R1's classification is implemented, two checks become permanent guards over the *entire* state enum, not just `timeout_complete`:

- `declared ∧ dispatched ∧ ¬entered` → **warn**: "unreachable state"
- `entered ∧ ¬dispatched` → **error**: "dispatch hole"

The error severity on the second rule reflects F2: a dispatch hole is a runtime failure mode, not a dead-code smell.

**R3 — Treat class-4 references as evidence of harness reachability only.**
In any audit output, report test-only states separately from live-path states. A state that appears in tests but has no kernel-source entry site (class 2 empty outside test dirs) is flagged as "harness-reachable only."

**R4 — Verify the upstream-idle-timeout cross-link before acting on F4.**
Read `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` and confirm whether `timeout_complete` is the terminal state of that sequence. If confirmed, a dispatch hole in this state is not merely dead code; it is a silent-failure bug in the timeout path. If unconfirmed, F4 is a hypothesis to discard or redirect.

**R5 — Close the verification debt before any recommendation is treated as actionable.**
Both prior beats ran without repository access. R1–R4 are structural expectations. They become findings about hngh only after R1 is executed and the actual class distribution is reported. Until then, this line's output is a probe design with decision criteria, not an audit result.

---

## Open Threads

1. **Repository access.** The single blocking dependency for every recommendation above. No file path in `/home/bricker/Projects/etc/hngh` has been verified to exist. The next transition with shell access should run R1 and report the distribution; this line then either confirms or revises F1–F4 against observed data.

2. **Dispatcher shape.** The four-class framework assumes a named-state match/router. If the hngh kernel uses table-driven dispatch, callback registration, or a state-machine library, class 3's syntactic signature changes (e.g., a table entry rather than a match arm). The classes still apply; the grep patterns in R1 must be re-derived. This is resolvable in one read of the dispatch function once access is available.

3. **Vault document contents.** F4 rests on title-level inference from two vault pointers. Neither `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` nor `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` has been read. The cross-link is a hypothesis, not a finding, until verified.

4. **Generalization scope.** R2 generalizes the probe to the full state enum. The line as scoped was about one identifier. Whether the generalization warrants its own research line (e.g., "audit all hngh kernel states for dispatch holes") is an open scoping decision.

5. **Truncation in prior record.** The prior contracting beat's "What I cannot claim" section was truncated at 4000 bytes mid-sentence ("All vault do…"). The tail of that section and any subsequent content (possibly a References list) are not recoverable from the material provided to this transition. This summary reconstructs the line from what is present; if additional prior beats exist beyond the truncation point, they are not reflected here.

---

## What I Cannot Claim

- **No file path in `/home/bricker/Projects/etc/hngh` is cited**, because none could be verified to exist.
- The kernel's programming language, state enum name, and dispatcher implementation are unknown.
- The actual grep output (hit count, class distribution) has never been observed on this line.
- The contents of any vault document beyond its title are unknown.
- Whether `timeout_complete` is a Rust-style PascalCase variant (`TimeoutComplete`), a snake_case string literal, or some other form is unverified; the grep pattern in R1 includes both forms as a precaution.

---

## References

All references below are vault pointers provided as prior art for this line. I have not read their contents; they are cited as pointers only. No hngh kernel source file paths are referenced because none could be verified.

- `[[concepts/hngh-lessons-current]]` — Hngh Lessons -- Current *(created: 2026-09-07)*
- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24) *(created: unknown)*
- `[[entities/hngh]]` — Hngh Agent Kernel *(created: unknown)*
- `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` — LLM Upstream Idle Timeout and Incremental Writes *(content unread; title-level inference only)*
- `[[sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus]]` — Observation *(content unread)*
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` — Observation re: guardrail bug filed upstream *(content unread; title-level inference only)*

*No hngh kernel source files are cited. No external sources beyond the above vault pointers were used or required.*
