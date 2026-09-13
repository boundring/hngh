# Does the `bin/hngh` executable have a stable CLI interface contract (e.g., version flag, JSON output mode) that can be pinned in capture-and-replay fixtures?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-the-bin-hngh-executable-have-a-stab`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-the-bin-hngh-executable-have-a-stab.md.

# Research line contraction: `bin/hngh` CLI contract stability

**Line:** Does the `bin/hngh` executable have a stable CLI interface contract (e.g., version flag, JSON output mode) that can be pinned in capture-and-replay fixtures?
**State:** contracting → closed (record crystallized; open threads remain for re-opening on verification)
**Date of contraction:** 2026-09-13

---

## Epistemic status

This line was opened because fixture authors in hngh-automation need a pinnable contract: something stable enough that capture-and-replay fixtures do not silently rot when the kernel changes. The prior beat (2026-09-13, expanding → contracting) produced **no empirical findings**. It ended at "Let me start by exploring the repository structure." No file was read, no flag was exercised, no output was captured. This contraction inherits that limitation: I am producing a text record, not executing commands or reading files in `~/Projects/etc/hngh`. Every claim below about the current CLI surface of `bin/hngh` is therefore **a hypothesis to verify, not an observation**. The recommendations are phrased so they hold regardless of which way verification lands.

---

## Findings

### What is established (grounded in prior material and vault pointers)

1. **The line exists for a concrete engineering need.** Fixture authors require a pinnable contract so that capture-and-replay fixtures remain valid across kernel changes. This is the motivating constraint, not an academic question.
2. **A run-contract notion already exists in the kernel's design discourse.** The vault pointer `[[sources/SRC-2026-08-24-020]]` is titled *"Hngh Run Contract"* (created: unknown). Its contents were not transcribed into any prior beat, so its specific claims are **unverified here**. What is established is only that the concept exists in the vault and predates this research line.
3. **A delegated-contract-verification concept exists.** The vault pointer `[[concepts/delegated-contract-verification]]` (created: 2026-08-2[truncated date]) frames prior thinking on how contract verification can be delegated. Its contents were likewise not transcribed into the beat; only its existence as a framing concept is established.
4. **The kernel repository path is known.** The hngh kernel lives at `~/Projects/etc/hngh`. No file paths within that repository are cited in any prior material, and I will not invent them.

### What is NOT established (hypotheses requiring verification)

- Whether `bin/hngh` is a compiled binary, a script, or a symlink wrapper. This affects how reliably flags can be added upstream.
- Whether `--version` exists, what it prints, and its exit code.
- Whether `--help` exists, whether its output is stable across invocations, and its exit code.
- Whether any JSON or machine-readable output mode exists at all.
- What the *"Hngh Run Contract"* source note actually specifies (schema, flag names, versioning policy).
- Exact paths within either repository for the CLI entry point's implementation and any existing contract documentation.

### What is established about the fixture-pinning problem itself

- The prior beat correctly identifies that **golden-file fixtures** (byte-for-byte comparison of `--version` and `--help` output) are the appropriate capture mechanism if a stable surface exists.
- If a JSON mode is verified to exist, **schema validation** is preferable to blob comparison so semantically equivalent reformatting does not break the suite.
- **Version-gating** (asserting the recorded `--version` string first and failing fast with a "contract drift" error) is the correct replay strategy regardless of which surface is pinned.

---

## Recommendations

### For the hngh kernel repository (`~/Projects/etc/hngh`)

1. **Define the contract as a small, explicit surface.** At minimum:
   - `hngh --version` printing a semver on stdout, exit 0, nothing on stderr.
   - `hngh --help` with a stable subcommand/flag listing, exit 0.
   - Documented exit codes (0 success; nonzero failure classes).
   - If machine-readable output exists or is planned, a single opt-in flag (e.g., `--json`) with a versioned schema identifier in the payload.
2. **Publish the contract as a committed artifact in-repo** (e.g., a `docs/` file or top-level contract document — exact location to be chosen by maintainers) so fixtures can cite a committed artifact rather than observed behavior. This makes the contract auditable and diffable.
3. **Treat contract changes as breaking changes** gated by the version flag, so fixture replay failures map directly to a version delta. A fixture that fails should be able to say "recorded against 0.x.y, running 0.z.w" without ambiguity.

### For hngh-automation (this repository)

4. **Probe before pinning.** The first concrete step, runnable in minutes on an idle host: execute `bin/hngh --version`, `bin/hngh --help`, and each subcommand with no args; record stdout/stderr/exit code for each. This converts the line's central question from open to answered empirically. No prior beat has done this.
5. **Golden-file fixtures, not transcripts.** Capture `--version` and `--help` output as golden files; replay compares byte-for-byte. If a JSON mode is verified to exist, validate against a stored schema rather than a captured blob.
6. **Version-gate the fixture suite.** Every replay run should assert the recorded `--version` string first and fail fast with a "contract drift" error rather than cascading into per-fixture failures.
7. **If verification shows no stable surface** (no version flag, unstable help text), the recommendation flips: pin at the *subcommand invocation* level with output normalization (whitespace/ordering-tolerant diffing) and file an upstream request for the four contract elements in item 1 above.

---

## Open threads

These keep the line in motion on idle hosts; any one of them resolving re-opens the contraction:

| # | Thread | Why it matters |
|---|--------|---------------|
| 1 | **Empirical probe of `bin/hngh`** — run `--version`, `--help`, no-arg subcommands; record stdout/stderr/exit. | Converts every "hypothesis to verify" in the Findings section into an observation or refutation. This is the single highest-leverage next action. |
| 2 | **Read `[[sources/SRC-2026-08-24-020]]` ("Hngh Run Contract")** and transcribe its claims into the line record. | If it already specifies a contract, the kernel-repo recommendations in items 1–3 may be partially or fully satisfied, and the automation-side work reduces to verification rather than upstream request. |
| 3 | **Read `[[concepts/delegated-contract-verification]]`** and determine whether the fixture suite should implement delegated verification (e.g., a sidecar that checks the contract independently of the kernel binary). | Affects *where* the pinning logic lives, not just *what* is pinned. |
| 4 | **Identify the CLI entry-point implementation path** in `~/Projects/etc/hngh` (compiled binary? shell script? Go main? Rust bin?). | Determines whether adding `--version` / `--json` is a one-line change or requires a build-system edit, and whether the contract can be enforced at compile time. |
| 5 | **Determine whether any JSON/machine-readable mode already exists** (grep for `json`, `JSON`, `marshal`, `encode` in the kernel repo; check subcommand output). | If it exists but is undocumented, the fixture work is purely on the automation side. If it does not exist, the upstream request in item 7 applies. |
| 6 | **Pin the exact file paths for contract documentation** once created (kernel-repo `docs/` or equivalent; automation-repo fixture directory). | The References section of this record currently cannot name these paths because they do not yet exist in any prior material. They become citable the moment they are committed. |

---

## Disposition

The line is **crystallized as a lasting record**. It is not "resolved" in the empirical sense — no flag has been exercised, no output captured, no contract confirmed or refuted. It is closed in the sense that the structured summary above is the final form of what this line establishes at this point: the engineering need is clear, the recommended shape of the contract is specified, the verification steps are enumerated, and the open threads are named so that any idle host picking up the line knows exactly where to start. The line re-opens on the first thread in the table above (the empirical probe), which is expected to take minutes and will either confirm the contract exists (in which case items 4–6 of the automation recommendations proceed) or confirm it does not (in which case item 7 and the upstream request proceed).

---

## References

- **Prior beat material, 2026-09-13** (expanding → contracting transition; no empirical findings produced; epistemic status and recommendations as transcribed above).
- **`~/Projects/etc/hngh`** — hngh kernel repository root. Path known from line framing. No internal file paths are cited in any prior material; none are asserted here.
- **`[[sources/SRC-2026-08-24-020]]`** — vault source note titled *"Hngh Run Contract"* (created: unknown). Existence confirmed by vault pointer; contents not transcribed into any beat and therefore unverified in this record.
- **`[[concepts/delegated-contract-verification]]`** — vault concept note (created: 2026-08-2[truncated]). Existence confirmed by vault pointer; contents not transcribed into any beat and therefore unverified in this record.
- **`research-lines.tsv`** — line state file for the continuous research process. The line's current lifecycle state (`contracting`) is recorded there.

No external sources are cited. No claims are made about the contents of `bin/hngh`, its flags, its output format, or its implementation language beyond what the prior material and vault pointers establish. Where a claim would require reading a file in `~/Projects/etc/hngh` or executing `bin/hngh`, it is marked as an open thread rather than asserted.
