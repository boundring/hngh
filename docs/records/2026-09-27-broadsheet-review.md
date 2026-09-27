# Broadsheet front page — supportive and adversarial review

- Date: 2026-09-27
- Scope: WebGL broadsheet front page (`automation/dashboard/broadsheet.html` + `broadsheet-view.js` + `broadsheet.css`), its feed pipeline (`newspaper-compose.py`, `news-ingest.py`, `weather-ingest.py`, `this-day-ingest.py`, `jobs/operator-items-feed.py`) and server surface (`dashboard-server.py`).
- Evidence basis: file reads and line pins against the **working tree** as of 2026-09-27 ~13:00 UTC, plus live probes against the running dashboard (http://127.0.0.1:8890) in Chromium, plus disk reads of live state under `automation/dashboard/`.
- Drift warning: the broadsheet front end is **mid-flight**: `broadsheet-view.js` (+113/-3), `broadsheet.css`, `broadsheet.html`, `index.html`, `newspaper-compose.py`, and several tests are modified-but-uncommitted in the working tree, and the live server serves this working tree directly. Line numbers below refer to that working tree, not HEAD. See F15.
- Method: deterministic evidence only (file:line, live observation, live simulation). Where noted, a Typesafe (Jev) judgment cross-checked a conclusion; Jev advises, evidence decides. Jev cross-checks used `ask_nouls` (severity calibration), `ask_choices` (flood-fix rivalry), `triage_fanout` (execution order — returned a malformed partial order and was discarded).

## Executive summary

The broadsheet is in unusually good shape for its age: fail-closed defaults everywhere (schema gate, endpoint whitelist, token handling, WebGL/map fallbacks), a genuinely novel flood-collapse UX landing in the working tree, and a test file with 30 named cases that already covers the flood family's failure modes. The full suite is green (`make -C automation test` rc=0, 217.8 s).

The operator's four complaints decompose into: (1) masthead identity — partially delivered now (°C/°F conversion works live) but the volumetric ASCII splash and procedural H.N.G.H. expansion are not implemented; (2) paper feel — largely delivered by the uncommitted WebGL2 paper shader; (3) the empty-idea flood — root-caused end to end (test-suite leak → operator-feed cap capture → composer card amplification), with a strong client-side fix sitting uncommitted and a server-side residue that still needs a purge; (4) content mix — 58 % wire news, and 100 % of the hngh-internal non-wire content is stub-class (research-route stubs, session stubs, flood residue); there is zero real editorial hngh content.

The biggest non-obvious risks are not bugs but **drift**: live behavior is served from uncommitted source (a checkout/stash would silently change production), and the news db has no pruning while the composer reads all of it on every compose.

Findings: 3 major, 5 minor, 7 notes. No blockers.

## Findings

| ID | Severity | Where | Evidence | Suggested fix |
|----|----------|-------|----------|---------------|
| F1 | major | `jobs/operator-items-feed.py:44` (CAP=40), `:200-201` (ranking puts `[feedback:` first); live state | All 40 operator-items slots are the empty `[feedback:idea] from email` test residue (40/40 status=open, live-verified 13:0x UTC); cap means zero real operator items can surface until these are purged | One-shot purge (dismiss all 40 via the existing `/operator-item/dismiss` endpoint or a script over the ledger) + ingest guard: drop feedback rows with empty/placeholder payload. Jev `ask_choices` agrees "purge-script" at 0.86 |
| F2 | major | `automation/scripts/news-ingest.py` (no DELETE anywhere), `newspaper-compose.py:158-185` (SELECTs all rows per compose) | Live feed: 429 articles in today's edition + 7 past editions (~100 each) — 530-entry render sequence; db grows without bound and every compose pays full-scan cost | Retention window or hard cap in the db (e.g. keep 14 days), enforced in news-ingest or a cadence step |
| F3 | major | `broadsheet-view.js:913` (`if (!$('stream').childNodes.length) rebuildStream()`), `:916-926` (`refresh()`) | Live probe: after clicking refresh, `stream.firstChild` node identity unchanged — only the masthead re-renders; poll ticks (30 s) behave the same. The sheet can silently trail the composer by 30+ minutes | Re-render on new `generated` stamp with scroll preservation, or at minimum surface a "new edition — reload" flag. Jev `ask_nouls`: 0.65 that major is correctly rated |
| F4 | minor | `broadsheet-view.js:666` bare `rebuildStream()` vs comment `:655-659` ("the feed reloads after success (scroll position preserved)"), `rebuildStream(keepScroll)` at `:881-889` | Code path: bare call → `y = keepScroll ? scrollY : 0` → `scrollTo(0, ...)` jumps to top after every operator decision, contradicting the comment | Pass the truth through: `rebuildStream(true)` — or fix the comment. Jev: 0.31 (Jev would rate it lower than minor; kept minor because the comment actively misleads) |
| F5 | minor | `broadsheet-view.js:502` (`FLOOD_MAX_DISMISS = 80`), `:534` (`pending = a.floodIds.slice(0, FLOOD_MAX_DISMISS)`), `:557` (`'Dismiss all ' + nLabel`) | The label uses the full family length but the batch only ever dismisses the first 80; with N>80 the button would dismiss fewer than labeled (currently N=40, so latent) | Label the batch honestly ("Dismiss 80 of N") or loop batches until empty. Jev: 0.35 |
| F6 | minor | `broadsheet.css` (no `prefers-reduced-motion` block; whole file reviewed) | The paper shader animates continuously (dapple drift) and the map auto-rotates; `style.css:446` already established the reduced-motion pattern for its own ticker | Add a `prefers-reduced-motion` block that stills the dapple uniform and map rotation (the JS already polls `document.hidden` at `:228`, `:377` — the seam exists). Jev: 0.37 |
| F7 | minor | `index.html:10` vs `broadsheet.html:10` | The two 48-line shells differ by exactly one comment line ("absent it, mutations fail closed." vs "at cutover; standalone, mutations fail closed.") — the token-meta contract is documented inconsistently in twin files | Converge the shells (one generated from the other) or make the comments identical |
| F8 | minor | `dashboard-server.py:1012-1036` (`_dismiss`), `:1038-1062` (`_handle`) | Read-modify-write of `operator-dismissed.json` / `operator-approved.json` with no file lock; two concurrent POSTs can lose one dismissal | `fcntl.flock` around the ledger update. Jev: 0.26 (kept: it is a real lost-update window even if single-operator likelihood is low) |
| F9 | minor | `broadsheet-view.js:757-767` (`trimAbove`) | Counts rendered articles via `querySelectorAll` on every append — O(n) per append at CAP=400, on every scroll-driven fill | Keep a running counter on `feed`; decrement on trim |
| F10 | note | `broadsheet-view.js:874` (`mastheadRender`), `index.html` h1 (`clamp(44px,8vw,96px)`, plain Averia) | Axis-1 vision (volumetric ASCII splash, procedurally varying H.N.G.H. expansion, ink emboss) not implemented; the composer already has deterministic stamp-based picking (`test-broadsheet-view.py:231` `test_pick_deterministic_off_feed_stamp`) to build the per-edition expansion on | Precomputed figlet-style splash in a `<pre>`, expansion chosen from the feed stamp, CSS text-emboss |
| F11 | note | `broadsheet-view.js:974` (`if (document.hidden) return;` without rescheduling) | Poll chain pauses while hidden; `visibilitychange` (`:980-982`) revives it on return. Works as designed; noting so it is not re-flagged | None needed |
| F12 | note | `broadsheet.css:32` (`--c-hngh-activity`) | The CSS var exists but no `hngh-activity` category is ever emitted by the composer | Either add the category in the composer or drop the var |
| F13 | note | `broadsheet-view.js:598-604` (`floodDismissOne` splices `feed.data.articles` and `a.floodIds`) vs static `feed.seq` | After an in-place flood dismissal, the stale seq still holds the old flood-card renderable; only after a full 530-slot wrap would it re-render as "(0 items)" with a "Dismiss all 0" button. Any `rebuildStream()` or reload clears it | At `floodSettled`, drop the card from `feed.seq` too, or accept the edge |
| F14 | note | `newspaper-compose.py:353-354` | The `queues` dict mixes queue-status counts and per-category article counts, so the card qchip "QUEUE 40" shows an article count while the masthead "queue 71" shows the real queue depth — same word, two meanings | Rename the card count field or label it "items" |
| F15 | note | `git status` (working tree) | Live-served front end is uncommitted: `broadsheet-view.js` +113/-3, `broadsheet.css`, `broadsheet.html`, `index.html`, `newspaper-compose.py`, tests modified; `system-ingest.py`, `dashboard-introspect.py` untracked. The live page's behavior (flood card, batch dismiss, °F) does not exist at HEAD | Land the work in small commits; the suite is green |
| F16 | note | Live observation (relay Chromium screenshot) | A red "not loaded over HTTPS" banner appears at the viewport bottom; it is injected by the relay/proxy layer, not by the app (no such element in `broadsheet.html`) | None (environment artifact) |

## Operator axis 1 — Masthead identity (textfile splash, procedural expansion, °C+°F)

**Current state.** The masthead is a plain Averia h1 (`clamp(44px,8vw,96px)`), with a static "H.N.G.H." plaque image and the edition line beneath. The °C/°F requirement is **now met**: `broadsheet-view.js:869-871` converts client-side (`(c * 9 / 5 + 32).toFixed(1)`) and `:696` renders `w.temp_c.toFixed(1) + '°C / ' + cToF(...)`; live-verified on the running page ("weather: 14.3°C / 57.7°F overcast") and in the synthetic fixture ("14.2°C / 57.6°F"); covered by `test_runtime_conversion_exact` (`test-broadsheet-view.py:250`) and `test_missing_weather_hides` (`:261`).

**Gap.** The volumetric ASCII-art splash, the procedurally varying spelled-out H.N.G.H. expansion, and ink-emboss treatment are not implemented (F10). The composer already has the deterministic-seed machinery (`test_pick_deterministic_off_feed_stamp`) to vary the expansion per edition without flicker between renders.

**Options.** (a) `<pre>` splash with a fixed figlet-style font, expansion text chosen off the feed stamp — cheap, fully offline, matches the textfile aesthetic; (b) canvas-emboss for volumetric effect — prettier, but a second rendering surface to keep accessible; (c) CSS-only emboss on the existing h1 — cheapest, weakest match to the ask. Recommend (a) + CSS emboss.

## Operator axis 2 — Whole-page paper feel (ink, emboss, dappled leaf-light)

**Current state.** Largely delivered by the uncommitted working tree: a WebGL2 paper shader (`broadsheet-view.js:92-234`) lays down paper tone + two dapple layers (drift amplitude ≤0.055, ~50 s loop) behind a transparent `.sheet`; there is context-loss handling and an honest fallback (`:206-211` adds `body.paper-fallback` + CSS newsprint). Live-verified: canvas present, no console errors, no fallback triggered. The ink/paper contrast pair (`#26221c` on `#f4f0e6`) is comfortable at body 14.5 px.

**Gaps.** No `prefers-reduced-motion` seam for the continuous dapple (F6); dapple darkening under text is subtle but real (≤12% locally) — fine for contrast, worth a look on low-quality panels. The map panel ("THE MEGASTRUCTURE") shares the paper world convincingly; its fallback (`:382-405`) is an honest styled list, live-verified hidden when WebGL map initializes.

## Operator axis 3 — The empty-idea flood (root cause, exact path)

**Verdict.** The flood is a three-stage pipeline failure, not a UI bug. Exact chain:

1. **Leak (historic).** `test-dashboard-p1.py` wrote the literal string `[feedback:idea] from email` through an unseamed FEEDBACK dir into the live `operator-items.json`, once per `make-test` run since 2026-09-11. Leak fixed 2026-09-27 (per the flood card's own body text at `broadsheet-view.js:511-518`).
2. **Residue persists (live, verified).** The 40 rows sit in `automation/dashboard/operator-items.json` with `status: "open"` — all ids distinct (`sha8` of text + `[w=crumbs.py@NNN]` suffix, `jobs/operator-items-feed.py:51-52`), so the resolution scan (`:175-183`, needs token overlap + resolved/fixed/closed in a later crumb) never matches them, and nothing prunes them.
3. **Cap capture.** `jobs/operator-items-feed.py:44` caps output at 40 and `:200-201` ranks `[feedback:` items **first** — the residue fills 40/40 slots and structurally excludes real operator items (F1).
4. **Composer amplification.** `newspaper-compose.py:203-231` emits one score-0.95 decision card per open item → 40 identical cards dominate today's sheet (live: 40/429 articles are this residue).
5. **UI response (working tree, uncommitted).** `FLOOD_NEEDLE`/`isFlood` (`:501-505`) collapse the family into one card at the top-score slot (`buildSeq`, `:720-742`); `floodChoicesEl` (`:529-570`) offers batch dismiss ("Dismiss all 40") or keep; `floodDismissOne` (`:598-604`) splices each id from feed data + persists to localStorage (`:423-431`); `floodSettled` (`:615-636`) replaces the card with a "flood cleared" note on full success and retries only failed ids otherwise; `loadFeed` filters dismissed ids on every fetch (`:908-911`).

**Why the operator saw "nothing visibly change."** The committed UI has no flood handling at all — forty separate decision cards. The collapse + batch-dismiss exists only in the uncommitted working tree (F15), which the live server *does* serve, so a page reload picks it up. Live simulation of the dismiss chain (40 intercepted POSTs, server untouched): the chain itself completes in ~12 ms against instant responses — the progress line ("dismissed k of 40…") is unreadably brief in that artificial case; against the real server each first-time dismissal runs a report-queue subprocess (~0.1–0.3 s each), so a real click shows readable progress for seconds and then the card is replaced by the cleared note. Disk verified untouched after the simulated run (ledger count unchanged, newspaper.json still carries the 40) — the client-side truth model works without lying to the server.

**What is still missing.** The server-side residue: until the 40 rows are dismissed or purged, the operator items lane has zero capacity for real items, and every composer edition reprints the family (the client hides it only for browsers that dismissed it). Recommended: one-shot purge + an ingest-side guard against empty-payload feedback rows (Jev `ask_choices` "purge-script" 0.86). F5 (label over 80) and F13 (stale-seq wrap edge) are the two small caveats on the new UI path.

## Operator axis 4 — Content mix (wire vs hngh-internal)

**Quantified from the live feed** (`automation/dashboard/newspaper.json`, generated 2026-09-27T13:02:01Z, 429 articles in today's edition):

- External wire: 248 (58%) — sports 66, technology 36, linux 28, world 27, business 20, politics 18, games 18, military 12, space 10, open-source 10, robotics 2, science 1.
- hngh-internal: 181 (42%) — but **100 % stub-class**: opportunities 100 (research-route backlog stubs), system 41 (session stubs), operator 40 (100 % flood residue).
- Real editorial hngh content (alerts, kernel/queue events, fleet notes, decisions with payload): **zero** rows; the only live system signal is the masthead line ("queue 71 - sessions 41 - fleet 0/2 online").
- Past editions: 7 dates (2026-09-18…09-24), ~100 articles each, all in the render sequence (530 slots before the wrap divider).

**Assessment.** The wire-vs-internal ratio is not the problem — 42% internal is a healthy *count*. The problem is that none of the internal content carries information: the composer's stub generators (`session_articles` `:234-248`, `research_articles` `:251-266`) emit boilerplate bodies at fixed scores, and the operator lane is captured by residue (F1). Fixing the mix means feeding real system content (the untracked `system-ingest.py` + `dashboard-introspect.py` in the working tree look aimed exactly at this), not rebalancing weights.

## What is already good (keep-list)

- **Fail-closed feed gate**: `feedOk` (`broadsheet-view.js:891-897`) refuses to print a blank page on malformed feed; live banner path verified in code.
- **Security posture**: endpoint whitelist (`:411`) re-checked per render (`:640`); token from server-injected meta, `hmac.compare_digest`, 403 when unreadable (`dashboard-server.py:675-677, 768-787`); `Cache-Control: no-store` on all responses (`:1205-1211`); loopback+CGNAT-tailnet allowlist default-deny (`:463-507`); id regex validation (`:170`); no CDN anywhere (vendored three.js r160, Averia woff2 — `test_no_cdn_links`).
- **Escaping discipline**: `esc()` (`:33-38`) on every interpolated HTML; deck/body via `textContent`; URLs never rendered.
- **Honest fallbacks**: WebGL2 paper fallback (`:206-211`), map fallback list (`:382-405`), `papererr` banner (`:90` region, test `test_fail_closed_banner`).
- **Client-side dismissal truth**: localStorage filter reconciled against the composer's next edition (`:418-431, 908-911`), private-mode fail-open.
- **Batch dismiss ergonomics**: per-id continue-on-failure, failed-ids-only retry with relabeled button (`:615-636`; tests `test_single_failure_never_fails_batch`, `test_progress_stays_visible_no_rebuild_flash`).
- **Perf hygiene**: ~30 fps shader cap + `document.hidden` pauses (`:228, 377`), one-build map flag (`:280` region), wheel throttle, DOM cap 400 with visible trim note (`:744`), bounded fill (12/call, IntersectionObserver + scroll dual driver, `rootMargin: 900px`).
- **Ingest hygiene**: per-feed try/except isolation, conditional GET (etag/last-modified), `INSERT OR REPLACE` dedup by `sha8(link|title)` in news-ingest; composer atomic tmp+replace output; weather gate keeps the edition printable when weather is missing (`newspaper-compose.py:357-361`).
- **Tests**: 30 named cases in `test-broadsheet-view.py` including the flood family's failure modes; full suite green (rc=0, 217.8 s, this date).

## Risk register

- **Performance**: shader at ~30 fps is fine, but the dapple + map + multicol reflow stack is unmeasured on weak GPUs; fallback exists. trimAbove O(n²)-ish growth during long scrolls (F9). Composer full-scan grows with the db (F2) — today ~0.5 MB feed, cost still trivial; the trend is the risk.
- **Memory**: `feed.data` holds ~470 KB JSON + 530-slot seq per tab; DOM capped at 400 articles; localStorage dismissed set grows without pruning (minor). news.db unbounded (F2) is disk + compose latency, not tab memory.
- **Security**: surface is loopback/tailnet with token + whitelist + no-store; residual items: the ledger race (F8); token readable by any page JS is acceptable *because* no third-party JS is vendored — keep that invariant; HTTP-only serving is mitigated by tailnet transport [INFERENCE on threat model].
- **Drift**: live behavior served from uncommitted source (F15) — the sharpest risk in this review; twin shells with divergent contract comments (F7); comment/code drift on scroll preservation (F4); dead `--c-hngh-activity` var (F12); fixture/live schema divergence (fixture carries weather both-unit fields and slot variants the live path must tolerate — verified tolerant).

## Recommended execution order

1. **Land the in-flight broadsheet work** (F15) in small commits — view+css+html+tests; suite already green. Until this lands, every other fix is targeting a moving tree.
2. **Purge the flood residue + ingest guard** (F1) — one-shot dismiss of the 40 rows, then drop empty-payload feedback rows at ingest so the class cannot recur.
3. **Refresh re-render** (F3) — new-edition detection with scroll preservation.
4. **news.db pruning** (F2) — retention cap in the ingest/cadence lane.
5. **Small-fix batch** (F4, F5, F6, F7, F8, F9) — mechanical, one commit each where sensible.
6. **Masthead axis-1 work** (F10) — splash + procedural expansion + emboss; design-heavy, schedule last.

*Addendum 2026-09-27 (post-metacycle reconciliation):* F3's fetch-staleness half is fixed by c0d6d961 (unique ?t= cache-bust per fetch, disabled+'refreshing…' button state), but the render half remains open — `loadFeed` still rebuilds only when the stream is empty (`broadsheet-view.js:938`), so refresh updates the masthead but never re-renders articles; feed-age staleness is probed by C's INT edition-fresh, the DOM-level render check is deferred to the ui-evolve machinery per docs/design/dashboard-intent.md.
