<!-- plan: status=executed risk=normal accepted=2026-08-28T18:12:00Z -->
# 2026-08-28 — device pairing formalization

Formalize the Steamdeck pairing process into Hngh's standard route for
connecting any new device: repeatable, documented, and governed.
Autonomy rule (also in the overnight-cycle prompt): hngh docs changes
land via certificate ceremony with a green `make test`; hngh kernel
src/tests/Makefile/hngh.asd changes are FORBIDDEN — park them. Never
touch provider or credential configuration, systemd unit state, tracked
deletions outside the 48h prune, or secrets.

## Steps

- [x] Document the six-step device-pairing route in
      hngh-automation/REMOTE-ACCESS.md (tailscale join → installer →
      Konsole mirror → launchers → key exchange → hngh-doctor).
- [x] Reproducible installer: scripts/deck-setup.sh extended with the
      Konsole theme mirror, four .desktop shortcuts, and the
      hngh-shell/hngh-dashboard helpers (hngh-automation `db2f60c`).
- [x] Font parity: the desktop's full missing font set (1,927 files,
      incl. FantasqueSansMNerdFont and Averia) ported to the deck's
      ~/.local/share/fonts with fc-cache rebuild — terminals render
      identically on both devices.
- [x] Capture the pairing lessons in the ledger: selector stalls on
      large candidate sets need `timeout -k` (SBCL ignores bare
      SIGTERM); profiles without their .colorscheme files fall back to
      white; fd-inherited flock locks survive wrapper kills; alert
      dedup needs escalation caps, not infinite bumps. (Four lesson
      rows filed 2026-08-28T18:35:46Z, ids 0c132557/e322ff4d/
      d460f9a4/b185ea3c.)
- [x] Deck-as-node (federation) parked as the follow-up wave (tracked
      in backlog.md federation rows): flatpak hngh slice per
      subsystem-anatomy senses/limbs rows, talking to brickertop over
      the tailnet.
