# 2026-09-09 — 1Password service account: hngh headless secret interface

Operator-created 1Password service account (2026-09-09) gives hngh's
unattended sessions a prompt-free, headless path to vault secrets — no
desktop-app dependency, no interactive unlocks.

## Interface contract

- Token env var: `ONEPASSWORD_SERVICE_KEY` (operator-set; value never
  handled by hngh tooling beyond passing it through to `op`).
- Declared in `~/.config/plasma-workspace/env/env_vars.sh` (chmod 600
  this session — it holds the secret), which on Plasma login also runs
  `systemctl --user import-environment ONEPASSWORD_SERVICE_KEY`,
  propagating it to the systemd user manager. All hngh cadence/overnight
  user units therefore inherit it after each login.
- Consumption: scripts need no changes. With
  `OP_SERVICE_ACCOUNT_TOKEN="$ONEPASSWORD_SERVICE_KEY"` in the
  environment, `op` authenticates headless (verified 2026-09-09: scoped
  `vault list` OK through the systemd user manager environment; 5
  vaults — deliberately excludes `Private` and `Shared`).
- Scope is least-privilege by design: the service account cannot read
  `Private`/`Shared`. Secrets hngh must read headless (e.g. the notify
  SMTP credential, currently a literal in the 600-perm notify-email
  conf) should live in a vault within the service account's scope and
  be referenced via `op://` — migration path via
  `automation/scripts/setup-notify-email.sh --from-1password
  "op://<vault>/<item>/<field>"` when the operator stages the item.
- Desktop-app CLI integration (fixed this session: settings flag
  `developers.cliSharedLockState.enabled`, setgid `onepassword-cli`
  group on the op binary — required because the app rejects peers not
  in that group) remains the interactive/operator layer; the service
  account is the automation layer. The two are alternatives, not
  dependencies: with `OP_SERVICE_ACCOUNT_TOKEN` set, `op` ignores the
  desktop app entirely.
- Known quirk: `op whoami` reports "account is not signed in" under
  app integration even when per-command auth works; hngh's
  `setup-notify-email.sh` gate should probe with `op account list` or a
  real `op read`, not `op whoami` (fold into the notify-email slice).
- Fallback for re-acquisition: the token is also stored in 1Password
  itself; if `env_vars.sh` is ever lost, recover it via the
  desktop-app-authenticated CLI.

Related: docs/records/2026-09-09-operator-flexibility-doctrine.md
(§4 operator-load surfaces), automation/scripts/setup-notify-email.sh.
