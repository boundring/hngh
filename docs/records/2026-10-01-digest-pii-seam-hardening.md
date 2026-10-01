# Digest PII seam hardening (hngh-292)

Date: 2026-10-01. Scope: automation digest writers; no kernel surface.

## Problem

The digest writers failed open at three seams (bead hngh-292):

- `automation/jobs/digest-html.py` `_load_scrub` (and its copy in
  `automation/scripts/html-digest.py`) swallowed every loader error and
  returned an identity scrubber: a missing or corrupt scrub module meant
  the page rendered unredacted.
- `automation/jobs/digest-public.py` had no scrub seam at all: home
  paths, `file://` URLs, and dash-mangled path-derived ids went to the
  public edition verbatim.
- `automation/jobs/digest-local.py` staged any `hngh-docs/media/` rel
  path without an escape check (`_stage_media`), and its HTML sink
  passed `file://$HOME/...` through untouched.

## Changes

- digest-html `_load_scrub` and html-digest `_load_scrub` now raise
  `RuntimeError("... refusing to render")` from the loader error
  (fail closed; accept-plans already was).
- digest-public gained a fail-closed `_load_scrub` (module-returning,
  mirroring research-harvest's loader), and `render_page` now runs a
  per-line sink: `file://` URLs cut first, then `scrub_paths`, then
  `scrub_truncate_pathy` for dash-form fragments. The saga blocker id
  passes through `scrub_truncate_pathy` at its sink.
- digest-local refuses media rels whose realpath escapes the docs media
  root (`ValueError` -> rc 1), and redacts its page via a fail-closed
  `redact_home` loader after cutting `file://` URLs.

## Lessons

- `scrub_truncate_pathy` CUTS ITS INPUT at the first path-derived
  segment; page-wide it amputates everything after the first mangled
  slug (caught by the fixture: saga vanished). Line-level application is
  the correct grain.
- The EmailDigest sandboxes (tests/test-notify-email.py) were green
  THROUGH the fail-open hole -- no digest-ledger.py was staged and the
  identity fallback kept rc 0. They now stage the real
  `jobs/digest-ledger.py` + `lib/scrub.py` per the test-digest-html.py
  fixture law ("no second regex anywhere").
- digest-html's parse-layer scrub replaces the whole home token with
  `[redacted path]`; tilde forms only appear from machine chrome, so the
  fixture pin asserts a redaction form, not a tilde shape.
- Fixture digest headers must match `SECTION_RE`
  (`^## (\d{4}) (\d{4}-\d{2}-\d{2})\s*$`); `## 1200 UTC` silently
  renders empty.

## Verification

- New hermetic fixture suite `automation/tests/test-digest-pii-seams.sh`:
  13 pins, all hold -- digest-local happy path, no raw home, redaction
  form present, media escape refused with nothing staged, refusal named;
  digest-public page free of raw home / `file://` / dash-mangled id with
  saga intact; three loader probes with a corrupt scrub module each
  printing "refused:" instead of rendering.
- Failing-first evidence: probes showed the unredacted page (raw home
  token, `file:///home/...` URL, dash id) before each flip.
- `python3 tests/test-notify-email.py EmailDigest`: 30 tests OK after
  the fixture staging fix.
- Full automation gate green; kernel gate unaffected (no kernel files).
