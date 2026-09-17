# 2026-09-17 — refresh path off argv: staged body + the sixth token-file gate

## The gap

Node `gap-refresh-argv-body-and-refreshfile-gate` (critique-gate finding
against `gap-modelsh-bearer-disposition`, whose deferral of the refresh
path rested on a false premise — "POST body, not argv" was wrong):

- `automation/lib/model.sh refresh_unsloth_token` interpolated the
  single-use refresh token VALUE into the curl `-d` argument:
  `-d "{\"refresh_token\":\"$rtok\"}"`. A value on the curl argv sits
  world-readable in `/proc/<pid>/cmdline` for the whole call — exactly
  the exposure class the bearer-argv conversions eliminated
  (2026-09-16/17; notify seam, credential-health probes, then the
  model.sh chat legs, 1ef90d76). The landed tree-wide contract ("zero
  credential values on argv", `test-probe-hygiene.sh`) had a blind
  spot: the lint hard-failed Authorization-on-argv but never policed
  credential-bearing `-d "{...$var...}"` bodies, and the lint's
  refresh-path exemption comment even recorded the wrong fact ("POST
  body, not argv").
- The `REFRESH_FILE` read (`cat` above the POST) had NO mode-600 stat
  gate — the only remaining ungated credential-file read after
  gap-unsloth-tokenfile-600-gate closed five TOKEN_FILE/
  REMOTE_TOKEN_FILE readers. The 2026-09-16 record exempted only the
  post-refresh TOKEN_FILE re-read, never the refresh-token read
  itself. The refresh token is single-use but credential-bearing:
  possession mints access tokens. The pair is chmod-600 only AFTER a
  successful rotation, so an operator-created or restored 0644 refresh
  file was silently read and POSTed as the request body.

## What landed

- `automation/lib/model.sh refresh_unsloth_token`:
  - mode-600 gate above the `cat`, in the exact kimi/remote/unsloth
    byte shape: absent-file contract made explicit first, then
    `stat -c %a != 600 -> breadcrumb "refresh key file too open
    (chmod 600 required)" -> return 1`, fail-closed BEFORE the value
    is read or sent;
  - the JSON body is staged to a mktemp file and sent as
    `-d @"$btmp"` — the exact `_post_chat`/`unsloth_attempt` pattern:
    the file PATH rides argv, the value never does. `%{http_code}`,
    `-o`, and both breadcrumbs are unchanged; wire shape verified
    byte-identical (below).
- `automation/tests/test-model-refresh-hygiene.sh` (new, in the
  Makefile fleet) — two red/green mechanisms: (1) a /proc-style argv
  capture (stub curl records ARGV: and, emulating `-d @`/`-o`, the
  staged BODY: and the response) proving the value is absent from argv
  pre-fix/present pre-fix and absent post-fix, the body rides
  `-d @file`, and the success path still completes (breadcrumb,
  rotated pair written, mode 600); (2) a real local HTTP stub proving
  the arriving body is byte-identical
  (`{"refresh_token":"<value>"}`), exactly one POST hits
  `/api/auth/refresh`, and the rotation lands. Plus the 0644
  REFRESH_FILE refusal (zero POSTs) and the absent-file dormant
  contract.
- `automation/tests/test-model-remote-token-mode.sh` — new section 5
  (the sixth credential-file reader): 0644 refresh file -> rc 1 +
  `refresh key file too open (chmod 600 required)`; 0600 -> past the
  gate (FAILED token-refresh breadcrumb shape at a dead URL proves the
  gate did not fire); absent file -> its own dormant breadcrumb.
- `automation/tests/test-probe-hygiene.sh` — the `-d` blind spot
  closed in both lint targets (credential-health.sh and model.sh):
  any interpolated curl body (`-d "{...$var...}"`, escape-aware regex)
  is a hard failure, and the refresh curl is positively pinned to the
  staged form (`-d @"...`, exactly one refresh-path curl). The lint's
  exemption comment now states the true fact: the refresh path is the
  -K exemption because it carries no Bearer header, and its body must
  stay staged.
- `automation/Makefile` — new suite registered next to the other
  model-leg suites.

## Red proof

With the new cases in place and the gate/staging temporarily reverted
(the pre-fix model.sh):

- `FAIL: argv: refresh token VALUE on curl argv (/proc cmdline exposure)`
- `FAIL: gate: zero POSTs (value never sent) (want [0] got [1])` — the
  0644 refresh token value was POSTed to the stub as the request body.
- `FAIL: refresh 0644: too-open breadcrumb (want [1] got [0])`
- probe-hygiene flagged the exact line:
  `FAIL: model.sh interpolated body on curl argv: code="$(curl ...
  -d "{\"refresh_token\":\"$rtok\"}" ...)` and
  `FAIL: model.sh: refresh body staged to a file (-d @) (want [1] got [0])`.

Green after the fix landed.

## Validation

- `tests/test-model-refresh-hygiene.sh` — all pass (26 assertions)
- `tests/test-model-remote-token-mode.sh` — all pass (incl. 9 new
  section-5 assertions)
- `tests/test-probe-hygiene.sh` — all pass (incl. the new guards)
- `bash -n` on model.sh and all touched suites
- Full model-leg fleet: bearer-argv, deck, kimi, ocgo, pin-routing,
  zai-proxy, demote, reply-scrub, credential-health-argv,
  probe-token-mode, review-ladder — all pass (exit-code verified)
- full `cd automation && make test`: ALL PASS

## Census amendment

This is the SIXTH credential-file reader gated. The
2026-09-16-unsloth-tokenfile-600-gate.md record's "five of five
readers" claim is amended (sibling section below) — that slice's sweep
covered TOKEN_FILE/REMOTE_TOKEN_FILE readers only; the refresh-token
read was never in its census and no record dispositioned it until now.

## What this does not cover

- `curl`'s own internal handling of `-d @file` (the value transits the
  wire, not argv; the staged file is mktemp 0600 by default and is
  removed immediately after the call, success or failure).
- A credential-evidence digest row for REFRESH_FILE (TOKEN_FILE gets a
  freshness digest at rotate time in credential-health.sh; the refresh
  token rotates every success, so a static digest row would be noise).
  Flagged as an open question, not built here.
- The `_unsloth_ctx_limit` probe-side audit inherits the unsloth_chat
  gate (above the first token use), unchanged from the 2026-09-16
  record's note.
