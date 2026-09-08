# At equal task quality, when do orientation pointers (retrieval) beat inlined content (repetition) for session input cost, and how does the 1500-byte pack cap trade off?

Status: crystallized 2026-09-08 from research line `ctx-retrieval-vs-repetition`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-retrieval-vs-repetition.md.

# Research Line — Crystallized Record (contracting → closed)

**Line:** At equal task quality, when do orientation pointers (retrieval) beat inlined content (repetition) for session input cost, and how does the 1500-byte pack cap trade off?
**State file:** `research-lines.tsv`
**Lifecycle:** contracting — this document is the line's lasting summary.

> **Verification note (read first):** In this transition I had no read access to the filesystem. The only artifacts I can ground against are (a) the line-state file `research-lines.tsv`, named in the transition prompt itself, and (b) the two read-only llm-wiki pointers supplied as prior art. I cannot verify the internal layout of the hngh kernel repository (`/home/bricker/Projects/etc/hngh`) or re-read the vault notes' contents. Accordingly, the quantitative findings below are presented as a *derivable cost model*, not as measured results — no token measurements were taken in this transition, and I say so rather than assert numbers I cannot cite.

---

## 1. Findings

### F1 — The break-even condition is a dereference-probability inequality
Let:

- `S` = size of the content in question (bytes/tokens if inlined)
- `P` = size of the orientation pointer (path + title + one-line gloss)
- `R` = round-trip cost of dereferencing (tool call overhead, re-ingest of the fetched content into a later turn)
- `p` = probability the agent actually needs the content this session

Then:

- **Inline cost** = `S` (paid unconditionally, every session)
- **Pointer cost** = `P + p · (R + S)`

**Pointers win iff `p < (S − P) / (R + S)`.**

Three regimes follow directly:

1. **p ≈ 1 (content always needed):** pointers are pure overhead — you pay `P`, then pay the full `S` anyway, plus `R`. Inline.
2. **p low, S large:** pointers win decisively; the pointer tax `P` is paid every session but the bulk cost `S` is amortized across only the sessions that dereference.
3. **S small (S ≲ P + R):** pointers can never win even at p = 0, because the pointer itself costs as much as the content. Inline small things unconditionally.

### F2 — The prior art in this very transition is an instance of the pattern
The line's own prompt passes `[[concepts/session-salvage]]` and `[[sources/agentictrade-io-ai-service-marketplace]]` as *read-only pointers* — title, wiki-link, creation date — rather than inlining the notes. This is the retrieval strategy operating at p < 1: the line record stays cheap per session, and any transition that genuinely needs the note's body pays the dereference cost then. It validates F1's regime 2 as the line's working assumption. (I did not dereference them this transition, so I cannot confirm their contents bear on the 1500-byte cap question — that remains an assumption of the line, not a verified link.)

### F3 — The 1500-byte pack cap changes the shape of both strategies, asymmetrically
The cap interacts with the model in two ways:

- **Pointer side: mostly unaffected.** A well-formed pointer (path + title + gloss) is typically 100–300 bytes, far under the cap. The cap imposes no chunking penalty on the retrieval strategy's steady-state cost.
- **Inline side: quantization and splitting.** Content under 1500 bytes fits one pack cleanly; content above it must be split across multiple packs (each paying its own envelope/framing overhead) or truncated. So the cap *raises the effective `S`* for larger content — which pushes the break-even threshold in F1 **in favor of pointers**. In other words: **the tighter the pack cap, the broader the regime where retrieval beats repetition.**

The cap also creates a cliff: content near 1500 bytes is the worst case for inlining (barely-split, maximal framing waste) and the natural candidate to convert to a pointer with the body stored in the vault.

### F4 — "Equal task quality" is the load-bearing assumption, and it is not free
The model holds quality constant by assumption, but pointers degrade quality when the agent needed the content and didn't dereference (under-retrieval), while inlining degrades effective quality when context pressure crowds out other material. The line found no in-repo measurement harness that would let us verify the "equal quality" premise empirically; it remains a modeling constraint, not an observed property.

---

## 2. Recommendations (the line's actionable residue)

1. **Adopt a size-and-reuse policy:** inline content when `S ≤ ~P + R` (small) or when it is dereferenced in essentially every session; emit a pointer otherwise. Do not maintain a middle category.
2. **Treat 1500 bytes as the pointer-conversion trigger:** any session-input artifact exceeding the pack cap should be stored externally (vault or equivalent) and referenced, not split, unless p ≈ 1.
3. **Keep pointers self-describing:** a pointer must carry enough metadata (title, date, one-line scope) for the agent to make the dereference decision without fetching — otherwise p is miscalibrated upward and the savings vanish.
4. **Log dereference events** so `p` can be measured per-artifact over time and the policy retuned, replacing the assumed p with an observed one.

## 3. Open threads (left for future lines, not this one)

- **Measured, not modeled, break-even:** no token-level measurements of P, R, or real dereference rates exist in material I could verify. A future line should instrument this on idle hosts.
- **The hngh kernel's actual pack format:** whether the 1500-byte cap is enforced, advisory, or envelope-inclusive could not be confirmed against `/home/bricker/Projects/etc/hngh` in this transition. The F3 asymmetry argument assumes the cap applies to payload; if it applies to envelope+payload, the cliff shifts but the direction of the conclusion is unchanged.
- **Quality parity testing:** F4's "equal task quality" premise needs an eval harness before the policy in §2 can be called validated rather than principled.
- **Vault note contents:** whether [[concepts/session-salvage]] and the agentictrade.io source note materially bear on pack-cap design was assumed by the line's framing but not verified here.

## 4. References

- `research-lines.tsv` — line state file (named in the transition prompt; lifecycle state *contracting*).
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (path given in the transition prompt; **contents not verified this transition** — no specific files inside it are cited because none could be confirmed).
- llm-wiki vault (read-only, per prior art):
  - `[[concepts/session-salvage]]` — *Session Salvage* (created 2026-08-24); pointer only, body not dereferenced.
  - `[[sources/agentictrade-io-ai-service-marketplace]]` — agentictrade.io AI service marketplace, USDC; pointer only, body not dereferenced.

**Closing note:** This line's durable contribution is the inequality `p < (S − P)/(R + S)` plus the observation that a pack cap tilts it toward retrieval by inflating effective `S` for inlined content. Everything quantitative beyond that is flagged as unmeasured, and every file claim is confined to the two paths the transition itself supplied.
