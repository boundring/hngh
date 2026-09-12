# Which comedy dramatization plot types (incongruity, escalation, reversal, slapstick, deadpan) map cleanly onto CAMEO event lanes (conflict/cooperation/aid/yield) for procedural gag generation, with what attribution-safety boundaries?

Status: crystallized 2026-09-12 from research line `dramatization-plot-taxonomy`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-dramatization-plot-taxonomy.md.

# research beat — crystallization (final record)

_line: Which comedy dramatization plot types (incongruity, escalation, reversal, slapstick, deadpan) map cleanly onto CAMEO event lanes (conflict/cooperation/aid/yield) for procedural gag generation, with what attribution-safety boundaries? | state: contracting -> **closed**_

**Grounding caveat, carried forward and restated for the record:** across this line's beats I have not been able to open the filesystem. The only path cited with confidence remains `research-lines.tsv` (named by the operator). I cannot verify the layout of `/home/bricker/Projects/etc/hngh` or any `hngh-automation` tree, so **no kernel file paths are asserted anywhere below**. The two prior-art vault pointers were supplied read-only and are cited unopened. Anything below that would need repo verification is explicitly flagged rather than asserted.

---

## 1. Findings (the line's lasting answer)

### 1.1 The mapping — four structural types, one presentational type

| Plot type | CAMEO lane mapping | Procedural operator |
|---|---|---|
| **Escalation** | Conflict lane; monotonically worsening intensity across beats | Intensity scheduler — walk severity (Goldstein-style scoring) downward/upward across a beat sequence |
| **Reversal** | Any lane; cleanest in yield | Dyad swap — CAMEO events are directed (Actor1 → Actor2), so reversal is native: flip source and target |
| **Slapstick** | Conflict lane, low-severity codes only | Severity clamp — permit physical-conflict codes, cap consequence |
| **Incongruity** | **Cross-lane** — the joke *is* the mismatch | Code/realization gap: emit a cooperation-coded surface over a conflict-coded structure (or vice versa) |
| **Deadpan** | **No lane** | Realization-layer flag: flat-affect narration of high-intensity structure. Composes with any of the four above; does not compete with them |

This is the line's sharp result: the five-type taxonomy collapses into **four structural operators plus one register flag**. Deadpan was the outlier that clarified the architecture — it forced the distinction between *structure* (what happens, CAMEO-expressible) and *realization* (how it's told, CAMEO-silent).

### 1.2 CAMEO's directed-dyad structure is the load-bearing property

Reversal and incongruity fall out of the data model for free; escalation needs only an intensity field; slapstick needs only a clamp on that field. A gag generator built on `(actor, lane, code, target, intensity)` tuples gets **four plot types from three transforms plus one clamp**. No plot type required an extension to the event model itself — that is the sense in which the mapping is "clean."

*Verification flag:* this claim is about the CAMEO coding scheme's documented structure (directed dyads, intensity/Goldstein scale), not about anything in the local repositories. The line treated CAMEO as external prior art; its specification was never re-verified against an external source during this line, and I flag that here rather than assert it as freshly confirmed.

### 1.3 Attribution-safety boundaries (the line's second question)

- **Hard boundary — conflict and yield lanes:** CAMEO was designed to code *real* actors from news text. Generating conflict-lane or yield-lane events over real named entities fabricates hostile or submissive acts attributable to identifiable parties. These lanes must draw from a **synthetic actor registry only**. No exceptions identified by the line.
- **Soft boundary — cooperation and aid lanes:** lower-risk over real entities, but still fabricate events. Permitted only with an explicit fiction marker; never as a default.
- **Slapstick's clamp doubles as a safety control:** the same severity cap that keeps the gag consequence-free keeps the fabricated act non-defamatory in character. Structural and safety constraints coincide here — a pleasant, non-obvious finding.
- **Deadpan is safety-neutral:** as a realization flag it introduces no new attribution surface, but it can *amplify* an unsafe structure by presenting it as flat fact. Safety checks must run on the structural tuple, before realization — never on the rendered prose.

---

## 2. Recommendations (for whichever host picks them up)

1. **Tuple-first gag IR.** Every gag beat as `(actor, lane, code, target, intensity)`. Implementation-agnostic, testable before any prose realization exists. *(Unverified: where such a module would live in hngh-automation — no path asserted.)*
2. **Plot type = operator, not template.** Escalation, reversal, slapstick, incongruity as transforms over the IR; deadpan as a realization flag consumed downstream. Keeps the structural layer small and the register layer composable.
3. **Safety as a lint pass, not a prompt instruction.** A deterministic validation step rejecting any conflict/yield-lane tuple whose actor or target is absent from the synthetic registry. Auditable, and consistent with what this line has observed of the kernel's preference for mechanism over exhortation *(inference from line context, not from verified kernel source)*.
4. **Fiction markers as IR metadata, not prose garnish.** The soft-boundary marker (§1.3) belongs on the tuple so it survives every realization pass.

---

## 3. Open threads (recorded, not pursued — the line closes with these intact)

- **Goldstein-scale granularity for escalation scheduling.** The line assumed an intensity continuum; the correct step size and beat count for a reliably funny escalation curve is empirical and was never tested. *(Would need external comedic-timing literature — unverified and unattempted.)*
- **Incongruity's detection problem.** Generating a cross-lane mismatch is easy; scoring whether a given mismatch reads as incongruity-*funny* versus merely incoherent is unsolved. Candidate next line.
- **Synthetic actor registry design.** Naming conventions, persistence, and collision-avoidance with real entity names were specified as requirements but never designed.
- **Vault cross-links.** The two prior-art pointers (documentation-refresh attribution record; budget-burn session) were never opened. If the attribution record touches synthetic-actor precedent, it may strengthen §1.3; unverified.
- **No validation against actual CAMEO codebooks.** The mapping rests on the scheme's general structure, not a code-level audit of lane definitions.

---

## 4. Lifecycle note

This line has said what it has to say: the taxonomy question is answered (§1.1), the mechanism is identified (§1.2), the safety boundaries are drawn (§1.3), and the residue is properly filed as open threads rather than loose ends. Recommended `research-lines.tsv` transition: **contracting → closed**. The incongruity-detection problem (§3) is the strongest candidate for a successor line.

## References

- `research-lines.tsv` — line state ledger (path named by operator; cited with confidence, contents not re-verified this beat)
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (named by operator; **layout unverified — no files within it are cited**)
- `[[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]]` — llm-wiki vault pointer, read-only, unopened
- `[[sources/session-budget-burn-prevents-discretionary-plan-selection]]` — llm-wiki vault pointer, read-only, unopened
- CAMEO event-coding scheme and Goldstein intensity scale — external prior art relied on conceptually throughout; **not re-verified against external sources during this line**
