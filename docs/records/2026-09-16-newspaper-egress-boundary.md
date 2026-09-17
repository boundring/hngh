# 2026-09-16 — newspaper egress boundary: the surfaces are local-only; the digest decks are not

## Question

Deep-task node `llc-newspaper-egress-audit` (follow-up to `llc-news-prompt-audit`,
which could not close it): does any consumer read `~/.hngh/newspaper/*` and ship
its files beyond the local home? The answer gates the severity of the
digest-chain redaction gap (`llc-digest-ledger-redaction`): a pathy deck-B
render is a different threat class depending on whether deck B never leaves the
machine or is published.

## Decision

**`~/.hngh/newspaper/*` is empirically local-only. No lane ships newspaper
files — article bodies, media, edition.json — beyond the machine.** But the
underlying digest decks (the newspaper's input) do egress on three surfaces,
none of which is the public web: the operator email, the LAN-bound dashboard,
and (deck A quote only, scrubbed) the pushed GitHub journal.

## Evidence: every reader of ~/.hngh/newspaper

- `automation/jobs/news-articles.py:65-69` — the writer (deck-A enrichment,
  `~/.hngh/newspaper/<date>/articles/<slug>.md`); ingress, not egress.
- `automation/jobs/newspaper-edition.py:42-46` — the local edition writer
  (digest.md copy, local-GPU media, index.html, edition.json); writes in-home.
- `automation/jobs/digest-html.py:39-43` (`ARTICLES` seam) and
  `load_articles` (:164) — reads articles to enrich Deck A with
  "Extended article" pointers. Consumers of this render:
  - the dashboard `GET /digest-html/<name>.html`
    (`automation/dashboard-server.py:526`), LAN-facing (see below);
  - `automation/jobs/digest-local.py` (writes `~/.hngh/dispatch/<date>/`).
- `automation/jobs/digest-public.py` — `render_page` (:225, :287-289) prints
  only the article **slug** (`Extended article: <slug> (local edition only)`);
  article bodies never enter the dispatch edition. `write_publication`
  (:320-334) writes `~/.hngh/dispatch/<date>.md` — **in-home**, and
  `publication-review.py:231-233` only reads it back (review output also
  in-home, `~/.hngh/archive/digest/PUBLICATION-REVIEW-<date>.md`).
- `automation/lib/hngh_home.py:33` — path helper only.

Neither `scripts/generate-publication` (kernel) nor
`automation/scripts/generate-publication` reads `~/.hngh/newspaper` at all:
the kernel one builds `docs/journal/<date>.md` from telemetry/queue/checkins
plus a **scrubbed** deck-A lead quote (`story_section`, `dl.scrub_paths`,
landed 2026-09-16 per `docs/records/2026-09-16-digest-seam-path-redaction.md`);
the automation one assembles `docs/research/` only. The notify seam
(`automation/lib/notify.sh`) can POST arbitrary bodies (email/telegram/
webhook) but has **zero production callers** carrying newspaper or dispatch
payload (only tests, with fixed bodies).

## Evidence: where the digest decks DO go

1. **Operator email (egress, conditional).** `cadence/day/09-email-digest.sh`
   emails `email-digest.py` output; `--html` renders `html-digest.py`, which
   includes `render_mega` (:311-338) — **deck B verbatim** from
   `automation/digest/<date>.md` — as the email HTML part. Armed only when the
   operator's notify-email conf exists; otherwise dormant.
2. **Dashboard (LAN exposure, not public web).** `dashboard-server.py:1152`
   binds **`0.0.0.0:8890`**, and `/digest-html/` renders deck B verbatim plus
   newspaper-article enrichment. Reachable by LAN peers; no evidence of an
   internet-facing tunnel in the tree (firewall posture not verified here).
3. **GitHub push (deck A quote only).** The kernel repo (origin
   `git@github.com:boundring/hngh.git`) commits `docs/journal/` and README
   dispatch tables — ledger numbers and one deck-A item quote `[:140]`,
   path-scrubbed since 2026-09-16. Deck B never enters committed docs; the
   digest raw files are untracked (`automation/.gitignore:26 digest/`).

## Threat-class consequence for llc-digest-ledger-redaction

A pathy deck-B render does **not** reach the public internet. It reaches the
operator's mailbox (via store-and-forward SMTP relays) and LAN peers via the
dashboard. That makes path redaction on the mega line a **defense against LAN
scraping and email-transport leakage, not a public-disclosure breach** —
moderate severity, and already mitigated at source by `scrub_paths()` in
`digest-ledger.py` (both quotes) and the kernel deck-A quote, per the
2026-09-16 seam record. Residual exposure: deck B verbatim on the
0.0.0.0-bound dashboard predates/independent of the ledger quote sites.

## What this does not cover

- Firewall/router posture for port 8890 (is the dashboard truly LAN-only?).
- Whether the operator's current mailbox relay is local or third-party.
- Any future lane that adds `~/.hngh/newspaper` to the email HTML part.
