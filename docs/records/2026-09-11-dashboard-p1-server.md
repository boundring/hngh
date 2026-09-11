# 2026-09-11 — dashboard P1 server wave

Lands the server half of the dashboard P1 wave
(docs/research/2026-09-11-dashboard-adversarial-review.md §5 P1) and the
token guard from plan 2026-09-09 stall-recovery step 6. One commit;
tests failing-first in `automation/tests/test-dashboard-p1.py` (22 cases,
real bound ThreadingHTTPServer, every path seamed into tmp — same
discipline as test-dashboard-feedback.py).

## What landed (automation/dashboard-server.py)

- **Token guard (F3, security, fail closed)**: every POST route requires
  `X-Hngh-Token` matching `dashboard/token.txt` (32-hex, generated on
  first boot, mode 600 re-enforced on every read, reused after).
  403 before any dispatch. The served index injects the token as
  `<meta name="hngh-token">` so the legit UI reads it from the page it
  already loaded. `DASHBOARD_PORT` env now selects the bind port
  (default 8890 unchanged) so bounded manual instances are possible.
- **Session slicing**: `GET /session/<id>?tail=N` (N clamped 1..200,
  default 20) returns `{id, entries: [...last N]}` from sessions.json;
  unknown/invalid id 404. Slices kilobytes instead of the 2.1 MB feed.
- **SSE push**: `GET /events` — text/event-stream over mtimes of
  operator-items.json + operator-dismissed.json + readout.json (the
  verdict feed). One no-payload `event: change` per change (client
  re-fetches the small feed), `: heartbeat` comment every 15s, clean
  close on client disconnect.
- **Telemetry feed**: `GET /telemetry.json` — 24h hourly buckets
  `{hour, spend, tokens_in, tokens_out, runs}`, per-model leg counts,
  total spend, straight from dashboard/telemetry.db (read-only sqlite,
  jobs/telemetry.py schema). Emitted on request, 30s in-process cache,
  zeroed payload when the db is missing.
- **Mark-read (B8)**: `POST /report-queue/mark-read {"id": str}` wraps
  `scripts/report-queue --mark-read <id>`; handoffs-logged like dismiss
  (`mark-read | <ts> | automation|<id> | report marked read`). CLI
  refusal (unknown id, exit 2) maps to 400. `--prune` stays CLI-only.

## Email-form migration (the one tradeoff)

Email forms cannot carry the `X-Hngh-Token` header, so
`scripts/email-digest.py feedback_form_html()` renders the token as a
hidden `hngh_token` field at digest-render time (the digest is generated
on-host, where token.txt is readable); the server accepts the field only
for urlencoded /api/feedback posts, header takes precedence. **Residual
risk, accepted**: the token rides in the digest email — it gates
ledger-mutating POSTs on the LAN, it is not itself a secret; the worst
an email-leaked token enables is the existing display/ledger families.
If the server has never booted the form renders with an empty token and
fails closed (403) server-side.

## Verification

- `python3 -B tests/test-dashboard-p1.py`: 22/22 green; hermetic under
  `env -i` too. Existing test-dashboard-feedback.py updated for the new
  contract (posts carry the token; hermetic token seam).
- `make test` green through all test lines; the final
  lint-identifiers failure is a sibling's uncommitted
  `lib/launch-session.sh` edit (BILI_OCGO_BIN undefined), not this wave.
- Bounded live instance on port 8891 (killed after): index meta inject,
  403/403 without/wrong token, 53-byte tail=2 slice, live telemetry
  numbers, mark-read unknown id → 400.

## Not in scope here

UI wiring (sessions-view.js etc. read the new routes) is a follow-up
worker; dashboard/ UI files are gitignored runtime. The systemd unit is
not restarted (operator/cert territory): the running service keeps the
pre-token posture until its next restart, which is harmless — the token
file simply exists and the served code upgrades on next boot.