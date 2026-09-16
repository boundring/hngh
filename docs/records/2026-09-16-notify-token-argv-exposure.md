# Notify-seam token argv exposure: closed via stdin curl config

Date: 2026-09-16
Lane: automation free-commit (lib/notify.sh + notify test suites)
Class: credential argv hygiene (same MEDIUM class the cred-refresh
hygiene review ranked for `model.sh` — secrets sitting in
`/proc/<pid>/cmdline` for the duration of a call)

## Exposure

`lib/notify.sh` `_notify_send_telegram` built the request URL as
`https://api.telegram.org/bot${token}/sendMessage` and passed it as the
final curl argv, so `TELEGRAM_BOT_TOKEN` was readable from
`/proc/<curl-pid>/cmdline` for the whole call (up to the 20 s timeout).
`_notify_send_webhook` passed `WEBHOOK_URL` the same way; webhook
endpoints (Slack/Discord/automation hooks) commonly embed their auth
token in the URL itself, so that argv is secret-bearing too.

## Fix

Both send paths now pass only non-secret arguments on argv
(`--data-urlencode` / `-H` / `--data`, timeouts, output format) and
carry the URL through the curl config read from stdin:
`printf 'url = "%s"\n' "$url" | curl -s --max-time 20 -K - ...`.
The double-quoted config form needs no further escaping here (telegram
bot tokens are digit:alnum, no quotes or spaces; the config parser
still sees one clean `url` directive). Style is unchanged:
fail-closed (`|| code=000` -> breadcrumb, exit 0, no retry), and the
KEY RULE (notify.sh header) holds — the token is never logged or
echoed; the tests assert on argv/stdin separation of a stub value, not
on any real secret.

## Verification (test-first)

- `tests/test-notify-seam.sh` and `tests/test-notify-send-path.py`
  stub curls were extended to record the curl argv (`ARGV:` lines)
  separately from the stdin `-K -` config (`STDIN:` lines), then new
  assertions were added and confirmed RED before the fix: token and
  webhook URL absent from every argv line, present in the stdin
  config, for both the env-armed and mode-600-key-file-armed cases.
  GREEN after the lib change.
- Real-curl sanity: a loopback HTTP server received the POST at the
  stdin-configured URL path with the urlencoded body (HTTP 200),
  proving `-K -` ordering with argv data options behaves identically.
- Full gate `cd automation && make test`: green on the tree as it
  will be committed (HEAD + this slice), proven in a clean overlay of
  HEAD plus the three touched files; the live worktree's unrelated
  in-flight `dashboard/sessions-view.js` edit trips
  `test-dashboard-p0.py` (raw `setInterval`) and is not part of this
  slice.

## Dispositions

- **Webhook URL: treated as secret-bearing** (not an accepted risk):
  same stdin-config pattern applied in the same change.
- **probe-model-route 600-check**: handled by a sibling on the kernel
  lane (not this slice's scope; the probe-hygiene lint
  `tests/test-probe-hygiene.sh` continues to police key-gated curl
  shapes in `jobs/credential-health.sh`).
