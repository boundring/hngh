# What is the exact exit status and match count of running `LC_ALL=C grep -F -- 'Storage=persistent' sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`?

Status: crystallized 2026-09-16 from research line `fail-20260916-What-is-the-exact-exit-status-and-match-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-What-is-the-exact-exit-status-and-match-.md.

# Final Structured Summary: `Storage=persistent` Verification Line

**Line:** What is the exact exit status and match count of running `LC_ALL=C grep -F -- 'Storage=persistent' sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`?
**State:** contracting → **closed**
**Disposition:** Unresolvable without direct execution on the host owning `~/Projects/etc/hngh`.

---

## Findings

### F1 — The command's semantics are fully determinable

The invocation decomposes as:

| Element | Effect |
|---|---|
| `LC_ALL=C` | Forces byte-wise collation; eliminates locale-dependent matching. |
| `grep -F` | Fixed-string (literal) match, case-sensitive. No regex interpretation of `=` or any other character in the pattern. |
| `--` | Option-termination guard; ensures the following argument is treated as a filename even if it began with `-`. |
| `'Storage=persistent'` | The exact 17-byte literal to search for. |
| `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` | Relative path, resolved against the current working directory (expected to be the root of the hngh kernel repository or a sub-repository such as `hngh-automation`). |

**Exit-status contract** (POSIX `grep`, §4.2):
- **0** — at least one line in the file contains the literal `Storage=persistent`.
- **1** — no line contains it.
- **2** — operational error (file missing, unreadable, I/O fault).

### F2 — The command as written does not emit a match count

`grep -F` without `-c` prints each matching line to stdout and sets the exit status. It does **not** print a numeric count. To obtain a match count one must either:

- append `-c` (`grep -Fc -- 'Storage=persistent' …`), or
- pipe the output: `… | wc -l`.

The research line asks for "the exact exit status **and** match count." The single command as specified yields the exit status directly and the match count only implicitly (as the number of lines on stdout). This is a specification gap in the original question, not a defect in the harness.

### F3 — The answer is host-bound and cannot be derived from repository metadata alone

The file `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` is an observation artifact whose content is produced at runtime by the overnight harness (built → verified → enabled, per the filename's embedded state markers). Its contents are not a static source file checked into version control in a way that would let a reader infer the presence or absence of `Storage=persistent` without executing the grep on the actual byte stream. I do not have filesystem access to `~/Projects/etc/hngh` in this session, and no prior beat in this line recorded an executed result. **The exact exit status and match count are therefore undetermined by this research process.**

### F4 — The filename encodes a three-phase state, not a storage-mode assertion

The suffix `built-verified-enabled` describes the harness lifecycle at observation time. It does not, by itself, assert that `Storage=persistent` appears in the log. A "verified" phase can pass on structural checks (file written, non-empty, schema-valid) while still omitting a particular key-value token. The grep is thus a **content-level** check that is strictly stronger than the filename's state claim.

### F5 — `LC_ALL=C` is load-bearing for this pattern

Because the pattern contains only ASCII bytes (`S t o r a g e = p e r s i s t e n t`), `LC_ALL=C` and any UTF-8 locale would produce identical results for this particular string. The flag is defensive hygiene, not functionally necessary here. It becomes load-bearing if the file ever contains multi-byte sequences that could shift byte offsets under a different collation order, or if the pattern were extended to non-ASCII tokens.

---

## Recommendations

### R1 — Execute and record the result (immediate, one-shot)

On the host owning `~/Projects/etc/hngh`:

```bash
cd ~/Projects/etc/hngh   # or the sub-repo root where sources/ lives
LC_ALL=C grep -Fc -- 'Storage=persistent' \
  sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled
echo "exit=$?"
```

Record both the count (stdout of `-c`) and the exit status. Append the result to the observation file or a sibling `verify/` artifact so the line is closed with a number, not a pointer.

### R2 — Add the token check to the harness's own verification phase

If `Storage=persistent` is a required field in the observation schema, the "verified" step should assert its presence **before** the filename is stamped `…-verified-enabled`. Concretely: inside the harness code that writes the obs file (expected to live under `~/Projects/etc/hngh` in a directory such as `hngh-automation/` or an equivalent build/verify script), add a post-write check:

```bash
if ! LC_ALL=C grep -qF -- 'Storage=persistent' "$OBS_FILE"; then
  echo "FATAL: Storage=persistent missing from $OBS_FILE" >&2
  exit 1
fi
```

This converts the external grep from a post-hoc audit into an inline gate, making the `verified` in the filename truthful by construction.

### R3 — Emit structured state alongside the human-readable log

The prior beat's suggestion to decouple configuration from log text remains valid but should be scoped: add a machine-readable sidecar (e.g., `sources/obs-2026-08-25-…/state.json` containing `{"storage": "persistent", …}`) so that verification can assert on a typed field rather than a substring. This eliminates the class of false positives where `Storage=persistent` appears inside a comment, a diff hunk, or a quoted string in the log body.

### R4 — Pin the grep invocation in a test

Add a regression test (shell or Python) to the harness CI that runs the exact command from this line and asserts both the exit status and the count. This makes the research question reproducible: any future drift in the obs format will fail the test rather than silently changing the number.

---

## Open Threads

| Thread | Status | Why it stays open |
|---|---|---|
| **Exact exit status** | Undetermined | Requires execution on the host; no prior beat recorded a result. |
| **Exact match count** | Undetermined | Same dependency; additionally requires `-c` or `wc -l` to be explicit. |
| **Whether the file exists at all** | Undetermined | If the path is stale (e.g., the obs file was rotated or the harness run failed before writing), exit status will be 2, which is a different failure mode than "file exists but token absent" (status 1). Distinguishing these two cases requires `test -f` before the grep. |
| **Schema enforcement in the harness** | Open design question | R2/R3 above are recommendations; whether and when they land in `~/Projects/etc/hngh` is a future beat. |

---

## What I cannot verify from this session

- The existence, size, or byte content of `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`.
- Whether the path is relative to `~/Projects/etc/hngh` root or to a sub-repository (e.g., `hngh-automation/`).
- Any external documentation of the obs-file schema beyond what the filename and prior beats imply.

I state these explicitly rather than asserting them.

---

## References

1. **Target file (referenced in the research line; existence on disk unverified in this session):**
   `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`
   — relative path, expected under `~/Projects/etc/hngh` or a sub-repo thereof.

2. **hngh kernel repository root (stated in the research-line prompt):**
   `~/Projects/etc/hngh`

3. **Prior art (llm-wiki vault entries, read-only pointers; I cannot verify their on-disk paths from this session):**
   - `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` — prior lesson on the same obs file.
   - `sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca` — prior lesson on file-path resolution for this line.
   - `concepts/agent-harness-governance` — positioning note (created 2026-08-24).
   - `sources/SRC-2026-08-24-030` — case study: overnight multi-agent sprint (2026-08-24).

4. **POSIX `grep` specification** (IEEE Std 1003.1, §4.2) — defines exit statuses 0/1/2 and the semantics of `-F`, `--`, and locale interaction. This is a standard reference; I cite it for the exit-status contract rather than asserting any hngh-specific behavior from it.
