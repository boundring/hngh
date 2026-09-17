# Email/notification comparison: hngh vs jcode ambient (2026-09-15, read-only survey)

## 1. hngh current path (send + reply BOTH EXIST)
- Send: `automation/lib/notify-email.sh` -> `scripts/notify-email.py` (timeout-capped, best-effort).
  Config: `~/.hngh-automation/notify-email.conf` (env seam `HNGH_NOTIFY_EMAIL_CONF`). Only
  IMMEDIATE-class alerts send now; rest defer to daily digest `cadence/day/09-email-digest.sh`
  (day tier; durable artifact `logs/email-digest-<day>.md`, email is transport only).
  The report-queue row is always the contract; email failure never fails a row.
- Reply: **hngh already has an IMAP leg** — `automation/scripts/imap-poll.py` +
  `cadence/30m/56-imap-poll.sh` (stall-recovery plan step 11). Polls UNSEEN replies on the same
  account ([imap] section of the same notify-email.conf; pass precedence 1Password item ->
  pass_cmd -> smtp pass), converts each to an operator-item via lib/operator-item.sh;
  plan decisions land as DRAFT proposals in automation/digest/ (never auto-accepted).
  Fail-closed, messages marked \Seen, never deleted. Tests: `automation/tests/test-imap-poll.py`,
  `test-email-qa.py`; patrol checks `send ok rc=0` rows in `logs/notify-email.log`.
- jcode [safety] email keys present in ~/.jcode/config.toml: email_enabled, email_smtp_port,
  email_imap_port, email_reply_enabled (values not read).

## 2. jcode ambient email
- Crate `crates/jcode-notify-email/src/lib.rs` (529 lines): `send_email` (lettre, STARTTLS,
  HTML from markdown, Message-Id `<ambient-{cycle_id}@jcode>`); `poll_imap_once` returns
  `Vec<ReplyAction>`: `PermissionDecision{request_id, approved, message}` and
  `DirectiveReply{cycle_id, text}` — replies are tied to ambient cycle ids and gate/execute
  inside the ambient session loop. Also ntfy + Telegram channels in jcode-app-core
  (notifications.rs, channel.rs, telegram.rs) as parallel transports.

## 3. Integration assessment
- (a) hngh calls jcode notify-email CLI directly: high reuse of sending, but new binary dep on
  the jcode repo in kernel automation, plus config translation (two homes). Effort: medium.
  Failure mode: cross-repo coupling, version drift; hngh's fail-closed conventions must wrap it.
- (b) Route hngh notifications through jcode ambient channel layer: would need an ambient
  session running to ingest queue items/DMs — hngh boundary forbids starting daemons/sessions
  from kernel, and cycle-id semantics (PermissionDecision/DirectiveReply) don't map to hngh
  report rows. Effort: high. Failure mode: ambient session must be alive; breaks hngh's
  "row is the contract" independence.
- (c) hngh reimplements IMAP-reply against its own report queue: **already largely done** —
  imap-poll.py files replies as operator-items. Remaining gap vs jcode: no structured
  permission-decision command grammar (free text + draft plan proposals only) and no
  report-id-in-subject threading. Effort to close gap: small (subject thread-id + a few
  command verbs parsed in imap-poll.py, fixture-backed tests). Failure modes: misparsed
  directives (mitigate: strict verb whitelist, fail closed), duplicate replies (idempotent via
  \Seen marking — already handled).
- Recommendation: option (c) — extend the existing imap-poll path with subject-carried report
  ids and a small directive grammar; no jcode dependency, stays inside hngh's contract.
