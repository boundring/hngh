<!-- plan: status=executed risk=normal accepted=2026-08-28T17:35:00Z -->
# 2026-08-28 — remote hardening

Harden the remote-access path proven on 2026-08-28 (REMOTE-ACCESS.md)
and make the machine watch it. Autonomy rule (also in the
overnight-cycle prompt): hngh docs changes land via certificate
ceremony with a green `make test`; hngh kernel src/tests/Makefile/
hngh.asd changes are FORBIDDEN — park them. Never touch provider or
credential configuration, systemd unit state, tracked deletions outside
the 48h prune, or secrets.

## Steps

- [x] Desktop tailnet posture probe landed on the System page
      (hngh-automation `89f3f36` — probe_remote: tailscale state/ip,
      sshd, dashboard bind).
- [x] Deck tailscale userspace deployment + hngh-tunnel + hngh-desktop
      ssh alias (deck-side $HOME; documented in REMOTE-ACCESS.md).
- [x] Verify tailnet reachability once per day: from the desktop,
      `tailscale ping 100.79.162.3` (deck) — record a progress row
      when unreachable ("remote posture degraded") and none when fine;
      keep it a bounded 15s probe.
- [x] Document the operator-side HTTPS upgrade in REMOTE-ACCESS.md:
      `sudo tailscale serve --bg 8890` on the desktop serves the
      dashboard at https://brickertop.<tailnet>.ts.net (needs operator
      sudo; do not attempt from automation).
- [x] Add the daily budget digest: one progress row per day summarizing
      overnight sessions (count from logs/budget.md) and remote model
      calls (telemetry kind=model source=remote) — the spend picture
      the operator asked to keep under $10-20/day.
