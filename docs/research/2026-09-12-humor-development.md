# Which deadpan craft-narration moves (Tatsumi A Drifting Life mode: the mundane played absolutely straight, wit from restraint) should the house voice adopt per lane (lib/quips.py quip lanes, generated-article closers), and what register-law boundary keeps the dryness from mocking the subject?

Status: crystallized 2026-09-12 from research line `humor-development`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-humor-development.md.

# Research line: deadpan craft-narration moves per lane + register-law boundary — contracting crystallization

**Line:** Which deadpan craft-narration moves (Tatsumi *A Drifting Life* mode: the mundane played absolutely straight, wit from restraint) should the house voice adopt per lane (`lib/quips.py` quip lanes, generated-article closers), and what register-law boundary keeps the dryness from mocking the subject?
**State:** expanding → contracting (crystallized record; line remains in motion on idle hosts)
**Date:** 2026-09-12

---

## Verification status

No live read of either tree was available in this transition. The only paths cited with confidence are those already attested in prior material: `lib/quips.py` (hngh-automation, quip lanes) and `meta/registry.json` (vault registry emitting the "Auto-generated… Do not edit manually" banner). The hngh kernel at `/home/bricker/Projects/etc/hngh` is asserted to exist by the line brief; no file inside it is confirmed. All claims touching a kernel path remain UNVERIFIED and are excluded from recommendations below.

---

## 1. Findings — the four adoptable moves

Distilled from *A Drifting Life*'s mode (the mundane played absolutely straight, wit from restraint) and tested against the two house-voice lanes:

| # | Move | Form |
|---|------|------|
| 1 | **Flat declarative inventory** | State the boring fact in full; no adjective does the joke's work. Comedy lives in the arithmetic, not the tone. |
| 2 | **Precision where vagueness is expected** | Exact number, exact flag, exact timestamp, delivered deadpan. Over-specification of trivia is the Tatsumi signature. |
| 3 | **No wink punctuation** | No "lol", no emoji, no "(sigh)", no trailing ellipsis soliciting sympathy. If a sentence needs a marker to be funny, it is not funny. |
| 4 | **The narrator absorbs the embarrassment** | The straight-man is always himself — his failed submissions, his rented room. The house voice may be dry *about the pipeline, the narrator, the automation*; the joke's target is inward. |

Moves 1 and 3 are structural (they govern sentence shape). Moves 2 and 4 are directional (they govern *what* is specified and *who* is the object of the dryness). The register-law boundary in §3 is the enforcement mechanism for move 4.

---

## 2. Recommendations per lane

### `lib/quips.py` — quip lanes

Quips are short and frequent; they are the highest-risk lane for sliding from dry into smug.

- **Subject bias.** Bias quip templates toward self-directed or process-directed subjects: the build, the queue, the retry count, the narrator's own bookkeeping. A quip whose grammatical object is a user, a contributor, an external project, or a piece of source material being processed is out-of-register and must not be templated.
- **Preferred move.** Prefer move 2 (over-precision) over move 1 (inventory). Quips are too short for inventory to land. *"0 tests added, 0 tests removed, 214 tests unbothered"* is in-register; anything requiring a second sentence is a closer wearing a quip's clothes.
- **Lexical guard.** Add a lint-style guard (a regex/template review checklist if no copy test harness exists) rejecting quips containing wink markers: emoji, "lol", "just", "simply", "obviously", "of course". These are the lexical tells that dryness has curdled into condescension.

### Generated-article closers

Closers have room for moves 1 and 3.

- **Close on flat factual residue, not a takeaway.** The Tatsumi ending is the camera staying on the room after the event: *"The draft was saved at 03:12. The queue is empty. The queue refills on Mondays."* No "and that's the lesson."
- **Ban moralizing closers** ("this shows that…", "ultimately,") in the closer lane specifically. An interpretive sentence may live mid-article; the last two sentences must be observable fact.
- **One restrained callback is permitted** — returning to a concrete detail named in the article's first third. This is the *Drifting Life* chapter-ending device and is the closest the house voice should come to warmth.

---

## 3. Register-law boundary (the contract)

> **The house voice may be dry only about the system itself — the pipeline, the automation, the narrator's bookkeeping. It may not be dry about any external subject: a user, a contributor, an external project, or a piece of source material being processed.**

This is move 4 stated as an enforceable rule. The wit comes from the system's own mundanity (the cron that renamed 41 files, three of which needed renaming; the queue that refills on Mondays). The moment the dryness turns outward — toward a person, a community, or material the system is processing — it becomes mockery, and the Tatsumi mode collapses into smugness.

**Test:** For any candidate quip or closer, identify the grammatical object of the sentence. If that object is not the pipeline, the automation, or the narrator's own record-keeping, the sentence is out-of-register regardless of how flat its tone is.

This boundary is complementary to, not identical with, move 3 (no wink punctuation). Move 3 polices *form*; the register-law polices *direction*. A sentence can be perfectly flat in form and still mock an external subject; a sentence can be directed inward and still fail if it reaches for a wink marker. Both must pass.

---

## 4. Open threads

1. **Guard implementation surface.** The prior material hedges: "a simple regex/template review checklist if no test harness exists for copy." Whether `lib/quips.py` (or an adjacent module) already carries a template-validation path, or whether the guard must be introduced as new infrastructure, is unresolved. No file in the quip-lane pipeline beyond `lib/quips.py` itself is confirmed.
2. **"Subject" boundary in closers.** The register-law names users, contributors, external projects, and source material as off-limits objects. Whether a closer that references *the article's own topic* (e.g., a library being documented) counts as "source material" or as "the system's work product" is not settled. The quip lane is clear; the closer lane has one more degree of freedom and may need a worked example set.
3. **Callback specificity.** The "one restrained callback" rule for closers names a concrete detail from the article's first third, but does not specify whether the callback must be *the same* detail or merely *a* detail from that region. If the article's first third contains multiple concrete details, the choice among them is currently unguided.
4. **Kernel-side voice surface.** The line brief asserts `/home/bricker/Projects/etc/hngh` as a repository in scope. No file inside it has been read or confirmed. If the kernel emits user-facing strings (error messages, status output, commit trailers), those are a potential third lane not yet assessed against the four moves or the register-law. This thread is UNVERIFIED and cannot be advanced without a live read.
5. **Tone-drift detection over time.** The lexical guard (§2, quip lanes) catches individual sentences. There is no stated mechanism for detecting *cumulative* smugness across a generated article — e.g., three flat closers in a row that individually pass but collectively read as condescending. Whether this is a real failure mode or an over-worry is untested.

---

## 5. References

- `lib/quips.py` — hngh-automation quip lanes (attested in prior material; path confidence: high)
- `meta/registry.json` — vault registry, source of the "Auto-generated… Do not edit manually" banner (attested in prior material; path confidence: high)
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (asserted by line brief; existence accepted, internal file structure UNVERIFIED)

No other file paths are cited. External sources (the *Drifting Life* manga itself, any published writing-craft literature on deadpan narration) were used as mode-reference only and are not verifiable in-repository; specific panel or chapter citations from the manga are not provided here because no in-repo source document was available to ground them.

---

*Line state: contracted. Record is durable; the line continues on idle hosts.*
