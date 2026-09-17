# Model.sh chat legs: bearer headers moved off argv to stdin curl config

Date: 2026-09-17
Lane: automation free-commit (lib/model.sh + test suites)
Class: credential argv hygiene — notify-seam class; secrets readable in
`/proc/<pid>/cmdline` for the duration of a call
Closed graph gap: `gap-modelsh-bearer-disposition`

## Why not a disposition: the "prior audit" did not exist

The e1 classification had excluded the model.sh chat legs from needs-fix
as "already-audited cred-refresh-hygiene scope". That audit record does
not exist: no docs/records entry of that name or content; e2 admitted
the same. The candidate citations were checked and do not cover it:

- `docs/records/2026-09-10-automation-ci-and-probe-hygiene.md` covers
  only the headerless-probe regression (probe measures its own missing
  header), not argv transport.
- `docs/design/credentials-posture.md` is a 1Password migration plan.
- `docs/records/2026-09-16-risk-dispositions-cred-argv.md` "Disposition
  summary" table explicitly does NOT list model.sh.

So option (b) — cite a genuine prior audit — was unavailable, and option
(a) — fix the sites — was taken. This record closes the gap so no
exclusion rests on a nonexistent document.

## Exposure (pre-fix HEAD)

Live secret values on the curl argv, world-readable via
`/proc/<curl-pid>/cmdline` for up to MODEL_TIMEOUT per call:

- `_post_chat` (shared POST+parse scaffold for the remote / kimi / ocgo
  / zai / deck chat legs): `${auth:+-H "Authorization: Bearer $auth"}`
  (model.sh:131 pre-fix)
- `unsloth_attempt` (unsloth chat + 401-retry path):
  `-H "Authorization: Bearer $tok"` (:220 pre-fix)
- `_unsloth_ctx_limit` (context-window probe of
  `/api/inference/status`): `-H "Authorization: Bearer $1"` (:250
  pre-fix)

The refresh-path curl (`$UNSLOTH_URL/api/auth/refresh`, :199 pre-fix)
carries the single-use refresh token inside the JSON body, not on argv;
it is refresh-path scope proper and deliberately out of this slice.

## Consistency argument

g3 (ccf8d7b5, 2026-09-16) converted the credential-health PROBES of the
exact same endpoints (unsloth, kimi, ocgo) to the stdin curl config
with "no exemptions", so the production legs those probes exercise were
the last remaining Bearer-on-argv sites in the tree (tree-wide grep at
fix time: model.sh:131/220/250 only). Same pattern as the notify seam
(docs/records/2026-09-16-notify-token-argv-exposure.md).

## Fix

All three sites now feed
`printf 'header = "Authorization: Bearer %s"' | curl -K -`; only
non-secret arguments (URL, timeouts, content-type, `-o`/`-w`) stay on
argv:

- `_post_chat`: the caller pipes the JSON body into the function's
  stdin; the body is staged to `$btmp` (`cat >"$btmp"`) so stdin is
  free for the curl config, and the request rides `-d @"$btmp"`. The
  header directive is built conditionally (`cfg`), so the keyless deck
  leg sends no Authorization header at all.
- `unsloth_attempt`: body staged to `$btmp` (`_json_body` output), fed
  via `-d @"$btmp"`; bearer directive piped to `-K -`; `$btmp` freed
  after the call.
- `_unsloth_ctx_limit`: GET probe piped through the `-K -` directive.

`-K -` injection caveat (g4): the values are single-line key-file/env
keys and the printf `%s` form matches the landed notify.sh pattern;
keys with embedded quotes would surface as a curl config parse error
(HTTP 000 + breadcrumb), never an echo.

## Verification (test-first)

- New `tests/test-model-bearer-argv.sh` (stub curl ARGV:/STDIN:
  recorder, test-credential-health-argv pattern): proven RED before the
  fix — 12 failures across remote (key-file armed), ocgo (env armed),
  unsloth_attempt, and _unsloth_ctx_limit; GREEN after (secret absent
  from every argv record, present in the stdin config; exactly one curl
  per leg; deck leg carries no Authorization header at all).
- `tests/test-probe-hygiene.sh` extended: the same mechanical form
  (continuation-joined curl records) now also classifies
  `lib/model.sh` — no Authorization on any curl argv, every non-exempt
  curl uses `-K -`, exactly three stdin Bearer directives. The single
  exemption is the refresh-path curl (token rides the JSON body, not a
  Bearer header; out of this slice by title). Red-proven against the
  pre-fix HEAD blob (Authorization-on-argv=1, non-K non-exempt=1)
  before the conversion, without touching the live file mid-flight.
- Real-curl loopback (socat capture): one request carried both the
  `header = "Authorization: Bearer ..."` directive (from `-K -`) and
  the `-d @"$btmp"` body — transport semantics preserved.
- Sibling suites after the change: test-model-remote-token-mode,
  test-model-pin-routing, test-credential-health-argv,
  test-probe-hygiene — all exit 0.
- Registered `tests/test-model-bearer-argv.sh` in automation/Makefile.

## Dispositions

- All three argv sites converted — no accepted-risk exemptions; the
  exclusion formerly backed by the nonexistent audit is retired.
- Refresh-path body token (`/api/auth/refresh`): out of scope here by
  title; remains a separate tracked concern, not an argv exposure.
- Commit note: a sibling session's staged-index sweep carried the core
  `_post_chat`/`unsloth_attempt` conversion into its 51f5f6d8 (the
  exact hazard the 2026-09-14T08:44:40Z lesson warns about); this
  commit lands the remaining hunks (docstring, conditional `cfg`,
  `$btmp` cleanup, ctx-limit conversion, both suites, Makefile hunk)
  as one slice.
