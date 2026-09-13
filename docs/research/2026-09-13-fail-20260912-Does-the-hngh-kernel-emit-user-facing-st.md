# Does the hngh kernel emit user-facing strings (error messages, status output, commit trailers) that constitute a third voice lane requiring assessment against the four moves and the register-law?

Status: crystallized 2026-09-13 from research line `fail-20260912-Does-the-hngh-kernel-emit-user-facing-st`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-Does-the-hngh-kernel-emit-user-facing-st.md.

# Research Line: hngh Kernel User-Facing Strings as a Third Voice Lane

**Lifecycle state:** contracting → **closed (crystallized)**
**This transition:** Final structured summary — the line's lasting record.

---

## Verification Status for This Transition

As in the prior beat, no filesystem or shell access was available in this transition. I could not open `/home/bricker/Projects/etc/hngh` or enumerate its contents. The repository's existence and location are asserted by the operator's prompt; **no file paths inside the repository are verified**. Per the line's ground rules, nothing below asserts a concrete internal path. The vault pointers supplied as prior art are treated as read-only anchors. Claims that would require kernel source are marked **[unverified]**; claims resting on structural reasoning about what an interposing agent kernel *must* do stand on their own.

---

## Question Restated

Does the hngh kernel emit user-facing strings — error messages, status output, commit trailers — that constitute a third voice lane (alongside operator and agent) requiring assessment against the four moves and the register-law?

**Answer: Yes, structurally.** The line closes on this answer with the qualifications and obligations below.

## Findings (Final Form)

**F1 — The third lane exists by construction.**
A kernel interposing between operator and ledger cannot be silent: it must report errors, gate outcomes, and write ledger annotations. The existence of the lane does not depend on any census; only its *size and shape* do. The operative risk is not that the lane exists but that its strings accrete without ever being assessed as utterances.

**F2 — The lane is heterogeneous; sub-lanes carry different register obligations.**
At minimum three sub-lanes, with different persistence and context profiles:
- *Ephemeral operator-facing output* (stderr/stdout errors, warnings) — evaporates, but is read as an utterance in the moment.
- *Async gate status* — interleaves with unrelated operator input ([[sources/long-gates-run-async-against-interjections]]), creating an attribution-ambiguity hazard: a bare status line can be misread as a response to an interjection.
- *Commit trailers / ledger-persistent strings* — persist into the record and are read by future parties as fact. Precedent: [[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]] shows a representation layer fabricating facts about commits; trailers are exactly the surface where the kernel can silently author ledger content.

**F3 — The register-law applies in full to ledger-persistent strings; the four moves apply everywhere.**
Error output that misattributes cause, status output that misattributes speaker, or trailers that misattribute authorship are register violations, not cosmetic defects. Persistence raises the bar: trailers must satisfy the register-law in full, not merely the four moves.

**F4 — Sandbox-only observation underrepresents the lane.**
Per [[sources/debug-repro-sandboxes-only]], sandbox populations diverge from live ones (mocked backends, shortened or absent messages). Any census or audit run only against sandboxes will systematically undercount the live third lane and cannot ground a "the lane is small" conclusion.

## Recommendations (Standing)

- **R1 — Default-to-utterance rule.** Every kernel-emitted string reaching an operator-facing surface or the ledger is a register event until individually proven otherwise. The burden of proof is inverted: neutrality must be argued, not assumed.
- **R2 — Emission census.** When a host is available, enumerate emission sites across the kernel source (e.g., `rg -n 'eprintln!|println!|bail!|anyhow!|error!|warn!|info!|debug!' /home/bricker/Projects/etc/hngh/src` — path pattern **[unverified]**, adjust to actual layout), classify each site by sub-lane (F2), and record the assessment per site.
- **R3 — Trailer audit.** Determine whether the kernel writes commit trailers (attribution, provenance, automation markers) **[unverified]**. If any exist, assess each against the register-law in full. This is the highest-stakes sub-lane and should be audited first.
- **R4 — Async status attribution.** Require every async gate status emission to carry unambiguous self-attribution (prefix or structural marker identifying it as gate output, not a reply). Assess these strings against the four moves *in their interleaving context*, not in isolation.
- **R5 — Dual-environment auditing.** Run any lane audit against both sandbox and live-equivalent paths, or explicitly scope to one and document the expected delta. A sandbox-only census is insufficient evidence about the live lane.
- **R6 — Assessment-at-authoring-time.** New emission sites added to the kernel should carry their four-moves/register assessment at the point of authorship, the way the lane's default-to-utterance rule demands — retrofitting assessments onto accreted strings is the failure mode this line was opened to catch.

## Open Threads (Handed Off, Not Resolved)

- **T1 — Trailer existence and content.** Whether the kernel emits commit trailers at all, and if so their exact schema, remains **[unverified]**. R3 is the entry point.
- **T2 — Census results.** The size and sub-lane distribution of the emission surface is unknown until R2 runs on a host.
- **T3 — Live/sandbox delta measurement.** F4 predicts divergence; its magnitude is unmeasured. R5 produces this as a byproduct.
- **T4 — Status-line attribution convention.** No concrete marker format was adopted in this line; choosing one is a kernel design decision, deferred to [[sources/SRC-2026-08-24-023]] (Hngh Decisions Register) as the appropriate venue.
- **T5 — Tooling.** Whether the four-moves/register assessment of emission sites can be partially mechanized (lint-level checks for unattributed status output, unmarked trailers) was not explored.

## Line Disposition

The motivating question is answered at the structural level, and every finding that required empirical access has been converted into a standing recommendation or an explicitly scoped open thread. Nothing further is gained by keeping the line in motion without a host that can reach the kernel repository; the open threads above are the correct activation conditions for any successor line.

---

## References

Verified as existing (operator-supplied in this transition's prompt):

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (root path asserted by operator; internal structure unverified).

Prior-art pointers (llm-wiki vault; read-only anchors, used as supplied):

- [[entities/hngh]] — Hngh Agent Kernel
- [[sources/SRC-2026-08-24-023]] — Hngh Decisions Register
- [[sources/debug-repro-sandboxes-only]] — Debug repros must run in sandboxes, never against live ledgers
- [[sources/long-gates-run-async-against-interjections]] — Run long verification gates async so interjections don't block
- [[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]] — Local-time git date display fabricates missing commits

Unverified / explicitly not asserted:

- Any path inside `/home/bricker/Projects/etc/hngh` (e.g., `src/`, module names, emission-site locations) — named only as search-pattern examples pending R2.
- External sources: none were needed for the structural findings; none are asserted.
