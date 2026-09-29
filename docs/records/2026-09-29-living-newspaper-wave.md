# Living-newspaper wave: motion, desks, one-click Fire

Date: 2026-09-29. Surfaces: broadsheet view (`automation/dashboard/
broadsheet-view.js`, `broadsheet.css`, `broadsheet.html`), composer
(`automation/scripts/newspaper-compose.py`), dashboard server
(`automation/dashboard-server.py`).

## Problem

The broadsheet rendered decision cards as static text: no placement
narrative, no way to act on a recommendation in one step, no live
machine readout (system desk sprawled as several low-signal articles),
no digest of parked items (they vanish with the settled-decisions
digest only after a handoff exists), and no path from an article to a
spawned omp session.

## Change

- Composer: one-click Fire attaches a pre-filled note only where a
  guidance example exists (`OP_GUIDANCE_EXAMPLES[(class, verb)]`) —
  Park can never fire blank, matching the server's 400 on an empty
  park note. Cards carry `narrative.place` from `OP_PLACES`
  (alarm/decision/pulse desk, shelf, debt shelf) with the line from
  `OP_NARRATIVE_WHY`. `system_articles()` collapses to one
  "System desk: live machine readout" card embedding
  `{kind: btop, src: /system/btop}`. `parked_article()` reads
  `scripts/report-queue --json` (repo-root cwd, `\bpark` filter,
  newest-first, cap 8) into a parked-desk digest wired after
  `settled_article()`; fail-open on spawn errors.
- View: settlement actions animate (`megaTilt` + `ripBurst`; park
  flies the card to the parked shelf via `parkFly` with a deferred
  feed rebuild at 520 ms). `settleReceipt` accepts an override text;
  `postJson` attaches error bodies so server 4xx/5xx reach receipts.
  `embedSync` re-arms every 2 s as a chained timer with a detachment
  guard. The omp-session button POSTs `/article/omp-session` and the
  receipt echoes the returned path/package/command or the 503's run
  command. Parked shelf (`#parked-shelf`) and the folded-paper
  megastructure (`#megastructure`) render from the feed; motion CSS
  is killed under `prefers-reduced-motion`; articles rise with an
  id-hash stagger.
- Server: `GET /system/btop` drives an idempotent detached tmux
  session (`hngh-btop`, `btop -lt`) and returns `capture-pane -p`
  output capped at 64 KiB (502 on capture failure).
  `POST /article/omp-session` validates the session id
  (`^[A-Za-z0-9._-]{1,80}$`), writes the context package under the
  hngh home dispatch dir before any spawn check, and launches the
  terminal via `systemd-run --user --on-active=2`
  (`HNGH_TERMINAL` | foot | kitty); 201 or a visible 503.

## Verification

- `automation/tests/test-newspaper-compose.py`: 36 tests OK —
  includes fire-note default from guidance examples
  (`test_fire_default_verb_note_effect`), fire absent when no example
  (`test_fire_absent_without_example_verb`), narrative places,
  single system-desk card, parked digest rows.
- `automation/tests/test-broadsheet-view.py`: 61 tests OK,
  `node --check` clean; smoke page load zero console errors.
- `automation/tests/test-article-desks.py`: 10/10 (btop endpoint,
  omp-session id policy, dispatch-package-first ordering, terminal
  selection); plan-acceptance 28, allowlist 10, feedback 13 suites
  green.
- Full `make test` gate green; live beat regeneration produced 45
  articles with 7 fire-capable cards, one btop embed, and the parked
  digest. A concurrent-tier commit had reverted wave files mid-flight;
  all edits were re-applied from disk, grep-verified, and re-tested
  before this record.
- The gate also caught a doc-secrets false positive in the ISO
  installer arc (`OMARCHY_KEY="..."` — a public GPG fingerprint);
  renamed to `OMARCHY_GPG_FINGERPRINT` in a separate gate-repair
  commit, with the installer's indentation restored additively after
  an amend divergence (no force push; origin history stays linear).
