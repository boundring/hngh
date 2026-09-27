# Email doctrine: three digests a day, no on-event mail

Date: 2026-09-27. Slice 2 of the course-correction pass
(local://hngh-course-correction-plan.md).

## Decision

Operator email is scheduled, never on-event. The only sender is the new
`automation/cadence/subhour/57-digest-send.sh`, firing at 07:30, 15:30,
and 22:00 America/New_York (operator wake / work-end / pre-bed), exactly
once per slot via a stamp file (`HNGH_DIGEST_STAMP_DIR/.hngh-digest-<slot>`).

- `automation/config.env` exports `HNGH_NOTIFY_IMMEDIATE=0` — exported,
  because unexported vars do not cross the cadence-tick `bash $f`
  drop-in boundary. `notify-email.py classify` then routes every alert
  row to the digest bucket; the report-queue row (the contract) is
  unchanged.
- `automation/cadence/calendar/daily/09-email-digest.sh` is compose-only
  (artifacts `logs/email-digest-<day>.md/.html`); its send leg moved to
  the subhour slot script. It never sends.
- Digest content upgrades (`automation/scripts/email-digest.py`):
  a feedback-backlog line from `dashboard/operator-items.json`
  (open `[feedback:` items, oldest first, top three snippets), a
  newspaper link (`http://127.0.0.1:8890/newspaper.html`) in the
  footer, and a ghost-editorial seam (silent until slice 4 lands
  `lib/ghost-voices.py`).
- IMAP mute list (`automation/scripts/imap-poll.py`): senders matching
  `noreply@github.com` (default) or the conf `[mute] senders=` list are
  marked `\Seen` and never filed — GitHub CI notification noise stops
  reaching the operator-item feed at the poll layer.

## Failure posture

- 57-digest-send exits 0 on every path; a failed send files a
  `digest-send-fail:<slot>:<date>` alert row, stamps the slot, and does
  not retry within the slot (next slot retries).
- Send failure of the transport does not block composition; artifacts
  are written before any send attempt.

## 1Password probe result

`Agent Mail` (Hngh Secrets vault) carries an API-key-style password only
(hostname/username fields empty) — not SMTP credentials, so
`~/.hngh-automation/notify-email.conf` cannot be materialized
fail-closed. Operator items parked: `email-smtp-credentials-missing`
(add host/port/user/password to the vault item, then
`bash automation/scripts/setup-notify-email.sh`) and
`imap-mute-github-note` (mute transparency).

## Verification

- `automation/tests/test-digest-send-schedule.sh` (new, 15/15): off-slot
  no-op, exactly-once per slot, force interlock
  (`HNGH_DIGEST_TEST=1` + `HNGH_DIGEST_FORCE_SLOT`), send failure files
  an alert and does not retry.
- `automation/tests/test-digest-compose-upgrades.py` (new, 4/4).
- `automation/tests/test-imap-poll.py`: 36/36 including the two new
  MuteList cases.
- Full `make -C automation test` rc 0 (see slice commit).
