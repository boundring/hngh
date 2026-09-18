# 2026-09-18 -- stall-recovery step 11: IMAP bidirectional mechanism verified landed; live-mailbox clause parked on operator conf

## Question

Plan 2026-09-09-stall-recovery-and-operator-surfaces step 11
("bidirectional email contact") asks for an IMAP poll drop-in reading
operator replies, fail-closed conf, reply->operator-item conversion,
seen-marking with no deletes, and a live dry-run poll listing unread
state. A sibling commit referenced scripts/imap-poll.py before any
step-11 lane ran -- was the step already landed, and what (if
anything) remains?

## Decision

**The mechanism is landed and verified on its own surface; this
session filed no code. The one remaining plan clause -- a live poll
against the real mailbox listing unread state -- is unsatisfiable
without [imap] keys in the notify conf, and machine sessions never
write credential/provider configuration (standing guardrail).**
Operator-item `imap-conf-keys` filed 2026-09-18T13:09Z; plan step 11
stays open with the annotation and ticks only when the live poll
runs against real conf.

## Evidence (each read fresh this session)

- `automation/scripts/imap-poll.py` + `automation/cadence/30m/
  56-imap-poll.sh` (timeout 120) exist; conf resolves to
  ~/.hngh-automation/notify-email.conf (:89-92), the same file the
  send leg uses, exactly as the plan specified.
- `automation/tests/test-imap-poll.py` -- 34 tests OK cold this
  session (0.2s), covering the plan's suite clauses: missing
  conf/section/keys fail closed, reply->operator-item conversion,
  dry-run-files-nothing, processed-marked-seen,
  failed-filing-stays-unseen, tick cap, client-surface-cannot-delete,
  PEEK fetch, attachment-paths-only. Registered in the main Makefile
  test target (Makefile:62) -- the older CHANGELOG "not wired" note
  is superseded.
- Landing commits: 8354731b (reply-parse lane + suite wired into the
  gate), c43f9127 (ONEPASSWORD_SERVICE_KEY -> OP_SERVICE_ACCOUNT_TOKEN
  mapping in op_password, mirroring lib/credentials.sh).
- Live dry-run poll 2026-09-18T13:02:51Z: `config missing
  [smtp]/[imap] section -- no-op` (STATE.md crumb); the conf carries
  only `[smtp]` (host/port/user/from/to/item keys).
- Beat mounts: STATE.md imap-dormant crumbs through
  2026-09-17T15:48:52Z; no 56-imap-poll mount since (mount gap named
  in the operator item). Not a general 30m-tier stall: 58-patrol
  filed alerts at 2026-09-18T13:05Z and 46-beat-watchdog ran
  2026-09-18T12:31:29Z.

## What is parked and why

The plan's own Change text folds conf provisioning into the step, but
credential configuration (mailbox host/user/password item) and
enabling a live-polling service against the operator's mailbox are
operator-territory under the standing guardrail -- the same class as
step 9's unarmed quota keys. The poll fail-closes no-op until the
keys land, by test and by live observation.

## Residual loop

Full automation `make test` red only on the sibling router-tick
scrub-single-source lane (failing test reads none of this slice's
files; `make -k` shows every other suite OK). Kernel gate green
(`make test`, 2931 checks, rc=0) for this slice's ceremony tick.
Step-10 postscript for the same wake: the 2026-09-18 review beat
ended `review unavailable: model chain down (pin=review quota ladder
exhausted through local)` (queue alert 13:03:40Z, during the
system-network-down window) -- an availability gap on an already-
landed ladder, not a step-10 regression.
