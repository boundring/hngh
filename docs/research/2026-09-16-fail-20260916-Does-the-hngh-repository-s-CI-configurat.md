# Does the `hngh` repository's CI configuration (e.g., `.github/workflows/*.yml`) explicitly pin a specific version of `make` or use a container image with a known Make version?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-hngh-repository-s-CI-configurat`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-hngh-repository-s-CI-configurat.md.

# Research Line Contraction: `hngh` CI Make-Version Pinning

**Line:** Does the `hngh` repository's CI configuration (e.g., `.github/workflows/*.yml`) explicitly pin a specific version of `make` or use a container image with a known Make version?

**State:** contracted — final structured summary as lasting record.

**Date:** 2026-09-16

---

## Findings

### F1 — No workflow file has been observed in this repository.

The kernel-repo root `~/Projects/etc/hngh` is the only path treated as a given anchor (supplied in the line). No `.github/workflows/*.yml` file has been read, listed, or confirmed to exist at that location. The prior expansion explicitly records: *"I have not read any workflow file in this repository."*

### F2 — The CI configuration's physical location is unresolved.

The line references `hngh-automation` as a possible separate repository holding the workflows. No checkout path for `hngh-automation` has been confirmed, and no observation distinguishes between:
- Workflows living inside `~/Projects/etc/hngh/.github/workflows/`
- Workflows living in a sibling or separate `hngh-automation` checkout

This is the single gating unknown. No other finding is valid until it resolves.

### F3 — No Makefile version guard has been observed.

No `Makefile`, `GNUmakefile`, or equivalent build-system file at `~/Projects/etc/hngh` (or within two directory levels) has been confirmed to exist, let alone to contain a `MAKE_VERSION` guard of the form `$(error "GNU Make >= X.Y required")`. The second-order coupling mechanism is therefore unassessed.

### F4 — No container image digest or tag has been observed.

No `container:` or `image:` directive in any workflow file has been read. Consequently, no image reference (e.g., `ghcr.io/hngh/ci-runner:<tag>`, `ubuntu:22.04`, a self-hosted runner label) can be classified as explicit pin, effective pin, or moving target.

### F5 — The decision rule is established but unapplied.

The line's crystallized decision rule states:

> The answer is *pinned* only if exactly one observed `make --version` string can be bound to a named mechanism — a YAML version key, a pinned image digest, or a Makefile guard. Anything else (`ubuntu-latest`, an untagged base, a self-hosted host) is a *moving target*, not a pin.

This rule is sound and reusable, but it has **zero observations** to which it can be applied from the current position.

### F6 — External base-image Make versions are explicitly excluded from assertion.

The prior expansion records an honesty boundary: unverified claims such as "ubuntu:22.04 ships make 4.3" are *not* treated as fact. They must be observed on a live host, not assumed from memory or documentation. This boundary is carried into the final record.

---

## Recommendations

Each recommendation is executable on an idle host and ordered by dependency.

### R1 — Resolve the workflow inventory (gates all other work)

```bash
ls -la ~/Projects/etc/hngh/.github/workflows/ 2>/dev/null \
  || echo NO_WORKFLOWS_DIR
```

- **If files are listed:** proceed to R2.
- **If `NO_WORKFLOWS_DIR`:** do *not* conclude "no CI." Re-point the same command at the `hngh-automation` checkout (path must be supplied by the operator; it is not derivable from this position). If that path also yields no workflows, the line's premise (that a CI configuration exists to inspect) is in question and the line should be re-scoped.

### R2 — Single-pass classification grep

Once R1 names files:

```bash
grep -rnE 'make-version|make=|/make:|container:|image:|runs-on|bootstrap' \
  ~/Projects/etc/hngh/.github/workflows/ 2>/dev/null
```

Any hit is a candidate pin. Zero hits means fall through to R3/R4.

### R3 — Classify each hit

| Classification | Mechanism | Verdict |
|---|---|---|
| **Explicit pin** | YAML names a version (`make-version: 'X.Y'`) or bootstrap installs a fixed release | *Pinned.* Record the string. Line may close. |
| **Effective pin** | `container:`/`image:` with a tag (e.g., `ghcr.io/hngh/ci-runner:<tag>`) | *Effectively* pinned but drifts on rebuild. Do **not** trust the tag name for the version; observe it (R5) and record the image **digest**. Recommend pinning by digest. |
| **No stable pin** | `runs-on: ubuntu-latest` or self-hosted label with no in-repo Dockerfile | *Moving target.* Produces an actionable change recommendation. |

### R4 — Check Makefile-side version guards (second-order coupling)

```bash
find ~/Projects/etc/hngh -maxdepth 2 -name 'Makefile*' -print 2>/dev/null \
  | xargs grep -ln 'MAKE_VERSION' 2>/dev/null
```

A guard of the form `$(error "GNU Make >= X.Y required")` (or feature-gated use that silently breaks on older Make) means the CI's effective version is pinned by the build system even when the YAML never names it. Record which mechanism it is.

### R5 — Capture the observed `make --version` string as the evidence artifact

The single most decisive output is one line:

```bash
# Run inside the CI container or on the runner that actually executes the build:
make --version | head -1
```

This string, bound to the mechanism identified in R3/R4, is the line's terminal evidence. Without it, the line remains open.

### R6 — If no stable pin is found, file the change

If R3 yields "moving target" and R4 yields no guard, the actionable recommendation is:

- Pin the container image by **digest** (not tag) in the workflow YAML, or
- Add a `make-version` key to the relevant setup action, or
- Add a Makefile version guard as a belt-and-suspenders measure.

This is a change proposal, not a finding. It belongs in the line's output only if R1–R5 have been executed and produced a negative result.

---

## Open Threads

| Thread | Status | Blocking condition |
|---|---|---|
| **Location of CI config** | Open | R1 must be executed on an idle host with access to the correct checkout. No path for `hngh-automation` is known from this position. |
| **Observed `make --version` string** | Open | Requires a live runner or container execution (R5). Cannot be resolved by static file inspection alone if the version is determined by image build time. |
| **Makefile guard presence** | Open | R4 must be executed. No Makefile has been confirmed to exist at the kernel-repo root. |
| **Image digest vs. tag** | Open | If an effective pin is found (R3), the digest must be pulled and recorded. Tag names are not stable identifiers. |
| **`hngh-automation` repo scope** | Open | Whether `hngh-automation` is a separate repository, a subdirectory, or a CI-only service is unconfirmed. The line's premise assumes it exists; its physical form is unknown. |

---

## Terminal Verdict

**Undetermined.** From the current position, no workflow file, container image reference, Makefile guard, or observed `make --version` string has been read. The decision rule is established and the recommendation sequence (R1→R6) is complete and executable, but **zero observations** have been recorded. The line cannot be closed as "pinned" or "not pinned" without executing R1 on an idle host with access to the correct checkout.

The line's lasting contribution is:
1. A **decision rule** that distinguishes explicit pin, effective pin, and moving target.
2. An **ordered probe sequence** (R1–R5) that any operator can execute in under five minutes on a single host.
3. An **honesty boundary** that excludes unverified external base-image version claims from the evidence ledger.

---

## References

- `~/Projects/etc/hngh` — kernel-repo root; the only path treated as a given anchor in this line. No sub-paths within it have been confirmed to exist beyond the root itself.
- Prior material, beat 2026-09-16 (expansion → contracting transition) — source of the decision rule, honesty boundary, and recommendation sequence R1–R6 as carried into this contraction.
- `[[concepts/evidence-ledger]]` — authority and evidence ledger; governs the requirement that every claim be bound to an observed artifact rather than an assumed external fact.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — prior research lesson on the same line; documents the failure mode of asserting CI configuration without having read the workflow files.
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — prior research lesson on schema inclusion for research lines; relevant to the format of this contraction record.

*No `.github/workflows/*.yml`, `Makefile`, `Dockerfile`, or container image reference is cited as a confirmed path because none has been observed from this position. Any such path appearing in future beats must be preceded by the R1 `ls` probe and recorded with its output.*
