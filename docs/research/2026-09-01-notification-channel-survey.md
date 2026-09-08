# 2026-09-01 — notification-channel survey

Status: RECORD
Date: 2026-09-01

## Scope

Survey candidate channels for operator reports (progress digests, alerts).
Ground in: browser-relay notification history (browser-based Google-Messages
notifications were token-costly), OSS prior art (ntfy, Apprise), and the
notify-email slice landed 2026-09-01 (commit 1d3be0c).

## Channels scored

### 1. Email (SMTP) — notify-email.py (stdlib)

- Token cost: zero (no LLM involvement in dispatch).
- Latency: seconds (SMTP send).
- Privacy: full (mail to operator's own inbox; no third party).
- Reachability: operator must check email.
- Cost: operator's own SMTP config (~$0).
- Status: ESTABLISHED — landed in commit 1d3be0c, tests green.
- Next: operator configures ~/.hngh-automation/notify-email.conf.

### 2. ntfy.sh (HTTP topics)

- Token cost: zero (curl POST, no LLM).
- Latency: sub-second (HTTP push to ntfy server).
- Privacy: low (payload goes to ntfy.sh hosted topics; operator controls
  topic naming but not the relay server). Self-hosted ntfy possible but
  requires network exposure.
- Reachability: mobile push via ntfy app (operator must install).
- Cost: free tier unlimited topics; self-hosted = one VPS.
- Status: PRIOR ART — OSS docs verified; not yet configured.

### 3. Apprise CLI

- Token cost: zero (CLI, no LLM).
- Latency: seconds (via Apprise's built-in transports).
- Privacy: varies by transport (same as raw email, but with unified API).
- Reachability: supports 40+ transports (email, Slack, Telegram, etc.).
- Cost: free OSS.
- Status: PRIOR ART — not yet configured; heavier dependency than notify-email.

### 4. Browser relay (Google Messages)

- Token cost: HIGH — each notification requires an LLM call to compose +
  dispatch via browser relay (the problem this survey replaces).
- Latency: seconds-to-minutes (LLM round-trip).
- Privacy: low (Google account involved).
- Reachability: high (operator's phone).
- Cost: high per notification.
- Status: OBSOLETE — superseded by notify-email.

## Recommendation

**Primary: notify-email.py (SMTP).** Zero token cost, full privacy, operator
owns config. One-time config; the operator places an INI at
~/.hngh-automation/notify-email.conf.

**Fallback: ntfy.sh.** Zero token cost, sub-second latency, mobile push.
Configured as a secondary channel when operator installs ntfy app.

**Deprecate: browser relay.** Token-costly; notify-email covers the same
reachability with zero LLM involvement.

## Next steps

1. Operator configures notify-email.conf (critical-class; parks with alert).
2. Operator installs ntfy app (optional; parks with alert).
3. Wire notify-email into overnight-cycle.sh for alert-only dispatch.
4. Route digest via notify-email in dry-run mode; operator confirms delivery.

## Sources

- docs/project/plans/README.md (plan contract).
- CHANGELOG.md newest entry 2026-08-31 (connectivity slice commit 1d3be0c).
- scripts/notify-email.py (stdlib SMTP, fail-closed).
- ntfy.sh docs (self-hosted HTTP topics, mobile push).
- Apprise docs (40+ transports, CLI).
