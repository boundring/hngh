<!-- plan: status=accepted risk=normal accepted=2026-09-19T19:04:00Z routed-from=imap-conf-keys -->
# 2026-09-18 — routed candidate

Routed by scripts/router-tick.py from alert identity `imap-conf-keys`
at 2026-09-18T13:16:30Z. Alert text: plan 2026-09-09-stall-recovery step 11 live clause: add [imap] keys to ~/.hngh-automation/notify-email.conf (host/port/user + 1password item for the password, same fail-closed pattern as [smtp]) — machine sessions never write credential config (standing guardrail); poll+30m beat+34-case suite are landed and the poll fail-closes no-op until conf lands (STATE.md imap-dormant rows; live dry-run 2026-09-18T13:02:51Z no-op); once conf lands run scripts/imap-poll.py --dry-run for the live unread-listing proof and tick step 11; note: 56-imap-poll.sh last cadence mount 2026-09-17T15:48:52Z, watchdog silent — mount gap worth a glance when conf lands

## Steps

- [ ] Delve: open research subject fail-20260918-imap-conf-keys for imap-conf-keys; record disposition; then fix or park
      Verification: research subject fail-20260918-imap-conf-keys present in research-subjects.txt with a recorded disposition; alert fixed or parked
