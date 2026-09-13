# Does the hngh kernel write any commit trailers (attribution, provenance, automation markers), and if so, what is their exact schema as authored ledger content?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-the-hngh-kernel-write-any-commit-tr`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-the-hngh-kernel-write-any-commit-tr.md.

# Research Line — Final Record (contracted)

**Line:** Does the hngh kernel write any commit trailers (attribution, provenance, automation markers), and if so, what is their exact schema as authored ledger content?
**State:** expanding → **contracting** (crystallized; design final, empirical gated on one host pass)
**Resolution status:** The *design contract* is final. The *empirical question* (does the kernel currently write trailers, and in what exact form) is **not resolved by this line** — it is deliberately left as a single open thread because I have no live read access to `/home/bricker/Projects/etc/hngh` here, and the prior beat explicitly deferred all empirical findings to a host-access pass. I do not assert current state below; every such claim is tagged `[UNVERIFIED]`.

---

## Findings

**F1 — Empirical status: unresolved (stated explicitly).**
Whether the hngh kernel writes commit trailers today, and if so their exact authored schema, is **not established**. I cannot verify it from this transition: no live read access to `/home/bricker/Projects/etc/hngh`, and I will not cite concrete file paths in that repo because I cannot confirm they exist. The prior beat deferred all empirical findings to a host pass; this contraction inherits that deferral rather than silently filling the gap. `[UNVERIFIED — stated explicitly]`

**F2 — Load-bearing property (resolvable now).**
The property that makes a trailer schema *sufficient* is **machine-joinability to the evidence ledger**: a trailer value that is a stable ledger-entry identifier, not free text. A single free-text automation marker (e.g. `Generated-by:`) does **not** satisfy this. This follows from H3 in the prior beat and the authored-vs-studied distinction recorded in `obs-2026-08-19`.

**F3 — Minimal sufficient schema (design, not observation).**
The two-key minimum is sufficient to satisfy the authored-vs-studied distinction at commit granularity *and* make commits machine-joinable:
- `Agent: hngh/<cycle-id>` — marks authorship class (autonomous kernel).
- `Ledger: <evidence-ledger-entry-id>` — provides the join into the evidence ledger.

This is a **design recommendation**, not a claim about what the kernel currently writes.

**F4 — Decision structure.**
The empirical question collapses H1–H3 into exactly three terminal branches (A: no trailers; B: stable two-key schema; C: unstable / free-text / missing join). Each maps to a bounded recommendation set. The branch is selected by one cheap verification pass (see V below); the design work is done either way.

**F5 — Attribution constraint.**
Kernel-authored commits must **not** carry human-style attribution trailers (`Signed-off-by:`, `Reviewed-by:`). Doing so conflates autonomous and supervised authorship and breaks the authored-vs-studied distinction flagged in `obs-2026-08-19`.

---

## Recommendations

**Gating step V (run on a host with read access to `/home/bricker/Projects/etc/hngh`):**
```
git log --format='%(trailers)'            # full trailer content, kernel-authored commits
git log --format='%(trailers:keyonly)'   # key inventory only
```
V selects the branch. Everything below is either (a) decidable now or (

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
