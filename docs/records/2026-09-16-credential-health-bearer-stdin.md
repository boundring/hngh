# Credential-health bearer probes: header moved off argv to stdin curl config

Date: 2026-09-16
Lane: automation free-commit (jobs/credential-health.sh + test suites)
Class: credential argv hygiene — same class as the notify-seam fix
(docs/records/2026-09-16-notify-token-argv-exposure.md); secrets on
`/proc/<pid>/cmdline` for the duration of a call

## Exposure

All three authenticated probes in `jobs/credential-health.sh` passed the
credential on the curl argv:

- unsloth session token: `-H "Authorization: Bearer $tok"` against
  `$UNSLOTH_URL/v1/models`
- kimi key: `-H "Authorization: Bearer $kimi_key"` against
  `$kimi_models_url`
- ocgo key: `-H "Authorization: Bearer $ocgo_key"` against
  `$ocgo_models_url`

While each curl ran (up to its 10 s timeout), the resolved key value sat
in `/proc/<curl-pid>/cmdline`, readable by any local process — the same
vector e1's classification note and the notify-seam record flag. The
2026-09-10 probe-measures-itself lesson (headerless probes reading their
own 401) made these probes authenticated; the argv shape was carried
over silently from that fix. No value was ever logged — breadcrumbs
carry codes and source names only.

## Fix

Each probe now feeds the header through the stdin curl config, the
pattern the notify-seam fix established:

```
printf 'header = "Authorization: Bearer %s"\n' "$key" |
  curl -s --max-time 10 -K - -o /dev/null -w '%{http_code}' "$url"
```

Only non-secret arguments (timeouts, `-o`, `-w`, the endpoint URL) stay
on argv. `-o /dev/null -w '%{http_code}'` semantics are unchanged, and
every breadcrumb string is byte-identical — the probes report `http=`
codes and arming source names, never values. The double-quoted config
form is safe for the same reason as in the notify fix: a config parser
error surfaces as `code=000` and a breadcrumb, never an echo.

## Dispositions

- All three probes converted — no accepted-risk exemptions.
- g2 coordination (missing TOKEN_FILE gate): untouched here. The
  g3 conversion only re-routes the header transport; the TOKEN_FILE
  gate is a separate pre-probe guard and is left for the g2 slice to
  land without collision. No line of the g2 surface was modified.

## Verification (test-first)

- New `tests/test-credential-health-argv.sh` (stub curl recording
  `ARGV:` vs `STDIN:` lines, test-notify-seam.sh pattern) confirmed RED
  before the fix: token values absent from every argv line, present in
  the stdin config, for unsloth (token file), kimi (env-armed and
  mode-600 key file), and ocgo (env-armed); exit 0 and breadcrumb
  strings asserted unchanged throughout. GREEN after the conversion.
- Real-curl loopback check in the same suite: `-K -` header directive +
  argv URL + `-o/-w` ordering delivers the Authorization header
  (HTTP 200, header received by the loopback server).
- `tests/test-probe-hygiene.sh` contract consciously evolved with the
  shape (per its own header): per-gate curls must use `-K -`; no curl
  record may carry `Authorization:` (argv regression guard); exactly
  three `printf 'header = "Authorization: Bearer %s"\n'` directives, one
  per probed gate (`$tok`, `$kimi_key`, `$ocgo_key`); deck `/health`
  stays the single exempt bare GET; catch-all stays fail-closed and new
  key-gated probes cannot hide without a directive.
- Regression sweep: `test-credential-kimi.sh` (real loopback: probe
  still authenticates, crumb still says `http=200`),
  `test-credential-alert-dedup.sh`, `test-credentials.py`,
  `test-credential-evidence.py` — all green.
- Full gate `cd automation && make test` green on the committed tree
  (clean overlay of HEAD + this slice, per the notify-seam precedent;
  unrelated in-flight worktree edits excluded).
