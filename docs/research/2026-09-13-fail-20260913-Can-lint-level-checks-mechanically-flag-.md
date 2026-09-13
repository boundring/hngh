# Can lint-level checks mechanically flag unattributed async status emissions and unmarked trailers at authoring time, and at what false-positive cost?

Status: crystallized 2026-09-13 from research line `fail-20260913-Can-lint-level-checks-mechanically-flag-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Can-lint-level-checks-mechanically-flag-.md.

# Research Line — Final Crystallized Record

**Line:** Can lint-level checks mechanically flag unattributed async status emissions and unmarked trailers at authoring time, and at what false-positive cost?
**Lifecycle state:** contracting → **closed (crystallized)**
**Scope:** `hngh` kernel (`/home/bricker/Projects/etc/hngh`) and its automation tooling (`hngh-automation`)

> **Verification caveat for this transition:** No filesystem reads were exercised while producing this record. File paths below are carried forward from prior beats where they were asserted with confidence; where a path or symbol could not be re-verified, it is marked *(unverified)*. Nothing in this record asserts a path that prior material did not already establish.

---

## 1. Findings

### F1. Emission points are syntactically discoverable; attribution is not statically provable.
In the `hngh` kernel, status emissions are structured calls on job contexts (pattern: `job.emit_status(Status::X, source: ...)`), not free-form logging. A lint pass can reliably *enumerate* emission sites. However, determining whether the `source` argument is *correct* requires resolving dynamic values (component registries populated at runtime, heartbeat sources derived from worker identity). **Full attribution verification is not a lint-level problem.** *(Kernel path asserted in prior material; exact emission API symbol unverified.)*

### F2. Trailer completeness is a control-flow property and is lint-feasible.
An "unmarked trailer" is an async task whose closure never reaches a terminal emission (`DONE`/`ERROR`). This is a structural property of the spawn site's lexical scope, not a semantic one. The `hngh` kernel currently absorbs these defects via timeout-based job reclamation — a runtime safety net, not an authoring-time signal *(mechanism described in prior material; timeout/reclamation code path unverified)*.

### F3. The naive "unattributed emission" check has unacceptable false-positive cost.
Flagging every emission with a non-literal or unregistered `source` catches heartbeats and legitimate dynamic resolution, producing noise high enough that the check would be disabled in practice. The prior beat's refinement — flag only **string literals absent from the component registry** — reduces false positives to hardcoded typos and stale IDs.

### F4. The false-positive cost is bimodal, not uniform.

| Check | FP vectors | Estimated FP cost | Verdict |
|---|---|---|---|
| Trailer completeness (scoped to job-task closures) | Terminal emission delegated to a helper; intentionally non-terminating tasks | Low, if helpers are inlined or allowlisted and `NON_TERMINATING` marking exists in the API *(unverified)* | **Adopt** |
| Invalid static attribution (literal ∉ registry) | Registry out of date; literals used for ad-hoc sources | Very low, contingent on registry freshness | **Adopt** |
| General unattributed-emission flag | Heartbeats, dynamic resolution, helper-mediated emissions | High | **Reject** |

### F5. The general-purpose linter fails the actionability test.
A check whose findings require runtime context to adjudicate is not a lint check; it is a deferred runtime check wearing lint clothing. The contracted design succeeds precisely because both surviving checks produce findings an author can resolve by reading one function body.

---

## 2. Recommendations (Final)

1. **Implement the Trailer Completeness Check** in `hngh-automation`'s lint suite *(suite location unverified)*: for each async spawn in a job scope, require a terminal-state emission reachable in the closure's control flow. Ship with an explicit suppression/annotation mechanism for intentionally non-terminating tasks.
2. **Implement the Invalid Static Attribution Check**: validate literal `source` arguments against the component registry (prior material referenced `/etc/hngh/components.json` *or a generated constant list — neither re-verified*). Never flag non-literal sources.
3. **Do not build the general "unattributed emission" linter.** Record this as a deliberate negative result, not a deferred task.
4. **Add a registry-freshness guard** (lint or CI step) so check #2 cannot silently degrade as components are added — otherwise its false-positive cost rises over time.
5. **Keep timeout-based reclamation** in the kernel as the backstop; the lint checks reduce reliance on it but do not replace it.

---

## 3. Open Threads (handed off, not pursued on this line)

- **Helper-delegated terminal emissions:** precise handling requires call-graph analysis. Whether `hngh-automation` has (or should grow) interprocedural capability is a tooling-scope question for a separate line.
- **Heartbeat semantics:** whether heartbeat emissions should carry a distinct marker so future checks can exclude them categorically rather than heuristically.
- **Registry provenance:** whether the component registry is hand-maintained or generated from kernel source; if generated, check #2's FP cost approaches zero and the freshness guard (Rec. 4) may be unnecessary.
- **Empirical FP measurement:** all false-positive costs above are structural estimates. A measurement pass over the existing `hngh` corpus (run both checks, hand-classify findings) would convert estimates into numbers — candidate seed for a follow-on line.

## 4. External-Source Note

Prior-art pointers (SLSA levels, MisakaNet trust semantics, async-proof patterns) informed framing but were **not re-read for this record**; any claim in this summary that would depend on their content is derived from repository-side reasoning instead. No external factual claims are asserted.

## References

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (emission API, job reclamation; specific symbols unverified this transition)
- `hngh-automation` — lint/automation tooling target (path within kernel repo unverified)
- `/etc/hngh/components.json` — component registry candidate (referenced in prior material; existence unverified)
- Prior beat: research beat 2026-09-13 (expanding → contracting), this line
- Prior art pointers (read-only, not re-verified): `[[sources/SRC-2026-08-24-006]]`, `[[sources/SRC-2026-08-24-011]]`, `[[sources/async-proof-pattern-for-long-drop-ins]]`, `[[sources/long-gates-run-async-against-interjections]]`, `[[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]]`

**Line status: contracted and recorded. The two-check design and the negative result on general attribution linting stand as the lasting output.**
