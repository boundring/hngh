# Is there a defined "audit log" facility in `hngh-automation` that is itself sealed/signed, as required by R2/R4, or would this need to be built from scratch?

Status: crystallized 2026-09-17 from research line `fail-20260917-Is-there-a-defined-audit-log-facility-in`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Is-there-a-defined-audit-log-facility-in.md.

# Research Line — Contracting (Final Structured Summary)

**Line:** Is there a defined "audit log" facility in `hngh-automation` that is itself sealed/signed, as required by R2/R4, or would this need to be built from scratch?

**State transition:** expanding → contracting (final record)

---

## Findings

### 1. Audit-related work exists but its sealing/signing posture is unconfirmed

The prior observation `obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au…` (truncated in the vault index) indicates that an **attribution record and audit** component was touched during a post-rung-11 documentation refresh. This strongly implies that *some* audit-log surface exists in `hngh-automation`—at minimum as an attribution/record-keeping layer. However, the observation title alone does not confirm whether that facility is:

- **sealed** (tamper-evident, e.g., hash-chained or Merkle-rooted),
- **signed** (cryptographically attested by a key whose provenance is governed by R2/R4),
- or merely a plain append-only log with no integrity guarantee.

I cannot verify the internal structure of the audit facility from here. The prior beat's `[redacted path]` placeholders confirm that at least one pass through this material produced paths the researcher was not confident enough to commit, and I will not propagate them.

### 2. R2/R4 requirements are external to the repositories in question

R2 and R4 appear to be requirement identifiers from a security or compliance model (likely an internal runbook, threat model, or attestation spec) that *governs* `hngh-automation` but is not itself a file inside either repository. I have no verified path for the document that defines R2/R4. **This is an explicit gap:** the exact wording of "sealed" and "signed" as R2/R4 define them—hash-chain vs. signature, which key, what revocation policy—cannot be confirmed from the material available to this line. If a spec file exists (e.g., under a `docs/`, `spec/`, or `R*` naming convention in either repo), it was not surfaced in the prior beats.

### 3. Operational infrastructure is live but orthogonal to audit sealing

The observation `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` confirms that an overnight harness in `hngh-automation` was built, verified, and enabled. This tells us the automation pipeline is operational, but it says nothing about whether the audit log *within* that pipeline meets R2/R4. The harness being "enabled" is a liveness property, not an integrity property.

### 4. Known path-collision issue in worker scratch store

The observation `obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes` documents that the hngh worker's wake scratch store has a path-collision bug across wakes. This is relevant context: if audit records are written to or derived from scratch-store paths, a collision could corrupt or conflate audit entries, which would be a direct R2/R4 integrity violation even before considering sealing/signing.

### 5. No evidence of a purpose-built sealed-audit subsystem in the kernel repo

The hngh kernel repository at `[redacted path] is referenced as the second grounding source, but no prior beat on this line surfaced a specific file path within it that implements a sealed/signed audit log. The absence of such a citation in the expanding phase—combined with the fact that the question was still open at contracting time—is weak evidence (not proof) that no dedicated sealed-audit facility exists in the kernel repo either. I flag this as **absence of evidence, not evidence of absence**.

---

## Recommendations

1. **Locate and read the R2/R4 spec.** Before any build decision, the exact requirements must be pinned down: what constitutes "sealed" (hash-chain? append-only with periodic Merkle root publication?), what constitutes "signed" (which key, which signature scheme, who holds the private key, what is the revocation/rotation policy?). If the spec lives in a file inside either repository, it should be cited by path in the next beat. If it lives outside both repositories (e.g., in a separate compliance repo or a runbook), that external source must be named and its authority established.

2. **Audit the existing attribution/audit surface.** The post-rung-11 work touched an "attribution record and audit" component. A focused pass should open that file (or set of files) in `hngh-automation` and determine:
   - Is it append-only?
   - Does it carry per-entry hashes or a running chain root?
   - Is there any signature (HMAC, Ed25519, etc.) on entries or on periodic checkpoints?
   - Is the signing key's provenance governed by R2/R4, or is it ad hoc?

3. **Assess the scratch-store collision as an audit-integrity risk.** If audit records are written to paths under the worker scratch store, the documented collision bug (`obs-2026-08-26`) means entries from different wakes can overwrite each other. This must be fixed *before* or *concurrently with* any sealing work, because a sealed log that silently drops entries is worse than an unsigned one: it gives false assurance.

4. **Decision fork (build vs. extend):**
   - If the existing attribution/audit surface already carries per-entry integrity and a signing path aligned to R2/R4, the line closes as **"exists, verify conformance."**
   - If it is a plain log with no sealing or signing, the work is **not from scratch** (the append/record layer exists) but the **sealing/signing layer must be built and integrated.** This is a materially smaller task than a from-scratch build: you are adding an integrity wrapper around an existing write path, not designing the log format, storage, and lifecycle.
   - If no audit surface exists at all (contradicting finding 1), then it is a from-scratch build, and the scratch-store collision fix becomes a prerequisite.

5. **Do not conflate "enabled" with "sealed."** The overnight harness being live does not satisfy R2/R4. Any future observation or status report should track these as separate properties.

---

## Open Threads

| # | Thread | Why it stays open |
|---|--------|-------------------|
| O1 | Exact R2/R4 spec text and location | Not found in either repository by prior beats; may be external. Must be located before the build/extend decision is final. |
| O2 | Internal structure of the attribution/audit component | The post-rung-11 observation confirms it was touched, but no file path or structural detail was committed to this line (prior beat used `[redacted path]`). A focused read is needed. |
| O3 | Whether the kernel repo (`[redacted path] contains any audit-primitive (hash-chain helper, signing utility) that `hngh-automation` could link against | No prior beat surfaced a path. Absence of evidence in the expanding phase is not proof of absence. |
| O4 | Interaction between scratch-store collision and audit-record integrity | The collision bug is documented; its impact on audit entries is unassessed. Needs a targeted check: do audit writes go through the scratch store? |
| O5 | Key-management / revocation model for any signing that R2/R4 requires | Even if a signing step is added, the key lifecycle (generation, storage, rotation, revocation) must satisfy whatever R2/R4 mandate. No prior beat addressed this. |

---

## References

All references below are to material surfaced in the prior beats of this line or to the two grounding repositories named in the line's charter. I cite only what I am confident exists as a *reference target*; I do not assert internal file paths that were redacted or unverified in prior passes.

- **Repository (grounding source 1):** `hngh-automation` — the automation repository under investigation. No specific internal file path is cited here because the prior beat's `[redacted path]` placeholders were not verified, and I will not propagate them.
- **Repository (grounding source 2):** `[redacted path] — the hngh kernel repository. Cited as a grounding source per the line's charter; no specific internal file path is asserted.
- **Observation:** `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` — confirms operational liveness of the overnight harness in `hngh-automation`.
- **Observation:** `obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au…` (title truncated in vault index) — indicates an attribution/audit component was modified post-rung-11. This is the primary evidence that *some* audit surface exists.
- **Observation:** `obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes` — documents a path-collision bug in the worker scratch store; relevant to audit-integrity risk (finding 4, open thread O4).
- **Prior research lessons (llm-wiki vault):** `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-…` and `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca…` — prior failed passes on closely related questions; their failure modes (redacted paths, unverified citations) are the reason this contracting pass explicitly withholds any path it cannot verify.
- **External / unverifiable:** The R2/R4 requirement specification. I have no verified source for its text, location, or authority. Any claim about what R2/R4 specifically mandate is **unverified** and flagged as such throughout this summary.

---

*Line state: contracted. This summary is the lasting record of the line. Open threads O1–O5 are handed to any successor line that picks up audit-sealing work; they are not closed by this contraction.*
