# Interpretation doctrine - how findings and offices are read

Status: DESIGN - 2026-09-24. Decision record: `docs/project/decisions.md`
(2026-09-24, foundation consolidation). Adjacent document:
[autonomous-development-control.md](autonomous-development-control.md)
governs admission; this document governs interpretation. The
interpretation clauses are part of the constitution (`GOVERNANCE.md`
preamble), amendable under its section 11.

## 1. Purpose

Interpretation exists so that findings mean something. Findings are
read through the canon and the pantheon at the named seams below. The
mechanical core is untouched: the closed principle matrix and the
certificate verdicts stay deterministic.

## 2. The interpretive register

The register is (a) the six annotated classics
(`~/Projects/etc/tao-confucian-canon/docs`; James Legge public-domain
base texts in `sources/`) and (b) the seventeen-voice pantheon
(`~/Projects/etc/tao-confucian-canon/voices/pantheon.md` /
`pantheon.json`). The corpus carries its own disclaimer, quoted
verbatim:

> **These are simulated voices.** Every entry below is an in-character pastiche — a character bible forged for a commentary engine, not the words or beliefs of the historical authors. The pantheon exists to argue about the Taoist and Confucian classics (James Legge's public-domain translations), each voice contributing supportive and adversarial entries; the pastiche disclaimer carried on every assembled document applies here. This file is the forge, not the artifact.

Pastiche commentary is evidence-like input, never endorsement of a
voice.

## 3. Named seams (the only places interpretation binds)

1. **Findings reading.** A supportive + adversarial dual pass - the
   pantheon's own method ("each voice contributing supportive and
   adversarial entries", `voices/pantheon.md`) - with convergent
   synthesis when readings agree (`commentary/<classic>/text-synth.json`
   style). Disagreement escalates; it never averages (mirroring the
   deterministic combiner's "Disagreement refuses or escalates",
   [autonomous-development-control.md](autonomous-development-control.md)
   reviewer contract).
2. **Office and role-contract vocabulary.** Rectification of names:
   where names are not correct, language is not in accordance with the
   truth of things (Analects) - the office is defined before the
   officer is judged (`GOVERNANCE.md` section 2).
3. **Structural mapping.** The table in section 4.

## 4. Structural mapping

| Federal branch | Repo component | Clean-arch layer | Canon concept | Pantheon commentary use |
|---|---|---|---|---|
| Judicial | constitution kernel (`src/`, ceremony) | domain (pure) | sincerity as correspondence (Doctrine of the Mean): "words answer to things, claims answer to evidence"; "It judges; it never initiates." | adversarial readings stress-test evidence claims |
| Legislative | bead chamber (issues/amendments) | application + ports | rectification of names (Analects) | supportive readings propose definitions; rival readings surface before adoption |
| Executive | cadence driver + domain kernels (`automation/`) | adapters + mechanism | "cooking small fish" (Tao Te Ching, ch. 60); minimal handling | commentary on execution economy; friction pairs mark where an action deserves a second reading |
| Checks | bailiff, guards, gates, review | test-boundary + fixtures | the mirror mind (Chuang Tzu: the mind "responds but does not retain") | the allies/friction graph supplies standing devil's-advocate pairings |
| Federalism | two homes + cert/free tiers | "no second core" (`docs/project/master-plan.md:49-50`) | the uncarved block (Chuang Tzu) | general mechanisms over special cases; voices that argue branding vs concrete abstraction feed the research line on that question |

## 5. What interpretation NEVER does

Interpretation never: admits or refuses a mutation; overrides a
deterministic refusal; creates authority; enters the evidence ledger
as proof (typed/challenge findings stay "CHALLENGE DATA, never proof").
Meaning is read; the evaluator decides.

## 6. Provenance

Every interpretive claim cites its source: a canon unit id or a voice
slug - the source-cited-findings rule applied to interpretation.

Flavor and lexicon documents mapped to the register (one line each;
recorded, not rewritten):

- [descent.md](descent.md) - the six-station loop is the Great
  Learning sequence run as a cycle: "investigate things, extend
  knowledge, make thoughts sincere, rectify the heart" and then
  "cultivate the person, regulate, govern" (`GOVERNANCE.md` section 7).
- [bestiary.md](bestiary.md) - rectification of names applied to
  failure: the cause class is named before the route is chosen ("Wrong
  class, wrong route", Analects via `GOVERNANCE.md` section 2).
- [display-register-spec.md](display-register-spec.md) - the pantheon's
  register discipline applied to display: one quiet register, flavor as
  perceptual decoration, never endorsement.
- [writing-register.md](writing-register.md) - the pantheon's voice
  bibles used directly as prose law (Orwell, Leonard, Adams anchors):
  the method binds, no voice does.
- [operator-mirror.md](operator-mirror.md) - sincerity as
  correspondence (Doctrine of the Mean): claims about operator intent
  answer to what the operator actually wrote ("words answer to things,
  claims answer to evidence", `GOVERNANCE.md` section 6.1).
- [../project/operating-precepts.md](../project/operating-precepts.md) -
  "watchers over gates" and cost-dictated cadence are "cooking small
  fish" (Tao Te Ching, ch. 60) as growth policy: the least handling
  that suffices (`GOVERNANCE.md` section 4).
