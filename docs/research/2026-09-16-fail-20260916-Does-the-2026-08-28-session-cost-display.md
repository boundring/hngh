# Does the `2026-08-28-session-cost-display.md` intent document specify a single canonical formatting function or module path that both dashboard surfaces should import?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-2026-08-28-session-cost-display`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-2026-08-28-session-cost-display.md.

# Contracted Research Record

**Line:** Does the `2026-08-28-session-cost-display.md` intent document specify a single canonical formatting function or module path that both dashboard surfaces should import?  
**Lifecycle state:** contracting  
**Contracted result:** Unresolved. From the supplied record, there is no verified basis to answer yes or no. No concrete file in `~/Projects/etc/hngh` has been confirmed as containing the relevant specification, and no import graph for either dashboard surface has been verified.

---

## Findings

### F1 — The question is not answered by verified repository evidence in this record

The supplied prior material states that the earlier expansion produced **zero verified findings**. It explicitly says the model could not confirm the existence or contents of `2026-08-28-session-cost-display.md`, and no file path in `~/Projects/etc/hngh` was confirmed.

Therefore, this contraction cannot claim:

- that the intent document exists,
- that it specifies a canonical formatting function,
- that it specifies a canonical module path,
- or that both dashboard surfaces import from that canonical location.

### F2 — No canonical formatting function or module path has been established for both dashboard surfaces

No verified claim in the supplied material identifies:

- a concrete module path,
- a concrete exported function name,
- a concrete import statement,
- or a concrete pair of dashboard surface entry points that both consume the same formatter.

The line therefore remains open on the central technical question: **whether a single canonical formatting implementation is specified and actually used by both surfaces.**

### F3 — A drift concern is present in the prior art, but it does not resolve this line

The supplied prior material names vault entries associated with drift concerns:

- `LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha`
- `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca`

These are relevant context, but they do not establish the canonical-module question. They indicate that drift is a live concern in this project; they do not prove whether `2026-08-28-session-cost-display.md` specifies a canonical formatter or whether both dashboard surfaces comply with it.

### F4 — The Architectural Charter pointer is present, but its content has not been verified here

The supplied prior material references:

- `SRC-2026-08-18-001` — Hngh Project Intent and Architectural Charter

However, the prior material also states that this source was referenced as prior art but its content was not extracted or cited in the expansion beat. Therefore, no claim can be made here about whether the charter defines a module-resolution policy, shared-utility convention, or canonical formatting requirement.

### F5 — No external sources were used to resolve the line

No external documentation, issue tracker, package registry, or third-party source was verified in this contraction. Any claim requiring such a source would be explicitly marked as unverified rather than asserted.

---

## Recommendations

These are the concrete verification steps required to close or re-open this line with evidence.

### R1 — Locate and read the intent document

This is the blocking step. No other recommendation can be completed until the target artifact is located or its absence is verified in the repository.

Search for the exact named file:

```bash
find ~/Projects/etc/hngh -name "2026-08-28-session-cost-display.md" -type f 2>/dev/null
```

If it is found, read it in full and extract:

1. Whether it names a **single canonical formatting function**.
2. Whether it

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
