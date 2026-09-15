# Does the `research-lines.tsv` schema include a field that explicitly maps each state (e.g., `planned`, `expanding`) to a corresponding page-rendering template or output path?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-research-lines-tsv-schema-inclu`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-research-lines-tsv-schema-inclu.md.

# Contracted Line: State→Template Mapping in `research-lines.tsv`

**Line:** Does the `research-lines.tsv` schema include a field that explicitly maps each state (e.g., `planned`, `expanding`) to a corresponding page-rendering template or output path?
**State:** contracting → **contracted (final)**
**Date:** 2026-09-15

---

## Findings

### F1 — The question decomposes into three structurally distinct answers, and the decomposition is settled.

The expansion beat established that the answer space partitions cleanly:

| Answer | Meaning | Verification cost |
|--------|---------|-------------------|
| **(a)** | `research-lines.tsv` contains an explicit column (e.g., `template_path`, `render_target`) mapping each state value to a template or output path. | One header inspection. |
| **(b)** | The TSV carries no such column; the mapping lives implicitly in renderer code inside the hngh kernel (`/home/bricker/Projects/etc/hngh`), keyed on state strings. | Grep across kernel source for state literals + template logic. |
| **(c)** | No rendering pipeline exists; states are pure lifecycle metadata with no downstream page-rendering coupling. | Absence of templating code in the kernel. |

This triad is the contract's decision tree. It is not re-derivable from first principles each time the line is revisited; treat it as fixed.

### F2 — The method is constrained by prior art, and those constraints are binding.

Two vault entries impose hard procedural rules:

- **`[[sources/grep-tab-escape-matches-nothing]]`** — GNU grep treats `\t` in a pattern as the literal two-character sequence backslash-t, not a tab. Any inspection of `research-lines.tsv` must use `awk -F'\t'`, not `grep -P '\t'`. This is not a style preference; it is a correctness requirement.
- **`[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]`** — The verification step (running the probes) must be logged as a *non-blocking transition artifact*. It must not gate the line's lifecycle state machine. A pending verification result does not freeze the line in `expanding`; the line transitions to `contracting` on schedule regardless of whether the probes have been executed.

### F3 — The operationally significant discriminant is (b) vs. (c), not (a).

Whether `research-lines.tsv` is *self-describing* (answer a: the mapping travels with the file) or *code-coupled* (answer b: the mapping lives in the kernel and the TSV is portable only alongside its renderer) is the only finding that changes downstream automation design. Answer (a), if present, is a one-line header check and is low-value once ruled in or out. The line's lasting record should weight (b)-vs-(c) accordingly.

### F4 — A precondition probe (R2) dominates the mapping probe in cost-benefit order.

If the hngh kernel contains no templating or rendering code at all, answer (c) holds trivially and the state-domain enumeration and state-keyed grep are wasted work. The cheapest first probe is a repo-wide search for any templating artifact. This precondition check was under-weighted in the expansion beat's F1 and should be sequenced *before* the three-step verification of R1.

### F5 — The actual answer to the line's question remains unverified in this repository.

No prior beat on this line has logged the output of any probe against `research-lines.tsv` or `/home/bricker/Projects/etc/hngh`. All findings above are structural (the question is well-posed, the method is constrained, the decision tree is fixed) but the *empirical* answer — which of (a), (b), (c) holds — has not been established. I do not have live filesystem access in this transition and will not assert a specific column name, state domain, or kernel file path without having read it.

---

## Recommendations

These are carried forward from the expansion beat, sequenced per F4, and are the actionable residue of this line. They are intended for execution on an idle host with filesystem access to both `research-lines.tsv` and `/home/bricker/Projects/etc/hngh`.

### R1 — Precondition: does any rendering pipeline exist in the kernel? (Run first.)

```sh
grep -rlniE 'template|render|\.html|jinja|mustache|handlebars' \
     /home/bricker/Projects/etc/hngh \
     --include='*.py' --include='*.sh' --include='*.ts' | head -20
```

- **If this returns nothing:** the line contracts to *"no rendering pipeline; states are pure lifecycle metadata"* (answer c). No further mapping work is warranted. Log the empty result as the transition artifact and close the empirical question.
- **If this returns hits:** proceed to R2. The hits identify candidate renderer files for targeted inspection.

### R2 — Three-step verification as a single atomic artifact, in strict sequence.

Step 2 depends on Step 1's output (the state column index), so these must not be parallelized.

```sh
# Step 1: header inspection — settle answer (a) in one pass
head -1 research-lines.tsv | awk -F'\t' '{for(i=1;i<=NF;i++) print i": "$i}'

# Step 2: enumerate the state domain (substitute N with the index from Step 1)
awk -F'\t' 'NR>1 {print $N}' research-lines.tsv | sort -u

# Step 3: settle (b) vs. (c) — search the kernel for state-keyed rendering logic
grep -rn -e 'planned' -e 'expanding' /home/bricker/Projects/etc/hngh \
     --include='*.py' --include='*.sh' --include='*.ts' -l
```

Log the combined stdout of all three steps as **one** transition artifact. Per `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]`, this artifact is non-blocking: it does not gate the line's state machine.

### R3 — Decide automation design on the (b)-vs-(c) outcome, not on (a).

- **If (a) holds** (explicit column present): the TSV is self-describing. Any consumer can read the template path directly from the file. Automation should treat the column as a first-class schema field and validate its presence in CI.
- **If (b) holds** (code-coupled mapping): the TSV is *not* portable without the kernel renderer. Automation must pin the kernel version alongside the TSV, and any change to state names requires a coordinated edit across both the TSV data and the kernel source. This is the highest-maintenance outcome.
- **If (c) holds** (no rendering): states are metadata only. No template-path field is needed or expected. Automation should not synthesize one.

### R4 — Do not re-open this line on a new beat unless the empirical answer changes.

The structural findings (F1–F4) are stable. The only reason to revisit is if R1/R2 produce output that contradicts the prior beats' assumptions (e.g., a rendering pipeline appears in the kernel after the line was contracted). Absent that, this record is the lasting form of the line.

---

## Open Threads

These are the items that remain genuinely open and require filesystem access to resolve. They are listed so that any future beat on this line knows exactly what is still pending.

1. **The empirical answer (a / b / c) is unknown.** No probe output has been logged on this line. R1 and R2 must be executed on an idle host before the question can be marked empirically settled.
2. **The state domain of `research-lines.tsv` is unenumerated.** Step 2 of R2 has not been run. We do not know whether the file contains only `planned` and `expanding`, or a larger set (e.g., `contracting`, `archived`, `blocked`). This matters for answer (b) because the renderer's state-keyed logic must cover the full domain.
3. **The header of `research-lines.tsv` has not been inspected.** Step 1 of R2 has not been run. We do not know whether a `template_path`, `render_target`, or analogous column exists. This is the one-line check that settles answer (a).
4. **The contents of `/home/bricker/Projects/etc/hngh` are unverified in this transition.** I cite the repository root because it is given as the ground-truth location in the line's scope. I do not assert the existence of any specific file, directory, or module within it. Any claim about kernel internals (e.g., "the renderer lives in `hngh/render.py`") would be unverified and is deliberately omitted here.
5. **Whether the hngh-automation layer (distinct from the kernel) carries its own state-to-template mapping is out of scope for this line.** The question is bounded to `research-lines.tsv` and the hngh kernel. If a separate automation repo exists, it would be a new line, not a re-opening of this one.

---

## References

- `[[sources/grep-tab-escape-matches-nothing]]` — GNU grep treats `\t` as a stray escape; use `awk -F'\t'` for TSV inspection. (Vault pointer; read-only.)
- `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]` — Mid-line verification is a non-blocking transition artifact, not a gate on the state machine. (Vault pointer; read-only.)
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root. Cited as the ground-truth location for probes R1 and R2. Internal file structure unverified in this transition.
- `research-lines.tsv` — The line-state file under investigation. Canonical name; full path not asserted in this record. Header, state domain, and column set are open threads (see Open Threads 2–3).
