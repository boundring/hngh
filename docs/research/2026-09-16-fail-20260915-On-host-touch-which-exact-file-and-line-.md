# On host touch, which exact file and line in ~/Projects/etc/hngh consumes the make exit code, and is it a `set -e` abort or an explicit status branch?

Status: crystallized 2026-09-16 from research line `fail-20260915-On-host-touch-which-exact-file-and-line-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-On-host-touch-which-exact-file-and-line-.md.

# Contraction — final record for line

**Line:** On host touch, which exact file and line in `~/Projects/etc/hngh` consumes the make exit code, and is it a `set -e` abort or an explicit status branch?
**State:** contracting → crystallized (record closed; core determination *not* resolvable from verifiable material — see §2)

---

## 1. Question under investigation

Two coupled sub-questions:
1. **Location:** the exact file and line in `~/Projects/etc/hngh` that consumes the exit status of a `make` invocation in the "host touch" flow.
2. **Mechanism:** whether that consumption is (a) an implicit abort via `set -e` / `set -o errexit`, or (b) an explicit status branch (`rc=$?`, `|| exit`, `if ! make …`, etc.).

## 2. Findings

**The core determination cannot be established from the material available to me, and I will not assert a file path or line number that I cannot verify.** I have no read access to `~/Projects/etc/hngh` (or to "this repository") in this context; therefore I cannot ground the location claim in the repo as the line's grounding rule requires. Any specific filename or line number offered here would be fabricated, and I decline to offer one.

What *is* on record:
- The prior contraction attempt for this date was truncated at the model call (completion hit the max-token cap, `finish_reason=length`) and recorded **no confirmed finding**. So before this crystallization there is no verified answer in the line's own history.
- The prior-art pointer ([[sources/SRC-2026-08-24-037]], AGPL-3.0 + DCO inbound-contribution practice) establishes only that the project is a copyleft codebase with DCO requirements. It does **not** bear on where or how a make exit code is consumed; it is context, not evidence for this question.

What *is* knowable as general tooling semantics (standard POSIX-shell / GNU-Make behavior — I am relying on standard tool documentation as general knowledge and have **no verifiable external source in this context** to cite; treat these as background, not repo facts):
- The two candidate mechanisms are precisely:
  - **`set -e` abort:** the script enables errexit (`set -e` / `set -o errexit`) and runs `make …` as a bare command. A nonzero make status then terminates the shell automatically; no explicit test of `$?` is needed for the abort to happen.
  - **Explicit status branch:** the script captures or tests the status itself, e.g. `make … || die`, `rc=$?` followed by `if [ $rc -ne 0 ]`, or `if ! make …; then … fi`.
- **These are not mutually exclusive.** A script can carry `set -e` *and* an explicit branch. The question asks which one *consumes* the code for control flow: if both are present, the explicit branch is what drives branching, while errexit would additionally fire on any unhandled failure. A correct answer must state which mechanism actually governs the observed behavior, not merely that `set -e` exists somewhere in the file.

## 3. Decision procedure (how to close the question)

These are inspection steps to run *against the repo*, not claims about its contents:
1. Enumerate make invocations in the "host touch" flow: search shell sources for `make` / `$(MAKE)` and match the specific call by its arguments/target (e.g. `-C …`, cross/host vs target variables) so you are looking at the right invocation, not an unrelated one.
2. For each candidate file, check the header for `set -e` / `set -o errexit`.
3. At the make line, look for explicit consumption: `$?`, `rc=`, `status=`, `|| exit`, `|| die`, `if ! make …`, `&& echo ok`.
4. Classify: bare call under errexit → implicit abort; captured/tested status →

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
