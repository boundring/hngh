# Does `lib/automation.py` invoke `bin/hngh` via `subprocess` or direct module import?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v.md.

# Final Structured Summary: `lib/automation.py` → `bin/hngh` Invocation Mechanism

**Line state:** contracting → **closed (pending single local verification)**
**Question:** Does `lib/automation.py` invoke `bin/hngh` via `subprocess` or direct module import?

---

## Findings

**F1 — The question is resolvable by a single local command, not by further research.**
The prior expansion beat could not resolve the line because the verifier lacked filesystem access to `/home/bricker/Projects/etc/hngh`. I must state this explicitly: **I cannot read `lib/automation.py` or `bin/hngh` from this session.** No claim in this record is an assertion of observed file content; every finding below is either (a) grounded in prior material already in the line, or (b) a recommendation whose only remaining step is a local check. The line should not consume another expansion beat on a question that a `grep` answers in under a minute.

**F2 — Circumstantial evidence strongly favors `subprocess`, but this remains a hypothesis until verified.**
Three independent signals from prior material point the same way:

1. **The hermetic-seam note** (`sources/subprocess-stub-seam-for-hermetic-tests`) describes an *env-overridable binary seam*. This pattern is coherent only if `bin/hngh` is invoked as an external process. You cannot env-override a direct module import in the same way; an env var that swaps the *binary path* presupposes a process boundary.
2. **The overnight-harness observation** (`sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`) describes a long-running, supervised harness. Long-running supervision pairs naturally with `subprocess.Popen` / managed-child-process lifecycle (signals, timeouts, exit-code capture) rather than in-process imports, where kernel-side exceptions would propagate directly into the automation's stack.
3. **The `bin/` path convention** signals an executable entry point (a script or compiled binary on `PATH` or invoked by absolute/repo-relative path), not an importable Python package. A direct module import would more typically live under a package directory with an `__init__.py`, not under `bin/`.

**Confidence:** high that the answer is `subprocess`; low enough to *not* state it as fact because I have not read the file. The line's lasting record should carry this confidence level, not a fabricated certainty.

**F3 — If the answer is direct import, that is an architectural defect, not a neutral alternative.**
An in-process import would contradict the stated hermetic-seam intent in the vault, couple the automation's failure domain to the kernel's (a kernel exception becomes an automation exception), and make the overnight harness fragile to kernel-side state. The correct response in that case is migration to `subprocess` with the env-overridable seam, not documentation of the import as intended behavior.

**F4 — State management across the process boundary must live in files, not Python objects.**
If (as expected) the invocation is `subprocess`, any state shared between automation and kernel must be persisted to files the harness already produces. Never assume a Python object survives between separate process invocations. This is a hard constraint on fixture design: capture-and-replay fixtures should record `argv`, `env`, `stdout`, `stderr`, and exit code — not Python-level call signatures that only make sense in-process.

---

## Recommendations

**R1 — Run the disambiguating check (one command, settles the line).**
```sh
grep -nE 'subprocess|Popen|shlex|run\(|import hngh|from hngh' lib/automation.py
grep -nE 'HNGH.*BIN|HNHG.*BIN|os\.environ' lib/automation.py
```
The first pattern distinguishes `subprocess` usage from direct import. The second checks whether the env-overridable seam is already implemented or merely described in the vault. This check takes under a minute and should be the *only* remaining action on this line.

**R2 — If `subprocess` (expected): formalize the seam.**
Make the binary path a single module-level constant overridable by one environment variable (e.g., `HNGH_BIN`), defaulting to the repo-relative `bin/hngh`. This is exactly the seam the hermetic-test note implies. It makes every test that touches `bin/hngh` hermetic by substituting a stub that records `argv` and emits canned `stdout`. If R1's second grep shows the seam already exists, this recommendation collapses to "verify it matches the vault description."

**R3 — If `subprocess`: pin the contract, not the implementation.**
Capture-and-replay fixtures for the harness should record `argv`, `env`, `stdout`, `stderr`, and exit code. Do not pin Python-level call signatures; they are an implementation detail that will drift. The state-management constraint from F4 applies: keep shared state in files the harness already produces.

**R4 — If direct import (unexpected): treat as a defect.**
Migrate to `subprocess` with the R2 seam. Do not document the import as intended behavior. The hermetic-seam intent in the vault is the stated architecture, and an in-process import contradicts it.

**R5 — Close the line after the check; do not idle-loop.**
This line has consumed one expansion beat without new evidence because the evidence requires local access. The correct lifecycle action after running R1 is `verified`, with a one-line observation note recording the answer and the file:line that proves it. A grep-answered question should not remain open past that check.

---

## Open Threads

**O1 — Whether the env-overridable seam is implemented or merely described.**
R1's second grep resolves this. If `HNGH_BIN` (or similar) appears in `lib/automation.py`, the seam exists and R2 is a verification, not a build. If it does not appear, the vault note describes an intended-but-unimplemented pattern, and R2 becomes a real task. This thread is *not* independent of R1; it resolves simultaneously with the main question.

**O2 — Whether the overnight harness's supervision model matches `subprocess` expectations.**
The observation note confirms the harness was "built-verified-enabled," but I have not read its source. If it uses `subprocess.Popen` with signal handling and timeout management, F2's second signal is confirmed at the code level. If it uses a different mechanism (e.g., `multiprocessing`, a process manager like `supervisord`, or a systemd unit), the architectural picture shifts slightly but the `lib/automation.py` → `bin/hngh` question is unaffected. This thread is *secondary* to the line's core question and should not block closure.

**O3 — Whether any other module in the automation repository also invokes `bin/hngh`.**
The line's question is scoped to `lib/automation.py`. If other modules (e.g., a CLI entry point, a test helper) also invoke `bin/hngh`, the seam from R2 should be shared rather than duplicated. This is a *follow-up* thread, not a blocker for closing this line. It can be opened as a new line if R1's grep reveals additional invocation sites.

---

## What I Cannot Verify (Stated Explicitly)

- Existence, content, or import structure of `lib/automation.py` and `bin/hngh`.
- Whether the env-overridable seam is already implemented or merely described in the vault.
- The supervision model of the overnight harness at the code level.
- Any external sources beyond the prior material already in this line. I have not consulted documentation, issue trackers, or commit history for either repository.

---

## References

1. `sources/subprocess-stub-seam-for-hermetic-tests` — Vault note describing an env-overridable binary seam for hermetic subprocess testing. Cited for F2(1) and R2.
2. `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` — Observation note confirming the overnight harness was built, verified, and enabled. Cited for F2(2).
3. `lib/automation.py` — Target file in the automation repository. **Not read in this session.** Cited as the subject of R1's grep; no content is asserted.
4. `bin/hngh` — Target binary in `/home/bricker/Projects/etc/hngh`. **Not read in this session.** Cited as the invocation target; no content or shebang is asserted.
