# Has the upstream guardrail bug from 2026-08-25 been resolved in the current kernel version, and does `lib/automation.py` now handle the corrected CLI contract without errors?

Status: crystallized 2026-09-13 from research line `fail-20260913-Has-the-upstream-guardrail-bug-from-2026`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Has-the-upstream-guardrail-bug-from-2026.md.

# Research Line Contraction — Final Structured Summary

**Line:** Has the upstream guardrail bug from 2026‑08‑25 been resolved in the current kernel version, and does `lib/automation.py` now handle the corrected CLI contract without errors?
**State:** contracting → **closed (recorded)**
**Epistemic status:** This turn performs no live reads. The summary below is a *decision record*, not a verification result. Claims are labeled **[G]** (grounded in prior material / vault pointers), **[H]** (hypothesis), or **[U]** (unverifiable from here; requires host access to `~/Projects/etc/hngh` and the automation repo).

---

## 1. Findings (what is established vs. what remains open)

The line decomposes into two conjunctive claims that must **both** hold for the question to be answered "yes" [G]:

- **C1 — Upstream resolution.** The guardrail fix is present in the hngh kernel at `~/Projects/etc/hngh` *and* in the version actually deployed on idle hosts.
- **C2 — Downstream conformance.** `lib/automation.py` invokes the *corrected* CLI contract (post‑2026‑08‑25) and exits cleanly under that contract.

**Established [G]:**
1. The bug is upstream‑origin: it lives in the kernel, not in `lib/automation.py`. Therefore C1 gates C2 — "the corrected contract" is undefined until C1 pins the fix commit. This framing is consistent with `[[concepts/delegated-contract-verification]]` and the failure class named in `[[concepts/llm-upstream-idle-timeout-incremental-writes]]`.
2. The dominant failure mode is **one‑sided verification**: a fixed kernel behind a stale caller still errors; an updated caller against an unfixed kernel also errors. Resolving only C1 or only C2 does not close the line.
3. A post‑dating artifact exists: `[[concepts/hngh-lessons-current]]` (created 2026‑09‑07, ~13 days after the bug) is the single most likely place to already record resolution status, fix commit, and corrected CLI shape.

**Open / Unverifiable [U]:**
- The actual fix commit hash, tag, or version number in `~/Projects/etc/hngh`.
- Whether the deployed kernel version on idle hosts ≥ the version containing that commit.
- The concrete corrected contract (flag names, argument order, exit codes, streaming/incremental‑write behavior).
- Line‑by‑line conformance of `lib/automation.py`'s CLI invocation site(s) against that contract.
- A clean execution result (exit code 0, no guardrail error) under the corrected contract.

**Explicitly not asserted [U]:** I do **not** assert that any specific file (`CHANGELOG`, version manifest, etc.) exists at a specific path in either repository. Locate such artifacts via `git ls-files` / repo inspection rather than assuming their presence.

---

## 2. Recommendations (execution order — the lasting decision procedure)

These are ordered so that each step gates the next; stop and record if any pass criterion fails.

**R1 — Read the lessons note first [G].**
Open `[[concepts/hngh-lessons-current]]`. If it names a commit hash, version, or corrected CLI shape, R2 becomes a *confirmation* check rather than a forensic search. This is the cheapest step and should gate all others.

**R2 — Kernel forensics: pin fix commit + deployed version [G method / U outcome].**
On an idle host against `~/Projects/etc/hngh`:
- `git log --since=2026-08-25 --oneline --all` filtered for guardrail / idle‑timeout / incremental‑write terms.
- `git tag --sort=-creatordate | head` to find any release cut after 2026‑08‑25.
- **Pass criterion (C1):** a post‑08‑25 commit modifying the guardrail path **and** deployed kernel version ≥ the version containing that commit. A fix on `main` that is not what's running does *not* resolve C1.

**R3 — Extract the corrected contract from the fix itself [H].**
From the fix commit's diff and any updated CLI/help/contract tests in the kernel repo, write the contract down as concrete expectations (flags, argument order, exit codes, streaming/incremental‑write behavior) *before* touching `lib/automation.py`. This makes R4 a comparison against a fixed reference, not drift.

**R4 — Static review of `lib/automation.py` [U].**
Grep for the CLI invocation site(s); compare flags/argument handling line‑by‑line against the R3 contract. **Pass criterion (C2 static):** every contract element matched; no pre‑2026‑08‑25 contract remnants remain.

**R5 — Execute, don't just read [U].**
Static conformance is necessary but not sufficient. Run `lib/automation.py` against the deployed kernel under the corrected contract. **Pass criterion (C2 dynamic):** clean exit (code 0), no guardrail error, correct streaming/incremental‑write behavior observed.

**R6 — Record and close.**
Write the fix commit, version, contract spec, and execution result back into `[[concepts/hngh-lessons-current]]` (or a successor note) so the line's resolution is durable for future beats.

---

## 3. Open Threads (what remains if this line re‑opens)

1. **Deployment lag.** Even if C1 holds on `main`, idle hosts may run an older kernel. The deployed‑version check in R2 is the live risk; monitor host kernel versions against the fix tag.
2. **Contract drift.** If the kernel team revises the CLI contract again post‑fix, R3's written spec becomes stale and C2 must be re‑verified. Pin the contract to a specific commit, not a date.
3. **Partial conformance.** `lib/automation.py` may have multiple invocation sites; R4 must enumerate *all* of them, not just the primary one. A single stale site can still trigger the guardrail error.
4. **Regression surface.** The fix's diff may touch behavior beyond the guardrail (e.g., incremental‑write semantics). R5's execution check should cover the broader contract, not only the previously failing path.

---

## 4. References

Grounded in prior material and vault pointers (read‑only):
- `[[concepts/hngh-lessons-current]]` — Hngh Lessons -- Current *(created: 2026‑09‑07)*; primary gate for R1.
- `[[concepts/delegated-contract-verification]]` — delegated‑contract‑verification; frames C1‑gates‑C2 and the "write contract before reviewing caller" method (R3).
- `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` — names the failure class (upstream idle timeout / incremental writes) that the guardrail bug belongs to.
- `[[sources/SRC-2026-08-24-020]]` — Hngh Run Contract; background on the CLI contract shape pre‑ and post‑fix.
- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026‑08‑24); context for upstream resolution timing.
- `[[entities/hngh]]` — Hngh Agent Kernel; entity record for the kernel at `~/Projects/etc/hngh`.

Repositories (host access required; not read in this turn):
- `~/Projects/etc/hngh` — hngh kernel repository (C1 forensics, R2/R3).
- The automation repository containing `lib/automation.py` (C2 conformance, R4/R5).

**External sources:** None required. All claims above are either grounded in the prior material / vault pointers or explicitly marked **[U]** as unverifiable from here. No external citation is asserted where verification was not possible.
