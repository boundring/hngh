# Does the Sigstore project have any open RFCs or design documents proposing a WASM-based or Go-plugin-based extension mechanism for custom predicate types in cosign?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-Sigstore-project-have-any-open-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-Sigstore-project-have-any-open-.md.

# Research Line Crystallization: Cosign Predicate Extension Mechanisms

_line: Does the Sigstore project have any open RFCs or design documents proposing a WASM-based or Go-plugin-based extension mechanism for custom predicate types in cosign? | state: contracting → **crystallized** (closed with armed reopen triggers) | supersedes beat 2026-09-17_

This is the lasting record for the line. It consolidates the 2026-09-17 beat, corrects two of its overstatements, and marks the verification boundaries explicitly so future transitions inherit an honest ledger rather than a confident one.

---

## Findings

**F1 — No public WASM/plugin predicate-extension RFC found.** The line found no open RFC, design doc, or issue in the public `sigstore/sigstore` or `sigstore/cosign` trackers proposing a WASM-based or Go-plugin-based extension mechanism for custom predicate types. *Basis:* the prior beat's tracker search. **This is an external claim I cannot re-verify in this transition** — I performed no network or filesystem reads here. Coverage is also **partial**: the prior material does not state whether other Sigstore venues (community spec discussions, `sigstore/protobuf-specs`, mailing lists) were searched.

**F2 — Predicate handling is compiled-in, but the prior beat overstated "fork required."** The prior beat concluded custom predicate types require forking cosign. From general knowledge — **not verified against any checkout in this transition** — cosign's `verify-attestation` supports validating attestation/predicate content against declarative CUE policies (`--policy`). If present in the version hngh targets, that is a real declarative extension point for *verifying* custom predicate payloads, with no plugins needed. This narrows the problem: what likely still requires forking is *type registration and semantic interpretation*, not content checking. Open Thread T2 resolves this.

**F3 — The Go-plugin route is dead for independent technical reasons.** Go's `plugin` package requires matching compiler versions and toolchain ABI compatibility across the plugin boundary, with known GC/finalizer hazards. Disqualifying for a security-critical verification path regardless of upstream appetite. *(General Go knowledge; external, not repository-grounded.)*

**F4 — Reported-but-unverified upstream file path.** The prior beat cites `sigstore/cosign/pkg/cosign/predicate.go` as defining a `Predicate` interface. I cannot confirm this path exists; no cosign checkout was read in this line's recorded transitions. Carry it as *reported, unverified* until someone reads it.

**F5 — Sigstore's own architectural answer is policy-as-data, not plugins.** The separate `sigstore/policy-engine` project uses a declarative policy language rather than executable extension. This converges with the vault's prior art: Cedar ([[sources/SRC-2026-08-24-036]] — property-based testing of a policy engine) and the design-time-enforcement pattern of CaMeL ([[sources/S

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
