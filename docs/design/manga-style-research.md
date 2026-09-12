# Manga style research -- reading conventions as executable descriptors

Status: RESEARCH (style study, 2026-09-12). Subject: what the named
masters' conventions mean as EXECUTABLE descriptor language for the
multi-pass panel pipeline (jobs/manga-draft.py passes 1-4). Reading
conventions only -- composition grammar, tone usage, face economy,
narration register -- implemented as prompt/bank language in hngh's OWN
style (the STYLE_CORE string), never as artist names in prompts
(test-enforced: tests/test-manga-draft.py TestStyleCore) and never as
copied artwork. The no-artist-names-in-prompts contract stays; the study
is cited as research, never used as training data.

## Style core (the one string, verbatim)

Defined once in automation/jobs/manga-draft.py (STYLE_CORE), inherited
by every component prompt:

    monochrome ink illustration, bold confident ink linework, dense
    cross-hatching on shadow and towering dark structures, screentone
    shading, vast negative space, high contrast black and white, muted
    desaturated accents, moss and bone motifs, cathedral-scale brutalist
    machine architecture, clean white ground, no text in image

Evolve the style HERE (or in this doc + the string together), never by
editing component prompts in place. The manga-panel row in
config/imagegen-styles.tsv remains the legacy one-shot prompt; its
descriptors fold into this core.

## Study 1 -- composition grammar (Tatsumi / Nihei line)

Reading notes (study: gekiga short-story composition; architectural
megastructure framing). Executable descriptors:

- "single gag manga panel" + "cinematic panel composition with diagonal
  depth" -- every panel has ONE focal action; the eye hits it second,
  after the establishing element (script pass: per-beat "eye" field
  encodes the order).
- "vast negative space in the background for bubbles" -- Tatsumi's
  economies: nothing competes with the word balloon; the environment
  plate leaves the bubble corners clean (component prompt carries
  "empty of figures" + "vast negative space").
- "cathedral-scale brutalist machine architecture, towering dark
  structures" -- the Nihei proportion law (display-register-spec s3):
  gaunt figures, tiny heads, huge volumes; scale contrast IS the drama.
  In the wireframe: the environment plate fills the frame, actor pieces
  stay thumbnail-readable (512x768 actor, 768x512 environment).
- "dynamic speed lines" only on the reaction beat, never the setup --
  motion is information (register law); stillness is the default.

## Study 2 -- tone usage (screentone language)

Reading notes (study: screentone shading conventions). Executable:

- Screentone = mid-gray without color. One dot pattern for sky/ambiance
  (skeleton "screentone" pattern), one dark for shadow masses
  ("screentone-dark"), one 45-degree hatch for mid-tones on structures.
- Density = emotional register: flat white for deadpan setup, dense
  cross-hatch ("dense cross-hatching on shadow") when the structure
  groans, dark tone pooling under the focal action.
- A single accent (the red seal) per panel -- "high contrast monochrome
  ink with a single accent color". Two accents read as color work; keep
  one.

## Study 3 -- face economy (Tezuka / Tatsumi line)

Reading notes (study: expressive-face conventions at thumbnail scale).
Executable:

- "expressive character faces with round expressive eyes and star
  highlights" -- the round eye + star highlight travels as a DESCRIPTOR
  (the highlight is a generic manga convention, not a signature).
- Gaunt silhouette first, face second: "small heads, gaunt coats,
  readable at thumbnail size". The character sheets
  (config/manga-cast.json) pin the silhouette per cameo; the face lives
  inside it.
- Reaction beats earn the exaggerated face; setup beats keep the
  deadpan mask (pose library: "standing-deadpan" vs "reacting").

## Study 4 -- narration register (the comedy dimension)

Reading notes (study: gekiga autobiography narration mode -- the dry
first-person account of a working cartoonist's life: deadpan
persistence, the dignity of daily craft, self-deprecation about the gap
between ambition and the daily grind). Executable, folded into the
banks (manga-draft.py NARRATIONS, the setup beat):

- Flat declarative narration of small dramas, played absolutely
  straight: "Another shift began. The building did not care." The joke
  is never announced; the FACT carries it.
- The bureaucratic-heroic register the Saga dispatch already uses,
  carried into panel dialogue: procedural language ("filed under",
  "the log says") applied to oversized events.
- Humor from CARE: knowing the subject deeply enough to play it
  straight. Never a wink, never "get it?"; the machine files its own
  catastrophe under the correct form number and moves on.
- Escalation is bureaucratic, not explosive: the panel's gag beat lands
  on a rule, a form, a log entry -- not a punchline shape.

House study queued: research-subjects.txt
`fail-20260912-serious-manga-narration-register` -- what A Drifting
Life-class works teach about deadpan narration and craft-persistence
humor, distilled into hngh's comedy banks.

## Provenance and limits

- Study sources: published manga histories, interview collections, and
  the works themselves, read as conventions (composition, tone, face,
  narration). No artwork scraped, no images copied, no style models
  trained. Attribution lives in this section; prompts carry pure
  descriptor language.
- The descriptors are hngh's own phrasing, aimed at the shared
  aesthetic denominator (design s3 "style-approximation framing",
  docs/research/2026-09-11-imagegen-integration.md). If a descriptor
  ever needs an artist's name to work, it is the wrong descriptor --
  replace it with the visual property it was reaching for.
