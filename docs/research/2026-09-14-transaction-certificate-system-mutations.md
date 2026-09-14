# What certificate shape lets one certificate cover a multi-dependency system mutation (one action over a closed artifact set with an aggregate hash, git-commit-shaped) so Rung D package/config operations ride the existing one-action-per-certificate mutation adapter without a blank permission slip or a daemon?

Status: crystallized 2026-09-14 from research line `transaction-certificate-system-mutations`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-transaction-certificate-system-mutations.md.

# Research Line Contract: Aggregate-Hash Certificates for Multi-Dependency Mutations

**Line:** What certificate shape lets one certificate cover a multi-dependency system mutation (one action over a closed artifact set with an aggregate hash, git-commit-shaped) so Rung D package/config operations ride the existing one-action-per-certificate mutation adapter without a blank permission slip or a daemon?

**State: contracting → crystallized (final record)**

---

## Findings

### F1. The git commit object is the correct structural template

A git commit object carries exactly four logical fields: tree hash, parent hashes, author/committer metadata, and (in signed commits) a signature over the canonical encoding of the preceding fields. This maps one-to-one onto the multi-dependency mutation certificate:

| Git commit field | Certificate analogue |
|---|---|
| `tree` (blob of file contents) | `aggregate_hash` (digest over closed artifact set) |
| `parent[]` | `parent_cert_hashes[]` (linear ordering / history) |
| `author` / `committer` + timestamp | `action_descriptor` + signing identity + epoch |
| PGP/Ed25519 signature over canonical bytes | `signature` over fields 1–3 |

The critical property is **offline verifiability**: a verifier with the certificate and the artifact set can recompute the aggregate hash, check the signature, and validate ordering—no network call, no daemon, no external authority. This is the same reason git commits are self-contained: the tree hash *is* the closure proof.

This aligns with the SLSA supply-chain principle (prior art `SRC-2026-08-24-006`) that provenance records must be verifiable without trusting a central registry, and with the DCO model (`SRC-2026-08-24-015`) where a signed attestation travels *with* the artifact rather than being looked up.

### F2. Aggregate hashing over a canonicalized closed set is what makes "one action" honest

A multi-dependency system mutation (e.g., install packages A, B, C and write config files X, Y) is **one action** only if the certificate pins the *entire* artifact set at sign time. The aggregate hash is computed over:

1. Every artifact explicitly enumerated (no open slots, no "latest" or "any").
2. Entries sorted lexicographically by `(name, version)` to eliminate ordering ambiguity.
3. Each entry encoded as `{name, version, content_hash}` in a length-prefixed, deterministic serialization.
4. A single SHA-256 (or stronger) digest over the concatenated encoding.

This is structurally identical to how a git tree object hashes its sorted entries: the tree hash *is* the proof that "these exact files, at these exact paths, with these exact contents, constitute the state." No resolver specification appears in the certificate; only resolved artifacts do.

### F3. Canonicalization-at-sign-time is the anti-blank-permission-slip invariant

A "blank permission slip" occurs when a certificate says "install package X" and the adapter resolves X to whatever version the registry currently serves at apply time. The invariant that prevents this:

> **The adapter must not re-resolve dependencies at apply time.** It recomputes the aggregate hash over the *certified* artifact set (the exact entries in the certificate) and compares it to the certified `aggregate_hash`. If the local environment has drifted (a package was updated, a config file changed), the recomputed hash diverges and the action **fails closed**.

This is a liveness check, not a freshness check: it verifies that *this specific set of bytes* is what will be applied, not that "something compatible" exists. The DCO model reinforces this—attestation binds to exact content, not to a policy description.

### F4. Moment-of-action freshness handles the temporal dimension without a daemon

The prior art concept `moment-of-action-freshness` (llm-wiki vault) establishes that attestation validity is rechecked at the moment of action, not continuously. For this certificate shape:

- The certificate carries a signing epoch (Unix timestamp or monotonic sequence).
- At apply time, the adapter checks that `now - signing_epoch ≤ max_freshness_window`.
- This is a **local** check against wall clock (or a trusted time source if available); it does not require contacting an authority.
- The window bounds replay: a certificate signed 48 hours ago for a package install is rejected even if the aggregate hash still matches.

This is distinct from F3's liveness check. F3 says "the bytes match what was certified." F4 says "the certification is recent enough to be meaningful." Both are local, stateless checks. No daemon is needed for either.

### F5. The existing one-action-per-certificate adapter is the correct integration point

The line's constraint is that Rung D package/config operations must ride the *existing* mutation adapter without modification to its fundamental contract (one certificate → one action → verify → apply). The aggregate-hash certificate satisfies this because:

- It **is** one certificate (one signature, one `aggregate_hash`, one `action_descriptor`).
- The adapter's existing verify path (check signature, recompute hash, compare) works unchanged.
- The "multi-dependency" is internal to the certificate's payload; the adapter sees a single atomic action whose success/failure is all-or-nothing over the closed set.

No new adapter, no daemon, no side-channel state. The multi-dependency complexity is *inside* the certificate, not in the execution path.

### F6. Git Back Dots and ceremony-loop mechanics constrain the vocabulary

The prior art `Git Back Dots` (`SRC-2026-08-18-007`) and `hngh-ceremony-loop-mechanics` establish that hngh operations use **closed vocabularies** and **path positioning**: every action name, target path, and artifact identifier must be drawn from a pre-declared set. The certificate's `action_descriptor` field must therefore not be free-form; it must reference a vocabulary entry (e.g., `rung_d_package_install`, `rung_d_config_write`) that the adapter recognizes. This is consistent with the git commit model where the "type" of change is implicit in the tree diff, but here it is made explicit because the adapter dispatches on it.

I note that I have not been able to open `/home/bricker/Projects/etc/hngh` to verify the specific vocabulary tokens or the adapter's dispatch table. The closed-vocabulary constraint is asserted from the prior art pointer; the exact token names are an open thread (see OT-3).

---

## Recommendations

### R1. Adopt the git commit object as the certificate schema

The certificate record contains exactly these fields, in this order of logical dependency:

```
{
  "aggregate_hash": "<hex>",          // SHA-256 over canonical artifact-set encoding
  "parent_cert_hashes": ["<hex>"],    // zero or more; linear history
  "action_descriptor": {
    "type": "<vocab_token>",           // e.g. "rung_d_package_install"
    "target_rung": "D",
    "epoch": <unix_seconds>           // signing time
  },
  "signature": "<base64>"            // Ed25519 over canonical encoding of fields above
}
```

- `aggregate_hash` is the tree-hash analogue: it *is* the closure proof.
- `parent_cert_hashes` provides ordering without a global sequence number (git-style DAG, though in practice Rung D mutations will be linear).
- `action_descriptor.type` must be a token from the Rung D closed vocabulary (per F6). I cannot verify the exact token strings in the hngh kernel; this is an open thread.
- `signature` uses Ed25519 (or the key type the existing adapter already trusts). The signing key identity is established out-of-band (same as git commit GPG keys); it is not embedded in the certificate beyond the signature itself.

**Why this rides the existing adapter:** The adapter's verify path is `parse → recompute aggregate_hash → compare → check signature → dispatch on action_descriptor.type`. No new code paths are introduced. The multi-dependency set is opaque to the adapter; it only sees one hash and one action type.

### R2. Enforce canonicalization at sign time; prohibit re-resolution at apply time

The signing tool (not the adapter) computes `aggregate_hash` over:

1. **Closed set:** Every artifact is explicitly enumerated. No wildcards, no "latest", no resolver spec.
2. **Canonical order:** Entries sorted lexicographically by `(name, version)` string.
3. **Entry encoding:** Each entry is `{name: String, version: String, content_hash: String}` serialized in a fixed format (e.g., JSON with sorted keys, or a length-prefixed binary TLV). The exact serialization must be specified in the signing tool's source and documented; it must be deterministic across platforms.
4. **Digest:** SHA-256 over the length-prefixed concatenation of all serialized entries.

**Prohibition (hard invariant):** The adapter, at apply time, does **not** contact a package registry, does **not** run a resolver, and does **not** substitute "compatible" versions. It takes the certified entries verbatim, fetches or locates each artifact by `content_hash`, recomputes the aggregate hash over the located set, and compares to the certified value. Any divergence → action fails, nothing is applied (atomic all-or-nothing).

This is the anti-blank-permission-slip guarantee. A certificate for "install foo@1.2.3, bar@4.5.6" cannot silently become "install foo@1.9.0, bar@4.5.6" because the aggregate hash would not match.

### R3. Implement moment-of-action freshness recheck at apply time

At apply time, after signature verification and before dispatch:

```
if (now_unix - action_descriptor.epoch > max_freshness_window):
    reject("certificate stale")
```

- `max_freshness_window` is a configuration parameter on the adapter (default suggested: 300 seconds for interactive Rung D operations; longer for batched ceremony loops). I cannot verify what window the existing hngh ceremony loop uses; this is an open thread.
- The check is **local**: it compares against the host's wall clock (or a trusted time source if the deployment provides one). No network call.
- This prevents replay: a validly signed certificate from yesterday cannot be re-applied today.
- This is complementary to R2's liveness check. R2 says "the bytes are what was certified." R3 says "the certification is recent enough to matter."

The prior art `moment-of-action-freshness` concept supports this pattern: validity is a property checked at the moment of action, not a continuously monitored state. No daemon, no heartbeat, no liveness probe.

### R4. The certificate is self-contained; no sidecar, no manifest file, no registry lookup

The entire verification path is:

```
1. Parse certificate (fields above).
2. Verify signature over canonical encoding of fields 1–3.
3. Check freshness (R3).
4. For each entry in the certified artifact set:
   a. Locate the artifact locally by content_hash (or fetch from a pinned mirror by content_hash—never by name+version alone).
   b. Verify the located artifact's hash matches the entry's content_hash.
5. Recompute aggregate_hash over all entries; compare to certified value.
6. If all pass: dispatch action_descriptor.type via existing adapter path.
7. If any fail: reject atomically; apply nothing.
```

No sidecar file, no separate manifest, no "trust this registry" step. The certificate *is* the authorization and the specification. This mirrors how a signed git commit is self-contained: you can verify it with `git verify-commit` and the object store, no server needed.

---

## Open Threads

**OT-1. Exact serialization format for artifact-set entries.**
R2 specifies the logical structure but not the byte-level encoding. The signing tool and the adapter must agree on a single canonical form (JSON-with-sorted-keys vs.

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
