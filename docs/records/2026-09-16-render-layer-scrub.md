# 2026-09-16 — render-layer scrub: the egress renderers fail-close host paths

## The question

Deep-task node `llc-gate-render-layer-scrub` (from the
`cred-llm-render-chain-leak::gate` critique, sibling of the writer
census `2026-09-16-digest-writer-census-scrub.md`). The writer census
scrubbed the four known digest writers, but gate-verified that every
DOWNSTREAM renderer still consumed `archive/digest/<date>.md` verbatim:

- `jobs/digest-html.py render_deck_b` rendered mega items via
  `_linkify` and beat side-note excerpts unscrubbed;
- `scripts/html-digest.py render_mega` (zero scrub hits in the file)
  embedded deck B verbatim into the operator email HTML part;
- `dashboard-server.py /digest-html/` served `render_page` output
  verbatim on the LAN-reachable :8890 bind;
- `jobs/digest-public.py render_page` emitted the raw mega lines into
  the pushable public edition.

The writer census itself proved the residual risk: `patrol.py
morning_report` appends `## The rounds` + top-3 FAIL details straight
into the daily digest, and the writer layer can never cover a future
direct writer. Live proof in `automation/STATE.md`
(2026-09-16T22:00:31Z crumb: `credential credential-freshness:
hash-mismatch: unsloth-session (evidence
~/.hngh-automation/unsloth.token)`) — pathy alert text exists below
the ledger layer today; only credential-health's emitter redaction
kept that particular crumb tilde-form.

## Chokepoint decision: parse-time seam in the readers

The census record argued writer-side scrubbing (M writers beat N
readers). This slice closes the complementary half: the readers that
are egress surfaces must not trust digest content either, because the
digest file is a multi-writer append log and no writer set is provably
complete. The seam is parse/load time, not per-renderer call sites:

- `jobs/digest-html.parse_sections` scrubs every parsed item line
  through `scrub_paths` BEFORE it becomes a section item. All three
  decks (deck A rows, deck B mega items, the rounds outcome table)
  flow from those items, so one chokepoint covers the newspaper page,
  the `/digest-html/` route payload, and — because
  `digest-public.render_page` parses through the same
  `dh.parse_sections` — the public edition.
- `jobs/digest-html.beat_sidenotes` scrubs the sidecar text before
  the 3-sentence excerpt is cut (RESEARCH-BEAT files are model
  output, equally below-ledger).
- `scripts/html-digest.news_sections` scrubs item lines (the email's
  own parse) and `render_mega` scrubs each mega line (its own parse).

Dashboard-server needed NO change: the route serves
`digest_html.render_page`, whose parse seam already covers it —
verified by the route-level e2e test over a real bound server.

Both renderers re-export `digest-ledger.scrub_paths` via
SourceFileLoader (same posture as `gdelt-news.py`): NO fourth regex.
Fail-open to identity only if the module cannot load — the renderers
stay alive if the ledger module moves, which is the documented
posture of the gdelt precedent (the census keeps the writer-side
guards as the primary layer; render-side is fail-close in every
working configuration).

## Marker decision (deliverable 3)

The fixed marker is `[redacted path]` — the existing identity seam
(digest-ledger PATH_TOKEN_RE, model.sh `_scrub_paths`,
digest-block.sh, news-articles.py). The tilde-form alternative was
rejected: `~/.hngh/...` style masking preserves a readable host
layout and this tree already standardized on the marker in four
call sites; marker unification across ALL scrub sites (including
token families like `/Users/`, `/root/`) remains
`llc-gate-scrub-site-divergence`'s scope.

Scope note (visible in the e2e assertions): the renderers' own
machine-written chrome literals — masthead pointers like
`~/.hngh/archive/digest/<date>.md`, ledger plate labels
`~/.hngh/db/telemetry.db`, the public edition's reading-room footer —
are constants of the renderer code, not digest content, and are out
of the seam's scope (scrubbing render templates would break the
newspaper's self-description). The law the tests pin: zero
`/home/`, `/tmp/`, `~/` tokens in any rendered DIGEST CONTENT
(content region from the Deck A plate onward), marker stands in,
URL-shaped tokens survive verbatim (the seam consumes URLs first).

## What landed

- `automation/jobs/digest-html.py` — `_load_scrub`/
  `scrub_paths` (re-export); `parse_sections` scrubs item lines;
  `beat_sidenotes` scrubs sidecar text before excerpting.
- `automation/scripts/html-digest.py` — same re-export;
  `news_sections` scrubs item lines; `render_mega` scrubs each
  mega line before the PLAN_ROW/linkify branch.
- `automation/tests/test-digest-html.py` — new
  `RenderLayerScrubTest` (5 cases, below).

## Tests (red first)

`RenderLayerScrubTest` in `automation/tests/test-digest-html.py`:
a pathy append (credential crumb with a `/home/.../.token` evidence
path, morning-rounds line with `/tmp/...` and `~/...`, a URL that
must survive) is injected into the fixture digest BELOW the
digest-ledger builder — the exact shape a patrol.py append or any
future direct writer produces. Five assertions, one per egress
surface + boundary:

- `test_render_page_scrubs` — the newspaper page
- `test_digest_html_route_scrubs` — the real HTTP payload from a
  bound ThreadingHTTPServer (the LAN-reachable surface)
- `test_email_html_scrubs` — the operator email HTML part (fully
  hermetic: every email-digest lane seamed via env; the fixture
  stages `<AUTOMATION>/jobs/digest-ledger.py` because the email
  renderer loads the seam from its deployment root)
- `test_public_edition_scrubs` — the public edition
- `test_render_page_scrubs_sidecar_excerpt` — RESEARCH-BEAT sidecar
  excerpt path (model-written sidecar, not the daily digest)

Red: all 5 failed on the leak assertions against the unscrubbed
renderers (full `make test` at the red commit: ONLY these 5 failed,
no collateral). Green after the parse-time seams landed.

## Validation

- `python3 -B tests/test-digest-html.py` 18/18 OK (13 prior + 5 new)
- `python3 -B tests/test-digest-append-scrub.py` 4/4 OK
- `python3 -B tests/test-digest-local.py` 2/2 OK
- `python3 -B tests/test-gdelt-news.py` 10/10 OK
- `python3 -B tests/test-email-qa.py` 13/13 OK
- `python3 -B tests/test-newspaper-window.py` 6/6 OK
- full `make test` (automation gate): ALL PASS

## What this does not cover

- `/Users/`, `/root/`, `//host/` path families stay outside the
  seam's token family (same divergence node as the census record:
  `llc-gate-scrub-site-divergence`).
- Render chrome literals (`~/.hngh/...` masthead/reading-room
  pointers) are deliberate constants, not scrubbed.
- The kernel `scripts/` tree and its report surfaces are outside
  this automation slice.
- `/digest/<name>.md` raw-md jail route still serves the unscrubbed
  raw file by design (operator-facing raw evidence behind the same
  jail as before; deck surfaces are the leak class this node owned).
