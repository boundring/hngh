# What is the exact byte-level serialization format of audit trail entries in hngh (e.g., JSON key ordering, timestamp precision), and does it currently enforce UTC normalization at write time?

Status: crystallized 2026-09-20 from research line `fail-20260920-What-is-the-exact-byte-level-serializati`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260920-What-is-the-exact-byte-level-serializati.md.

# Research Line — Final Structured Summary (Contracting)

**Line:** What is the exact byte-level serialization format of audit trail entries in hngh (e.g., JSON key ordering, timestamp precision), and does it currently enforce UTC normalization at write time?

**Lifecycle state:** contracting → closed (this summary is the line's lasting record)

**Verification status:** No source file in the hngh kernel repository (`[redacted path] was inspected during any beat on this line. All prior material carries the caveat that the target repository was inaccessible or redacted at the time of writing. Consequently, **no claim below asserts what the code currently does at the byte level.** Every finding is either a structural decomposition, a recommended invariant, or an explicitly unverified open thread.

---

## Findings

### F1 — The question decomposes into six independently verifiable properties

The expansion beat established that "byte-level serialization format" is not a single property but a conjunction of six:

| # | Property | Why it matters for the line's question |
|---|----------|----------------------------------------|
| 1 | Field set (which keys appear, which are optional) | Determines whether two logically identical entries can differ in byte length |
| 2 | Value encoding (string vs. integer for timestamps; hex/base64 for binary) | Determines cross-entry ordering guarantees and parser compatibility |
| 3 | Key ordering (struct order, lexicographic, insertion, or nondeterministic) | Nondeterministic map iteration breaks byte-level reproducibility |
| 4 | Timestamp representation (RFC 3339 string vs. Unix integer; precision in ns/µs/ms/s) | Mixed representations across entry types break cross-entry ordering |
| 5 | Timezone normalization (UTC at write time vs. local-time passthrough) | The core of the line's second sub-question |
| 6 | Persistence framing (NDJSON, single JSON array, length-prefixed, etc.) | Determines whether the trail is stream-parseable and byte-countable without full-document buffering |

These six are the unit of verification. Any future beat on this line should report status per property, not as a monolithic "format."

### F2 — No external source in the prior art determines the byte format

The prior-art pointers (OSV Schema, SLSA, AgentSpec, MisakaNet Trust Semantics, and two LES-fail lessons) were consulted during expansion. None of them specifies hngh's audit-trail serialization. The OSV schema and SLSA levels describe *vulnerability* and *provenance* formats, not an operational audit trail. The AgentSpec source addresses runtime enforcement for LLM agents, not persistence framing. The two LES-fail lessons are research-process meta-lessons about file-path resolution and surviving-class confirmation; they do not carry format data. **No external source claim is made in this summary.**

### F3 — The implementation language of the hngh kernel is unconfirmed

The expansion beat noted that the search strategy for the audit emission site depends on the implementation language (Go `json.Marshal`, Rust `serde_json`, Python `json.dumps`, JS `JSON.stringify`, etc.). No beat confirmed which language or framework the hngh kernel uses. This is a prerequisite for Recommendation R1 below and remains open.

### F4 — The normalization question requires writer-boundary inspection, not call-site inspection

The expansion beat established that "does it enforce UTC at write time" is answerable only by reading the serializer configuration at the single emission site, not by sampling call sites or test fixtures. If conversion to UTC happens at call sites, any new call site can regress silently. The invariant must be *writer-boundary*: the serializer itself normalizes, so that no caller can bypass it. This is a design principle, not an observed fact about the current code.

### F5 — No file path in `[redacted path] has been verified to exist

The prior material references `[redacted path]` where the kernel repository path would appear. The expansion and contraction beats both state explicitly: "I have not been able to inspect files inside [that path]." I cannot cite any concrete file path within that repository with confidence. Any future beat that does locate a file must be treated as the first verified datum on this line; until then, all path references are hypothetical.

---

## Recommendations

### R1 — Locate the audit writer (mechanical, single step)

This is the gating action for the entire line. The procedure:

1. Confirm the implementation language of the hngh kernel (resolves F3).
2. Grep the repository for the audit emission site using language-appropriate serialization calls (`json.Marshal`, `serde_json::to_string`, `json.dumps`, `JSON.stringify`, etc.) combined with domain terms (`audit`, `trail`, `log_entry`, `event`).
3. From the single emission site, read the serializer configuration directly. Do **not** infer the byte format from tests, fixtures, or golden files; those may be stale or hand-written.

**Deliverable:** one file path + line range naming the writer. Until this exists, every downstream claim on this line stays unverified. This is not a recommendation to "eventually" do; it is the next idle-host action for this line.

### R2 — Pin the six properties as an explicit target specification

Regardless of what the code does today, hngh-automation should commit to a written spec so that any deviation is *measured*, not *discovered*. The recommended invariants:

| Property | Invariant | Rationale |
|----------|-----------|-----------|
| Key ordering | Fixed, source-defined order (struct/record field order), documented in the spec. Lexicographic sorting is also acceptable but fixed struct order is cheaper to keep stable across refactors. Nondeterministic map iteration is **unacceptable** for byte-level reproducibility. | A consumer that does a byte-compare on two logically identical entries must get identical bytes. |
| Timestamp representation | Pick one: RFC 3339 string with nanosecond precision, **or** integer Unix nanoseconds. Document the choice. Mixed representations across entry types are **unacceptable**. | Cross-entry ordering guarantees require a single total order. |
| Timezone | Normalize to UTC (`Z` suffix for RFC 3339; zero offset) **at write time**, inside the serializer, not at the call site. | Per F4: normalization must be a writer-boundary invariant. Call-site conversion is fragile. |
| Optional fields | Omit absent fields entirely. No `null`, no empty-string sentinels. | Keeps byte size deterministic as a function of content; simplifies golden-file testing. |
| Framing | Newline-delimited JSON (NDJSON): one entry per line, single trailing `\n` per entry, no BOM, no leading/trailing whitespace on the line. | Append-only, stream-parseable, byte-countable without full-document buffering. |
| Escaping / binary | UTF-8 strings with standard JSON escaping (`\uXXXX` for control chars, `\"`, `\\`). Binary payloads hex- or base64-encoded, with the encoding named in the spec. | Prevents ambiguous byte sequences (raw newlines, NUL bytes) from corrupting line framing. |

This spec is a *target*, not a claim about current behavior. It exists so that R1's output can be diffed against it.

### R3 — Enforce through exactly one choke point

The "does it enforce UTC at write time" question becomes trivially answerable if there is exactly one code path from which audit entries are serialized. The recommendation:

- All audit emission must flow through a single function (or method) that owns the serializer configuration.
- That function is the only place where key ordering, timestamp conversion, timezone normalization, and framing are determined.
- Call sites pass *logical* data (structs/records); they do not pre-format timestamps or pre-order keys.

This makes R1's grep a one-hit search and makes F4's writer-boundary invariant structurally guaranteed rather than conventionally hoped-for.

### R4 — Golden-file test suite (post-verification)

Once R1 produces the file path + line range, add a golden-file test that:
- Feeds a fixed set of logical entries (covering all six properties: present/optional fields, boundary timestamps in multiple timezones, binary payloads, max-length strings with escape sequences).
- Asserts the exact byte output (not just parsed-equivalence).
- Pins the key ordering, timestamp format, timezone suffix, framing bytes, and escaping.

This converts the line from "what is the format?" to "the format is X, and this test proves it."

---

## Open Threads

| Thread | Status | Blocking dependency |
|--------|--------|---------------------|
| **O1 — Actual byte format** | Unverified. No source file has been read. The six properties (F1) are the unit of verification; each is currently unknown. | R1 (locate the writer). |
| **O2 — UTC normalization at write time** | Unverified. F4 establishes *where* to look, but no beat has looked. | R1. |
| **O3 — Implementation language** | Unconfirmed (F3). Blocks the grep strategy in R1. | Direct inspection of the repository root or build files. |
| **O4 — Single emission site** | Assumed by R3 but unverified. If multiple writers exist, the choke-point recommendation becomes a refactoring task, not a verification task. | R1 (the grep may return multiple hits). |
| **O5 — Test/fixture staleness** | Unknown whether existing tests or golden files reflect current serializer behavior. F4's caveat applies: do not infer from fixtures. | R1 + R4. |

No thread can be closed without repository access. The line is contracted with these threads explicitly open, not silently dropped.

---

## What this line does **not** claim

- It does **not** claim that hngh's audit trail uses any specific format (NDJSON, JSON array, protobuf, etc.).
- It does **not** claim that UTC normalization is or is not enforced at write time.
- It does **not** cite any file path within `[redacted path] as verified.
- It does **not** assert that the implementation language is Go, Rust, Python, JavaScript, or any other.
- It does **not** treat the prior-art sources (OSV, SLSA, AgentSpec, MisakaNet) as evidence for or against any specific byte format. They were consulted and found non-determinative; that is the finding.

---

## References

The following are the only materials this summary is grounded in. No file path within `[redacted path] is cited because none has been verified to exist in any beat on this line.

- **Prior material, expansion beat (2026-09-20):** Established the six-property decomposition (F1), the writer-boundary principle (F4), and the language-dependence of the search strategy (F3). Carries the verification caveat that the target repository was inaccessible.
- **Prior material, contraction beat (2026-09-20, truncated at 4000 bytes):** Provided Recommendations R1–R3 in draft form. The third recommendation was cut off mid-sentence; this summary completes it as R3 above based on the visible context and the line's stated question.
- **Prior art: `[[sources/SRC-2026-08-24-034]]` — OSV Schema (Open Source Vulnerability format).** Consulted during expansion. Does not specify an operational audit-trail serialization format. Non-determinative for this line.
- **Prior art: `[[sources/SRC-2026-08-24-006]]` — SLSA Supply Chain Levels.** Consulted during expansion. Addresses provenance and build-level attestation, not per-entry byte serialization of an audit trail. Non-determinative for this line.
- **Prior art: `[[sources/SRC-2026-08-24-003]]` — AgentSpec: Customizable Runtime Enforcement for Safe LLM Agents.** Consulted during expansion. Addresses runtime enforcement semantics, not persistence framing of audit entries. Non-determinative for this line.
- **Prior art: `[[sources/SRC-2026-08-24-011]]` — MisakaNet Trust Semantics: Evidence Levels and Lesson Verification.** Consulted during expansion. Addresses evidence-level taxonomy, not byte-level serialization. Non-determinative for this line.
- **Prior art: `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson (file-path resolution).** Meta-lesson about the difficulty of resolving exact file paths in a research process. Informs the verification caveat carried throughout this line.
- **Prior art: `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` — Research Lesson (surviving-class confirmation).** Meta-lesson about confirming a single surviving class on a host. Informs the "single emission site" assumption in R3/O4.

No external source beyond the above prior-art pointers is cited. No file path within the hngh kernel repository is cited. If any future beat produces a verified file path, it should be appended here and the corresponding open thread (O1–O5) closed or narrowed accordingly.
