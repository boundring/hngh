# Are there additional surfaces (test fixtures, docs, other repos) containing copies of the patrol verdict rule beyond the two identified in the drift note?

Status: crystallized 2026-09-15 from research line `fail-20260915-Are-there-additional-surfaces-test-fixtu`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Are-there-additional-surfaces-test-fixtu.md.

# Final Structured Summary — Patrol Verdict Rule Surface Bound

**Research line:** Are there additional surfaces (test fixtures, docs, other repos) containing copies of the patrol verdict rule beyond the two identified in the drift note?  
**Lifecycle state:** contracting — final structured record for this transition  
**Process posture:** continuous; the line remains in motion on idle hosts. This is not a batched or periodic pass.

## Epistemic status and verification boundary

This contraction was produced **without live filesystem access** to `hngh/hngh-automation` or to `/home/bricker/Projects/etc/hngh`. Therefore:

- I do **not** assert any repository-internal file paths as confirmed.
- I do **not** restate the exact paths of the two known surfaces, because their identity is established by the drift note in prior material, not independently re-verified here.
- Any claim that would require reading repository contents, test fixtures, documentation files, or other repositories is marked **unverified** rather than asserted.
- The confirmed surface set available to this line remains exactly what the drift note establishes: **two surfaces**. No additional surface is confirmed from this beat.

The search commands in the recommendations are the means by which the surface set becomes closed on an idle host with access. Until those searches are run and their outputs recorded, the answer to the line’s question remains: **not yet proven negative**.

## Contracted question

Bound the full surface set for the patrol verdict rule across `hngh/hngh-automation` and `/home/bricker/Projects/etc/hngh`, determine which surface is the source-of-truth, and make future drift structurally impossible in `hngh/hngh-automation`.

## Findings

### F1 — The confirmed baseline is two surfaces, per the drift note

The prior drift note establishes that the patrol verdict rule exists on **two surfaces** and has drifted between them. That is the only confirmed surface set available in the prior material for this line.

Status: **established by prior material**, but not independently re-verified from this beat.

### F2 — No additional surface is confirmed from this contraction beat

This beat did not execute live searches across repositories, test fixtures, documentation, or other codebases. Consequently, it cannot confirm the existence of any additional copy beyond the two known surfaces.

Status: **absence of confirmation**, not absence of copies.

### F3 — The unexamined surface classes are still open

The line’s question explicitly names three candidate classes that remain open because they have not been searched here:

1. **Test fixtures** in `hngh/hngh-automation` or related test trees.
2. **Documentation surfaces**, including install, timer, harness-health, or operational docs.
3. **Other repositories**, including `/home/bricker/Projects/etc/hngh`.

These are not asserted to contain copies. They are the remaining search space.

Status: **open**.

### F4 — The drift mechanism is duplication without a single source-of-truth

The fact that the rule drifted across two known surfaces implies that at least two independent copies exist and can diverge. The structural problem is not merely that copies exist, but that no surface is designated as the authoritative one, or no guard prevents divergence.

Status: **inferred from the existence of drift**, consistent with the drift note; exact implementation details are not re-verified here.

### F5 — Adjacent observation is context, not confirmed shared rule text

The prior observation pointer concerns a harness-health / timer doc-vs-install drift. It is adjacent context and may share domain vocabulary with the patrol verdict rule, but this beat does **not** verify that it contains the same patrol verdict rule text as the two known surfaces.

Status: **unverified as a third surface**.

## Recommendations

These recommendations are applicable on an idle host with access to `hngh/hngh-automation` and `/home/bricker/Projects/etc/hngh`. They are not claims that any specific file exists.

### R1 — Decompose the rule into atoms before searching

Exact-string grep alone will under-count paraphrased copies. Before searching, extract from the two known surfaces:

- exact literals,
- status strings,
- threshold values,
- function or symbol names,
- short invariant phrases,
- semantic variants likely to appear in docs or fixtures.

Do not assume those atoms here; derive them from the drift note’s recorded rule text or from a live read of the two known surfaces.

### R2 — Run a bounded, reproducible search across both repositories

On an idle host, run searches over:

- `hngh/hngh-automation`
- `/home/bricker/Projects/etc/hngh`

Use both exact and fuzzy patterns. Record:

- the exact commands,
- the repository roots searched,
- the commit or checkout state if available,
- every hit,
- and a classification for each hit.

Example command shapes, to be parameterized with the extracted atoms:

```bash
rg -n -F '<exact-rule-atom>' /home/bricker/Projects/etc/hngh
rg -n -i 'patrol|verdict|healthy|timer' /home/bricker/Projects/etc/hngh
rg -n -F '<exact-rule-atom>' <hngh-automation-checkout>
rg -n -i 'patrol|verdict|healthy|timer' <hngh-automation-checkout>
```

The `<hngh-automation-checkout>` placeholder is intentional: this beat does not assert a local path for `hngh/hngh-automation`.

### R3 — Classify every hit

For each hit, classify it as one of:

- source-of-truth candidate,
- generated artifact,
- test fixture copy,
- documentation paraphrase,
- foreign repository copy,
- incidental lexical match.

Only after classification can the surface set be called closed.

### R4 — Designate exactly one source-of-truth surface

Once all copies are found, choose one surface as authoritative. Prefer:

- a single code module if the rule is executable logic,
- a generated artifact if docs or fixtures must mirror it,
- a test that imports or references the source rather than restating it.

All other surfaces should become references, imports

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
