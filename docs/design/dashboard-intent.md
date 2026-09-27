# Dashboard Intent — machine-evaluable operator goals (2026-09-27)

Every operator goal for the broadsheet dashboard, restated as numbered
checkable intent statements. Each intent has a probe the hourly
metacyclic beat (`cadence/hour/42-dashboard-introspect.sh` →
`jobs/dashboard-introspect.py`) evaluates at file/JSON level — no
browser, no DOM. Probes are the DECIDERS; Jev (typesafe `ask_nouls`,
one batched call) only ORDERS arc filing when several gaps are pending
(operator doctrine: Jev advises, never certifies).

Severity: **major** = blocks an operator goal directly (file arc this
sweep; regression alerts immediately). **minor** = polish/quality
(file arc; defer allowed). Any met→unmet transition alerts via
report-queue identity `dashboard-regression:<slug>` regardless of
severity.

Probe targets: `automation/dashboard/newspaper.json` (the composed
feed), `broadsheet-view.js`, `broadsheet.css`, `broadsheet.html`
(the tracked surface). State: `automation/state/introspect-state.json`
(gitignored). Tuning: `cadence-params.tsv` `introspect-*` rows.

## Goal 1 — Masthead (the paper's face)

- INT-1 **masthead-splash** (major): the masthead renders a volumetric
  ASCII-art splash title (banner glyphs), not plain HTML text.
  Probe: `broadsheet-view.js` contains a splash renderer (`splash`
  AND `ascii` tokens).
- INT-2 **masthead-expansion** (major): `newspaper.json`
  `.edition.masthead.expansion` is four fully spelled words whose
  initials are H N G H.
  Probe: JSON — 4 words, each ≥3 letters, initials `hngh`.
- INT-3 **masthead-varies** (minor): the expansion differs across
  editions.
  Probe: JSON — `.editions[].masthead.expansion` distinct values ≥ 2.
- INT-4 **masthead-emboss** (minor): the masthead is ink-embossed.
  Probe: `broadsheet.css` — a `text-shadow` within the masthead rule
  block.
- INT-5 **masthead-temperature** (minor): the dateline shows
  temperature in BOTH °C and °F.
  Probe: JSON — `.edition.weather.temp_c` and `.temp_f` both present.

## Goal 2 — Printed-paper realism

- INT-6 **paper-texture** (major): textured paper background.
  Probe: `#paper-canvas` in the HTML AND `paperInit` renders into it.
- INT-7 **printed-frames** (minor): cards read as printed rules.
  Probe: `broadsheet.css` — a `border: ... double` rule.
- INT-8 **leaf-light-motion** (minor): dappled leaf-light moves across
  the page, smoothly.
  Probe: `dapple|leaf` renderer tokens in `broadsheet-view.js`
  (smoothness itself stays DOM-level, ui-evolve's jurisdiction).

## Goal 3 — Operator decisions visible and usable

- INT-9 **choice-previews** (major): every multi-choice action carries
  an outcome preview.
  Probe: JSON — every `choices[].outcome` on every article non-empty,
  and ≥1 article has choices.
- INT-10 **dismiss-immediate** (major): a dismissal reflects in the
  visible stream immediately.
  Probe: `broadsheet-view.js` — `dismiss` handler + in-place DOM
  mutation tokens (`removeChild|classList|.remove(|hidden`).
- INT-11 **no-dead-buttons** (major): every `<button id=...>` in the
  HTML is referenced in `broadsheet-view.js`.
  Probe: id-set difference is empty.
- INT-12 **family-card** (major): a flood of empty feedback ideas
  renders as at most ONE family card.
  Probe: JSON — `family: true` articles ≤ 1.

## Goal 4 — Content balance (voice over wire)

- INT-13 **voice-majority** (major): ≥ 60% of articles carry a voice
  category (`system, operator, research, hngh, resources`).
  Probe: JSON category share.
- INT-14 **wire-capped** (minor): wire-category share
  (`politics, world, business, sports, technology, military, space,
  entertainment, games`) stays ≤ `introspect-wire-max-share`
  (default 25).
  Probe: JSON category share.

## Goal 5 — No blank / flooded noise

- INT-15 **no-empty-feedback** (major): zero non-family articles with a
  headline starting `[feedback:idea]`.
  Probe: JSON headline + empty-body-block scan.

## Goal 6 — Performance, a11y, honesty

- INT-16 **single-webgl** (minor): at most one WebGL context creation
  in `broadsheet-view.js` (paper texture + megastructure map share it).
  Probe: `getContext('webgl…` + `WebGLRenderer` sites ≤ 1.
- INT-17 **reduced-motion** (major): `prefers-reduced-motion` honored
  somewhere on the surface.
  Probe: token in view or css.
- INT-18 **no-client-today** (major): the view never derives "today"
  from client Date.
  Probe: no `new Date(`/`toISOString(` in `broadsheet-view.js`.
- INT-19 **evidence-sources** (major): every wire-category article has
  non-empty `sources`.
  Probe: JSON scan.
- INT-20 **fail-closed-auth** (major): fetches attach the `hngh-token`
  and treat 401/403 as an error state.
  Probe: both tokens in `broadsheet-view.js`.
- INT-21 **feed-error-banner** (minor): a missing/unreachable feed
  shows `#papererr`, never a blank page or fake data.
  Probe: `papererr` in HTML AND view.
- INT-22 **scroll-60fps** (minor): the stream renders lazily via an
  IntersectionObserver sentinel so scroll stays cheap.
  Probe: `IntersectionObserver` in `broadsheet-view.js`.

## Loop mechanics (the metacycle)

Every hour (`42-dashboard-introspect`, no stamp gate — the hour tier
paces it):

1. Run all 22 probes (fail-open per probe; a probe error counts as
   unmet with the error as detail).
2. Grade = met/22. Written as a report-queue progress row, identity
   `dashboard-introspect:grade`, evidence `M/T` — re-fires only when
   the grade moves.
3. Unmet probes → research arcs `arc-<date>-dashboard-<slug>` in
   `research-subjects.txt` (deduped by id), chewed by the hourly
   `33-research-beat` like any other subject. `introspect-min-gap-hours`
   paces sweeps; regression-driven arcs bypass the window (fresh damage
   files now).
4. Met→unmet transitions → report-queue alert, identity
   `dashboard-regression:<slug>`, window 86400, evidence = hash of the
   fresh failing detail (the 10-router-feed consumes alerts).
5. Closure criterion: `introspect-retire-streak` (3) consecutive met
   grades close a probe's era (state json). While met, nothing files.
   A re-gap after retirement files a FRESH `-r<N>` arc id — the old,
   answered arc stays in the ledger and is not confused with the new
   question.
6. Jev (operator addendum 2026-09-27): when ≥ `introspect-jev-min-gaps`
   gaps are pending, ONE batched `ask_nouls` call (lib/typesafe.py,
   jev-1.13.0, shared state paid once, input-only priced) scores
   "file this gap's arc now?" per pending slug and reorders filing.
   Timeout-bounded (`introspect-jev-timeout`, 20s) in a child process;
   unreachable Jev or any failure = fail-open to probe order. Jev
   NEVER changes the met/unmet decision — deterministic probes own
   that.

Test: `automation/tests/test-dashboard-introspect.sh` (hermetic
fixture surface; proves all-met → no arcs, one-gap → one arc,
met→unmet → regression identity alert, era retirement → fresh `-r1`
id, pacing window → deferred filing).
