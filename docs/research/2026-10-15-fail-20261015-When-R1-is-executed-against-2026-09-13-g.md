# When R1 is executed against 2026-09-13-governed-fleet-consolidation, does the verdict change after a disposition sweep alone  i.e., can F3 and F4 be separated in two cycles without touching parser code?

Status: crystallized 2026-10-15 from research line `fail-20261015-When-R1-is-executed-against-2026-09-13-g`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261015-When-R1-is-executed-against-2026-09-13-g.md.

# Final Contraction: Sweep-Only Verdict Separation

## Line

When R1 is executed against 2026-09-13-governed-fleet-consolidation, does the verdict change after a disposition sweep alone — i.e., can F3 and F4 be separated in two cycles without touching parser code?

## State

**contracting → final**

## Epistemic Status

This session carries forward the prior beat's constraint: **no filesystem access**. I cannot read `research-lines.tsv`, the kernel at `[redacted path] or the consolidation ledger. The following is a **protocol-level final record**: each recommendation is executable, but each carries an explicit in-repo verification step that must run on the actual system. Claims about file paths are asserted as *to-be-verified targets*, not as confirmed citations.

---

## Findings

### F-1. The line decomposes into two claims

- **Claim A (verdict sensitivity):** Does the disposition sweep alone change R1's verdict against the 2026-09-13 ledger?
- **Claim B (separability):** If the verdict changes, is the change attributable to F3's sweep-touched records, leaving F4's evidence untouched?

### F-2. The cheapest possible win exists (Claim A negative)

If R1's verdict is identical pre- and post-sweep, the line closes immediately: F3 was never sweep-sensitive, the two-cycle plan is unnecessary, and the prior precedent (`backlog-disposition-sweep-reduces-accepted-plans-by-half`) did not transfer to this ledger. This gate must not be skipped.

### F-3. Separability is a set-membership question (Claim B)

If the verdict changes, separability reduces to computing `F4_evidence ∩ sweep_touched_records`. Empty intersection → separation is clean. Non-empty intersection → parser-level tagging or a disposition-freeze snapshot is required. The critical precondition: this join must be computable from R1's existing output. If R1's findings do not name their supporting records, that is an instrumentation gap — but emitting a trace is read-only output plumbing, arguably not "touching parser code."

### F-4. Determinism must be verified before any comparison

Two runs on the same state must agree. If they disagree, no pre/post comparison can attribute anything. The line is unanswerable at R1's current stability and should be closed as "blocked on verifier determinism."

---

## Recommendations

### R-1. Determinism gate (cheapest, highest information)

Run R1 twice against an identical frozen snapshot of the consolidation ledger in a sandbox. If two runs on the same state disagree, close the line as "blocked on verifier determinism."

*Verify in-repo:* Whether hngh-automation already has a fixture/snapshot harness for ledger states. If not, the fixture is the first artifact to build.

### R-2. Verdict-sensitivity gate (answers Claim A)

1. Snapshot the ledger.
2. Record R1's verdict (pre-sweep).
3. Run the evidence-gated disposition sweep against the sandbox copy.
4. Re-run R1 (post-sweep).
5. Diff the verdicts.

- **Identical** → line closed, negative.
- **Different** → proceed to R-3.

### R-3. Separability test as a pure join (answers Claim B without touching parser code)

Compute `F4_evidence ∩ sweep_touched_records`.

- **Empty** → separation is clean. Run F3 in cycle 1 post-sweep, F4 in cycle 2, no parser changes. Line answers in the affirmative.
- **Non-empty** → line answers in the negative. Report which F4 findings were contaminated — that intersection set is the concrete scope of any parser work that follows.

### R-4. Instrumentation gap flag (if R1 findings do not name records)

If R1's findings do not currently name their supporting records, flag this as an instrumentation gap before proceeding. Emitting a trace is read-only output plumbing — do not let this silently redefine "touching parser code."

---

## Open Threads

| Thread | Status | Notes |
|--------|--------|-------|
| R1 determinism verification | Open | Must run in-repo; no sandbox harness confirmed |
| Ledger snapshot harness | Open | To-be-verified in hngh-automation |
| R1 output traceability | Open | Whether findings name supporting records |
| F4_evidence set definition | Open | Must be computable from existing output |
| Sweep_touched_records set definition | Open | Must be computable from existing output |

---

## References

- `[redacted path] — hngh kernel repository root (path given in prompt; existence unverified by this session)
- `research-lines.tsv` — research line state file (referenced in prior material; existence unverified)
- `hngh-automation` — automation harness (referenced in prior material; existence unverified)
- `sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour` — llm-wiki vault note (read-only pointer from prior material)
- `sources/debug-repro-sandboxes-only` — llm-wiki vault note (read-only pointer from prior material)
- `sources/long-gates-run-async-against-interjections` — llm-wiki vault note (read-only pointer from prior material)
- `sources/backlog-disposition-sweep-reduces-accepted-plans-by-half` — llm-wiki vault note (read-only pointer from prior material)

---

## External Sources Disclaimer

This session has no filesystem access and cannot verify the existence of any file paths in the hngh kernel repository or the consolidation ledger. All file path references above are asserted as *to-be-verified targets*. Claims about R1's behavior, the disposition sweep's mechanics, and the ledger's structure are carried forward from prior material and must be validated in-repo before execution. No external sources beyond the llm-wiki vault notes supplied in the prompt were consulted.
