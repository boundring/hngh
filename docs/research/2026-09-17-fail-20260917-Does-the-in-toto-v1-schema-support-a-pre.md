# Does the `in-toto` v1 schema support a `predicateType` that explicitly encodes retention policy metadata, or is sidecar logging the only standard-compliant approach?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-in-toto-v1-schema-support-a-pre`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-in-toto-v1-schema-support-a-pre.md.

# Contracted Research Line: in-toto v1 `predicateType` for Retention Policy Metadata

**Line state:** contracting → **final**
**Date crystallized:** 2026-09-17
**Model:** unsloth:unsloth/Qwen3.8-27B-GGUF

---

## Direct Answer

**No.** The in-toto v1 statement schema does not define a standard `predicateType` URI for retention-policy metadata. The v1 envelope (`_type`, `predicateType`, `subject`, `predicate`) is deliberately minimal: it specifies *how* to bind subjects to predicates, not *which* predicates are normative. Retention and lifecycle policy sit outside the spec's concern (provenance, step integrity, artifact digests).

The two standard-compliant paths are:

1. **Sidecar logging** – keep retention metadata in a separate structured log stream that references the in-toto statement by subject digest or statement ID. The in-toto statement itself remains unmodified and parseable by any conformant verifier.
2. **Custom `predicateType` URI** – the schema permits *any* well-formed URI in `predicateType`. You may register e.g. `https://hngh.dev/predicates/RetentionPolicy/v1` and attach a retention object as the `predicate`. This is *schema-valid* (the JSON Schema constrains the field to a string/URI) but **not standard-compliant** in the interoperability sense: no upstream in-toto tooling (SLSA verifiers, Sigstore policy engines, `in-toto` CLI) will interpret or act on it.

For hngh/hngh-automation, **sidecar logging is the lower-risk choice** unless a concrete interop requirement demands retention data live inside the statement envelope.

---

## Findings

### F1 – The v1 schema is extensible by design; that is not the same as normative coverage

The in-toto v1 JSON Schema constrains `predicateType` to a URI string. It does **not** carry an enumeration of permitted predicate types. This means:

- Any well-formed URI passes schema validation.
- The *semantics* of a given `predicateType` are defined by the document that URI points to, not by the v1 envelope itself.
- Standard-compliant interop depends on the consuming toolchain recognising the URI, not on the schema accepting it.

This is the critical distinction: **schema-valid ≠ standard-compliant.** A retention predicate at `https://hngh.dev/predicates/RetentionPolicy/v1` will pass a JSON-Schema validator but will be opaque to SLSA provenance verifiers, Sigstore policy engines, and the `in-toto` CLI.

> *Verification caveat:* My characterisation of the v1 envelope is from training-time knowledge of the public in-toto spec (the normative document at `https://in-toto.io/Statement/v1` and the JSON Schema published under the `in-toto-attest/spec` GitHub repository). I cannot verify from within this repository or the hngh kernel whether a 2026 revision added a retention-related predicate type. Treat the "no standard retention predicate" claim as **true as of my last verifiable knowledge** and re-check before shipping a compliance statement.

### F2 – No upstream predicate type encodes retention semantics

The recognised predicate types in the in-toto / SLSA ecosystem as of my training-time knowledge include:

- `https://slsa.dev/provenance/v1` (and v0.1) – build provenance
- `https://in-toto.io/predicates/build/0.1` – legacy build predicate
- `https://in-toto.io/predicates/generic/0.1` – generic step predicate

None of these carry retention-class, purge-after, or legal-hold fields. The SLSA provenance v1 schema defines `builder`, `buildMetadata`, `materials`, and `invocation` – no retention axis. This is consistent with the spec's stated scope: attesting *what was built and how*, not *how long the artifact should be kept*.

> *Verification caveat:* I cannot confirm from within this repository that no 2025–2026 SLSA or in-toto working-group proposal has introduced a retention predicate. The claim rests on training-time knowledge of the published spec documents.

### F3 – Sidecar logging is the only approach that preserves byte-identical statement compatibility

If hngh-automation emits in-toto statements that are consumed by external verifiers (Sigstore, SLSA build-ticket checks, downstream CI gates), any modification to the `predicate` object or introduction of a non-standard `predicateType` risks:

- Silent rejection by strict verifiers that validate against a known set of predicate types.
- Schema-validation failures if the verifier's JSON-Schema validator includes an enum on `predicateType` (some SLSA tooling does this at the policy layer, not the schema layer).
- Inability to diff or replay statements across retention boundaries.

Sidecar logging avoids all three: the in-toto statement is untouched; the sidecar record references it by subject digest (`sha256:...`) or statement ID and carries `{ retention_class, purge_after, legal_hold, jurisdiction }`.

### F4 – The automation layer already has a schema-validation gate that a sidecar should flow through

Prior art in `wave-delay-spec-fixes-20260827` documents "scout schemas" (a schema-validation pass) and "atomic land" mechanics in the hngh-automation layer. A retention-metadata sidecar, if introduced, should enter the same validation gate rather than bypassing it. This means:

- The sidecar record format needs a scout-schema definition (JSON Schema or equivalent) before it is emitted.
- Atomic-land discipline applies: the sidecar and its referencing manifest entry land in the same atomic commit, so a partial state never exists.

This is grounded in the prior-art pointer `[[sources/wave-delay-spec-fixes-20260827]]` in this repository. I cannot verify from this position the exact file path of the scout-schema definitions within `[redacted path] I do not assert specific subdirectory paths beyond the kernel root.

### F5 – The custom-predicate route is viable but carries a namespace-collision risk

If a concrete interop requirement later demands retention data inside the statement envelope, the custom-URI route works *today* (the schema accepts any URI). The critical rule: **do not use the `https://in-toto.io/predicates/…` or `https://slsa.dev/…` namespace.** Use a distinct domain (`https://hngh.dev/predicates/…`) so that if upstream later ratifies a same-named predicate with different semantics, hngh tooling is not silently reinterpreted.

---

## Recommendations

| # | Recommendation | Rationale |
|---|---|---|
| 1 | **Do not invent a `predicateType` URI inside the in-toto or SLSA namespace.** Use `https://hngh.dev/predicates/…` if the custom-predicate route is taken. | Avoids silent breakage if upstream later ratifies a same-named predicate with different semantics. |
| 2 | **Prefer sidecar logging for retention metadata.** Emit a structured log record (JSON Lines or the existing scout-schema format) carrying `{ statement_subject_digest, retention_class, purge_after, legal_hold }` and reference it from the automation run manifest. | Keeps in-toto statements byte-identical to what any external verifier expects; retention policy is an operational concern, not an attestation concern. |
| 3 | **Gate the sidecar format through the existing scout-schema validation pass.** Define a JSON Schema for the retention-sidecar record before first emission. | Consistent with the atomic-land discipline documented in `wave-delay-spec-fixes-20260827`; prevents schema drift. |
| 4 | **Re-verify the upstream spec before shipping any compliance statement.** Check whether a 2025–2026 SLSA or in-toto working-group proposal has introduced a retention predicate type. If one exists, prefer it over the sidecar route. | The "no standard retention predicate" finding is bounded by training-time knowledge; a recent ratification would change the recommendation. |
| 5 | **If the custom-predicate route is taken, document the `predicate` object schema in the hngh kernel repository** (e.g., under a `predicates/` or `schema/` directory) so that the URI's target document is resolvable and versioned. | A `predicateType` URI without a resolvable target document is a dead reference; downstream consumers cannot validate the predicate object. |

---

## Open Threads

1. **Upstream spec drift.** The core finding ("no standard retention predicate") is bounded by training-time knowledge of the in-toto v1 and SLSA provenance v1 schemas. A 2025–2026 working-group proposal could have introduced a retention or lifecycle predicate type. This thread remains open until the normative documents at `https://in-toto.io/Statement/v1` and the SLSA provenance schema are re-checked against the current date. *I cannot verify this from within this repository.*

2. **Kernel-repo file layout.** I do not assert specific subdirectory paths within `[redacted path] (e.g., whether a `schema/`, `predicates/`, or `logging/` directory exists). The prior-art pointer `wave-delay-spec-fixes-20260827` confirms the existence of scout-schema validation and atomic-land mechanics in the automation layer, but the exact file paths are not verified from this position. If Recommendation 5 is actioned, the target path should be confirmed against the actual tree before a commit.

3. **Sigstore policy-engine behaviour.** Some Sigstore-based policy engines validate `predicateType` against a known set at the *policy* layer (not the JSON-Schema layer). The exact behaviour of current Sigstore releases toward an unknown `predicateType` URI is not verified from this position. If the custom-predicate route is taken, a conformance test against the target Sigstore version is required before deployment.

4. **Sidecar-to-statement binding model.** The recommendation to reference by subject digest (`sha256:...`) assumes the sidecar is keyed on the *subject* of the in-toto statement (the artifact). If hngh-automation also needs retention metadata scoped to the *step* or *builder* rather than the final artifact, the binding key may need to be the statement ID or a composite `(subject_digest, predicateType)` pair. This is an open design decision for the automation layer.

5. **Legal-hold interaction with purge-after.** The sidecar record format includes both `purge_after` and `legal_hold`. The interaction semantics (does a legal hold override purge-after? does it extend retention indefinitely?) are not specified by any in-toto or SLSA document. This is an hngh-internal policy decision, not a standards question, but the sidecar schema should encode the resolution rule explicitly to avoid ambiguity at purge time.

---

## References

### This repository (llm-wiki vault / research process)

- `research-lines.tsv` – line-state file tracking this research line; referenced in the prompt header as the canonical state store.
- `[[sources/wave-delay-spec-fixes-20260827]]` – prior art documenting scout-schema validation and atomic-land mechanics in the hngh-automation layer.
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` – research lesson on the `research-lines.tsv` schema (contextual, not directly load-bearing for this finding).

### hngh kernel repository

- `[redacted path] – kernel root, as given in the prompt. No specific subdirectory paths are asserted beyond this root; see Open Thread 2.

### External sources (training-time knowledge; not verifiable from within this repository)

- in-toto v1 Statement schema – normative document at `https://in-toto.io/Statement/v1`. The JSON Schema constrains `predicateType` to a URI string without enumerating permitted values. *Not verified against the current live document.*
- SLSA Provenance v1 schema – `https://slsa.dev/provenance/v1`. Defines `builder`, `buildMetadata`, `materials`, `invocation`; no retention axis. *Not verified against the current live document.*
- `in-toto-attest/spec` GitHub repository – source of the normative JSON Schema

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
