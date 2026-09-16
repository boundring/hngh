# Which specific environment variables or binary paths constitute the "subprocess-stub-seam" documented in the vault pointer for hermetic testing?

Status: crystallized 2026-09-16 from research line `fail-20260915-Which-specific-environment-variables-or-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Which-specific-environment-variables-or-.md.

# Contraction: Subprocess-Stub-Seam for Hermetic Testing

**Line:** Which specific environment variables or binary paths constitute the "subprocess-stub-seam" documented in the vault pointer for hermetic testing?
**State:** contracting → **closed (unresolved)**
**Date:** 2026-09-16

---

## Findings

### What is established

| # | Claim | Basis |
|---|-------|-------|
| 1 | A vault pointer is *referenced* in the line's framing as documenting a "subprocess-stub-seam" for hermetic testing. | Line title itself; prior beat framing. |
| 2 | The pointer's **content was never read, quoted, or cited by path** in any prior beat of this line. | Prior contraction assessment (beat 2026-09-16): "The pointer is referenced in the prior material's framing but its content was never quoted or cited by path." |
| 3 | No file from `~/Projects/etc/hngh` was examined in any beat of this line. | Prior contraction assessment: "No file from that tree was read." |
| 4 | The expanding beat produced **zero repository-anchored findings**; every candidate mechanism (env-var toggle, `LD_PRELOAD`, stub binary directory) was explicitly labelled hypothetical and generic to standard hermetic-testing practice. | Prior contraction assessment table, row 3: "Hypothetical pattern only." |

### What is NOT established

- **No specific environment variable name** (e.g., no `HNNGH_*`, `STUB_*`, `FAKE_*` identifier) can be named as part of the seam. I have not read any source file in the hngh kernel repository, and no prior beat did either.
- **No specific binary path** (e.g., no `/usr/lib/hngh/stubs/…`, no `bin/stubs/…`) can be cited. Same reason.
- **The identity of the vault pointer itself is unconfirmed.** The prior art list for this line contains six pointers, none of which is titled or described as a "subprocess-stub-seam" document:

  - `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson (truncated title)
  - `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson (truncated title)
  - `[[sources/SRC-2026-08-24-007]]` — AgentDojo: Dynamic Environment for Agent Attack/Defense Evaluation
  - `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson (truncated title)
  - `[[sources/SRC-2026-08-24-004]]` — in-toto Specification
  - `[[sources/SRC-2026-08-24-036]]` — Cedar: property-based testing of a policy engine

  None of these is the primary source for the seam. The pointer the line asks about is either (a) one of the truncated-title entries whose full title I cannot see, or (b) a pointer not in this prior-art list at all. **I cannot verify which.**

### Verdict

The line's question is **unanswerable from available evidence**. The contraction records this as an unresolved gap rather than fabricating an answer. No environment variable name, binary path, or mechanism can be asserted without reading the primary source (the vault pointer) and/or the hngh kernel repository.

---

## Recommendations (Executable Next Actions)

Ordered by information yield per unit effort. Each is a single locally executable action.

### 1. Read the vault pointer (blocking prerequisite)

The entire line hinges on what the pointer says. Before any code search:

```bash
# Identify which pointer in the vault is the "subprocess-stub-seam" document.
# The prior-art list does not contain an obvious match; search by keyword:
grep -ril 'subprocess.stub.seam\|stub.seam\|hermetic' /path/to/llm-wiki/vault/sources/

# Then read it in full:
cat <resolved-pointer-path>
```

Record verbatim every environment variable name, binary path, flag, or directory the pointer names. If the pointer is terse, that terseness *is* the finding—note it and stop speculating.

### 2. Targeted source grep in the hngh kernel repository

Once candidate names exist from step 1 (or even without them):

```bash
# Env-var lookups
grep -rn 'getenv\|secure_getenv' ~/Projects/etc/hngh \
  --include='*.c' --include='*.h' --include='*.rs' --include='*.go'

# Subprocess call sites
grep -rn 'execve\|posix_spawn\|fork\b\|system(' ~/Projects/etc/hngh \
  --include='*.c' --include='*.rs' --include='*.go'

# Stub / hermetic markers
grep -rni 'stub\|hermetic\|fake\|mock' ~/Projects/etc/hngh \
  --include='*.c' --include='*.h' --include='*.rs' --include='*.go' \
  --include='*.sh' --include='*.py'
```

Cross-reference hits against step-1 names. The intersection is the answer.

### 3. Inspect test harness and CI scripts

Hermetic seams are typically wired in the *harness*, not kernel code:

```bash
find ~/Projects/etc/hngh -type d \
  \( -name 'test' -o -name 'tests' -o -name 'stubs' -o -name 'fixtures' \) -print

grep -rn 'PATH=\|LD_PRELOAD\|chroot\|unshare' \
  ~/Projects/etc/hngh/{test,tests,stubs,scripts,.github} 2>/dev/null
```

If a `stubs/` or `bin/stubs/` directory exists, list its contents—those *are* the binary paths in the seam.

### 4. Check hngh-automation for the automation-side counterpart

The line's prior art references an `hngh-automation` repository (see pointer `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-`). The seam may be defined or consumed there rather than in the kernel tree:

```bash
# Adjust path to wherever hngh-automation lives on this host.
grep -rni 'stub\|hermetic\|LD_PRELOAD\|getenv' /path/to/hngh-automation \
  --include='*.py' --include='*.sh' --include='*.yaml' --include='*.yml'
```

### 5. If the pointer cannot be located or read

Record that fact in the line's state file and re-open the line as a **new** research question: *"Locate and transcribe the subprocess-stub-seam vault pointer."* Do not close this line on speculation.

---

## Open Threads

| Thread | Status |
|--------|--------|
| Identity of the vault pointer for "subprocess-stub-seam" | **Open.** Not in the prior-art list under an obvious title; may be a truncated-title `LES-fail` entry or an unlisted pointer. Requires vault search (action 1). |
| Actual env-var / binary-path content of the seam | **Open.** Zero evidence gathered. Blocked on action 1. |
| Whether the seam lives in the kernel repo, the automation repo, or both | **Open.** No file from either tree was read. |
| Relationship to `in-toto` (SRC-2026-08-24-004) and `Cedar` (SRC-2026-08-24-036) prior art | **Open / tangential.** These are listed as prior art but their connection to the seam is unexamined. May be relevant if the seam involves supply-chain attestation or property-based testing of subprocess policy, but this is speculative and unverified. |

---

## References

All citations below are to vault pointers present in the prior-art list for this line. **No file paths from `~/Projects/etc/hngh` are cited because no file in that tree was read in any beat of this line.** No external sources beyond the vault are cited because none were consulted or verified.

- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson (title truncated in prior-art list; full title not available to this contraction)
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson (title truncated)
- `[[sources/SRC-2026-08-24-007]]` — AgentDojo: Dynamic Environment for Agent Attack/Defense Evaluation
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson (title truncated)
- `[[sources/SRC-2026-08-24-004]]` — in-toto Specification
- `[[sources/SRC-2026-08-24-036]]` — Cedar: property-based testing of a policy engine

*No hngh kernel repository file paths are named. No vault pointer for the "subprocess-stub-seam" itself is cited, because its identity could not be confirmed from the prior-art list and its content was never transcribed in any prior beat.*

---

**Line status: closed (unresolved).** The question remains open to a future line that can execute actions 1–4 above. This contraction is the lasting record of what was *not* found, why it could not be found, and exactly what must be done to find it.
