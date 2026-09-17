# Does the Sigstore policy engine support a "custom predicate handler" plugin that can interpret non-standard `predicateType` URIs without modifying the core validation logic?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-Sigstore-policy-engine-support-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-Sigstore-policy-engine-support-.md.

# Research Line — Final Structured Summary (Contracted)

**Line:** Does the Sigstore policy engine support a "custom predicate handler" plugin that can interpret non-standard `predicateType` URIs without modifying the core validation logic?

**State:** contracting → **contracted** (final record)

---

## Verdict

**No.** Neither the Sigstore/cosign userspace verification stack nor the `hngh` kernel repository provides a runtime "custom predicate handler" plugin mechanism for non-standard `predicateType` URIs. The original research question conflates two architecturally unrelated systems that do not share a common policy-engine abstraction. The line is closed on this negative finding.

---

## Findings

### F1 — Sigstore/cosign predicate interpretation is compile-time, not pluggable

The `sigstore/sigstore` Go library and the `sigstore/cosign` CLI are statically compiled Go programs. Predicate-type dispatch in the verification path (e.g., matching an attestation's `predicateType` field against a known URI such as `https://in-toto.io/predicates/v0.1` or `https://slsa.dev/provenance-v1`) is implemented as Go source-level branching — a `switch`, a map lookup, or a sequence of string comparisons inside the verification package. There is no:

- `dlopen` / shared-object loading path,
- eBPF map or BPF program slot that could register a new URI handler,
- configuration-file schema that maps an arbitrary `predicateType` URI to a user-supplied interpretation function,
- Go plugin (`plugin` package) usage in the verification hot-path.

A non-standard `predicateType` URI presented to stock `cosign verify` will either be **ignored** (no handler matches it, so no attestation-level check is performed for that type) or **rejected** if the caller explicitly requests a predicate type the binary does not recognize. The core validation logic — signature verification, bundle integrity, identity matching — is untouched by any runtime registration mechanism.

*Grounding:* This is a structural property of the Go language toolchain as used by sigstore/cosign (static linking, no FFI plugin ABI in the verify path). The absence of a plugin slot is confirmed by the lack of any `plugin.Open`, `dlopen`-equivalent syscall, or dynamic-handler registration API in the published source. I cannot cite a single file that *proves* the absence (absence-of-evidence), but the positive evidence — all predicate-type dispatch is in Go source within the module's own packages — is consistent across the codebase.

### F2 — The `hngh` kernel repository operates at a different trust layer

The `hngh` kernel repository at `[redacted path] contains an OMP (Open Memory Pool / or project-specific) bridge with its own plugin architecture, as documented in the prior observation `obs-2026-08-24-hngh-omp-bridge-plugin-scaffolded-and-installed`. This plugin model is:

- **Kernel-space or kernel-adjacent** (in-kernel module or eBPF program),
- Governed by its own registration and lifecycle rules (module load, BPF verifier constraints, map-based configuration),
- **Not a Sigstore predicate interpreter.** It does not parse `predicateType` URIs, does not validate in-toto attestations, and does not participate in the cosign verification trust chain.

The two systems share no common "policy engine" interface. The word "plugin" appears in both contexts but refers to entirely different extension models at different privilege levels.

### F3 — No single component in either repository answers the research question as posed

The phrase "Sigstore policy engine" does not name a discrete, self-contained component with a documented plugin ABI. What exists is:

- A Go library (`sigstore/sigstore`) with typed interfaces (e.g., `policy.Policy` or equivalent) that are **satisfied at compile time** by concrete types in the same module or a forked copy.
- A CLI (`cosign`) that wires those interfaces to specific predicate-type handlers in its own source tree.

There is no "engine" with a stable, versioned plugin contract that an external party could implement against without forking the Go module. The research question's premise — that such an engine exists and the only open question is whether it has a plugin slot — is therefore **false at the premise level**.

---

## Recommendations

### R1 — For `hngh/hngh-automation`: use a pre-verification shim, not a fork, unless co-signing is required

If the automation pipeline must accept an hngh-specific attestation schema (a custom `predicateType` URI), the lowest-maintenance path is:

**(a) Pre-verification shim (preferred).**
A userspace step in the CI/automation graph that:
1. Extracts the bundle's attestations,
2. Validates any custom-predicate attestations against an hngh-specific schema (JSON Schema, Go struct unmarshal + field checks, or a small purpose-built validator),
3. Strips or annotates those attestations,
4. Invokes stock `cosign verify` on the remaining standard predicates.

The core validation logic is untouched. The shim is a separate Go binary or shell step with its own test suite. Failure of the custom-predicate check fails the pipeline independently of cosign's exit code.

**(b) Forked verifier (only if the custom predicate must participate in the cryptographic trust chain).**
Fork `sigstore/cosign` (or the relevant `sigstore/sigstore` sub-package), add one handler entry for the custom URI, vendor the fork. Keep the diff to a single dispatch entry — do not restructure the policy layer. Accept the ongoing upstream-merge cost.

**Do not** attempt to make stock cosign "just work" with an unknown `predicateType` by configuration alone. It will not.

### R2 — Keep kernel-space policy artifacts in a distinct pipeline stage from userspace Sigstore verification

If any automation step touches hngh kernel modules (`.ko`) or eBPF object files, those artifacts and their validation (module signing, BPF verifier acceptance) belong to a **separate pipeline stage** with its own trust assumptions. Do not:

- Route `predicateType` URIs through the OMP bridge plugin path,
- Expect the kernel plugin registration mechanism to influence cosign's predicate interpretation,
- Co-mingle `.ko` build artifacts and cosign verification steps in a single Makefile target or CI job without explicit separation.

The extension models are incompatible: eBPF is dynamically loadable but governed by verifier constraints and map configuration; LSM hooks require kernel compilation; neither interprets `predicateType` URIs.

### R3 — Document the boundary explicitly in the automation repo

Add a short architecture note (e.g., `docs/predicate-handling.md` or an equivalent) stating:

- Stock cosign does not interpret custom `predicateType` URIs.
- The pre-verification shim (or fork, if chosen) is the sole mechanism for custom-predicate acceptance.
- Kernel-space policy (OMP bridge, eBPF, LSM) is a separate trust layer and is not a predicate handler.

This prevents future contributors from re-litigating the question or attempting a "just add a config flag" solution that will not work.

---

## Open Threads

| # | Thread | Status |
|---|--------|--------|
| O1 | Whether a future sigstore/cosign release introduces a Go `plugin`-based or WASM-based predicate handler ABI. | **Unlikely** given the project's current architecture and Go's plugin-package limitations (same-version, same-GC constraint). Monitor upstream RFCs; no such proposal is visible in the prior material. Revisit if an upstream issue or design doc appears. |
| O2 | Whether the hngh OMP bridge plugin model could be *repurposed* as a pattern for a userspace predicate handler (e.g., an in-process registry with capability-gated handlers). | **Not directly applicable.** The OMP bridge operates at kernel privilege; its registration semantics (module load, BPF map) do not translate to a Go userspace library. The *conceptual* pattern (registry + capability check) could inspire a custom shim design, but this is a greenfield design

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
