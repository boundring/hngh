#!/usr/bin/env bash
# test-bootstrap.sh — bootstrap + env-contract contract, hermetic (sandboxed,
# no network, no real secrets in asserts). Covers peer-review finding 1:
# (a) env.example exists and carries KEY NAMES ONLY — no real secret value
#     from the operator's key files leaks into it;
# (b) config/machine.env.example parses and cadence/day/06-remote-posture.sh
#     resolves DECK_IP from a machine profile selected by env (HNGH_MACHINE_PROFILE),
#     not from the value baked in job code;
# (c) bootstrap --check passes when prerequisites are present (sandbox PATH)
#     and fails cleanly naming a missing one when PATH is stripped.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0
ok() { echo "ok: $*"; }
bad() {
  echo "FAIL: $*"
  fails=$((fails + 1))
}

# --- (a) env contract -------------------------------------------------------
ENV_EXAMPLE="$ROOT/env.example"
if [ -f "$ENV_EXAMPLE" ]; then
  ok "env.example exists"
else
  bad "env.example missing"
fi
# Real secret fixtures: the operator key files test-credentials-style consumers
# actually read (missing files are skipped — hermetic by construction).
leaks=0
for f in "$HOME/.hngh-automation/unsloth.token" "$HOME/.hngh-automation/unsloth.refresh" \
  "$HOME/.hngh-automation/openrouter.token" "$HOME/.hngh-automation/notify-email.conf" \
  "$HOME/.config/hngh/kimi-key"; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    [ -n "$line" ] && [ "${#line}" -ge 8 ] || continue # skip trivial ini keys
    if grep -qF -- "$line" "$ENV_EXAMPLE"; then
      bad "env.example leaks a secret value from $f"
      leaks=$((leaks + 1))
    fi
  done <"$f"
done
[ "$leaks" -eq 0 ] && ok "env.example carries no real secret values"

# --- (b) machine profile ----------------------------------------------------
EX="$ROOT/config/machine.env.example"
if [ -f "$EX" ]; then
  ok "config/machine.env.example exists"
else
  bad "config/machine.env.example missing"
fi
DECK_IP=""
if bash -n "$EX" 2>/dev/null && . "$EX" && [ -n "$DECK_IP" ]; then
  ok "machine.env.example parses and yields DECK_IP"
else
  bad "machine.env.example does not parse/yield DECK_IP"
fi
if git -C "$REPO" check-ignore -q automation/config/machine.env; then
  ok "config/machine.env is gitignored"
else
  bad "config/machine.env is NOT gitignored (host data would be committed)"
fi

# profile override path: the job must resolve DECK_IP from the profile set
# via env (HNGH_MACHINE_PROFILE), never by editing the script's default.
printf '%s\n' 'DECK_IP="203.0.113.7"' >"$SANDBOX/machine.env"
mkdir -p "$SANDBOX/bin"
cat >"$SANDBOX/bin/tailscale" <<'STUB'
#!/usr/bin/env bash
# test stub: log the ping target, answer pong (06-remote-posture greps 'pong from')
printf '%s\n' "$*" >> "${TS_LOG:?}"
echo "pong from ${4:-unknown}"
STUB
chmod +x "$SANDBOX/bin/tailscale"
TS_LOG="$SANDBOX/ts-hits"
: >"$TS_LOG"
SANDBOX_STATE="$SANDBOX/STATE.md"
env TS_LOG="$TS_LOG" STATE_FILE="$SANDBOX_STATE" DECK_IP= \
  PATH="$SANDBOX/bin:$PATH" HNGH_MACHINE_PROFILE="$SANDBOX/machine.env" \
  bash "$ROOT/cadence/day/06-remote-posture.sh" >/dev/null 2>&1
if grep -qF '203.0.113.7' "$TS_LOG" && grep -q 'remote-posture | ok' "$SANDBOX_STATE" 2>/dev/null; then
  ok "06-remote-posture resolves DECK_IP from the sandboxed machine profile"
else
  bad "06-remote-posture did not resolve DECK_IP from HNGH_MACHINE_PROFILE"
fi

# fail-closed: no profile, no env DECK_IP -> skip probe, never the baked IP.
: >"$TS_LOG"
rm -f "$SANDBOX_STATE"
env -u DECK_IP TS_LOG="$TS_LOG" STATE_FILE="$SANDBOX_STATE" \
  PATH="$SANDBOX/bin:$PATH" \
  HNGH_MACHINE_PROFILE="$SANDBOX/missing.env" \
  bash "$ROOT/cadence/day/06-remote-posture.sh" >/dev/null 2>&1
if [ -s "$TS_LOG" ]; then
  bad "06-remote-posture pinged with no machine profile (stub log nonempty)"
elif grep -q 'no DECK_IP' "$SANDBOX_STATE" 2>/dev/null; then
  ok "06-remote-posture skips fail-closed when no profile sets DECK_IP"
else
  bad "06-remote-posture missing-profile path did not crumb 'no DECK_IP'"
fi

# --- (c) bootstrap --check --------------------------------------------------
# stripped PATH: every prereq missing -> exit 1, names them (flock shown).
out="$(env -i HOME="$HOME" PATH=/nonexistent /bin/bash "$ROOT/bootstrap.sh" --check 2>&1)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'flock'; then
  ok "bootstrap --check fails cleanly on stripped PATH (names missing tools)"
else
  bad "bootstrap --check stripped-PATH behavior (rc=$rc)"
fi
# sandbox PATH holding every prerequisite -> exit 0.
mkdir -p "$SANDBOX/all"
have_all=1
for t in python3 git curl jq flock sqlite3 sbcl; do
  if p="$(command -v "$t")"; then ln -sf "$p" "$SANDBOX/all/$t"; else have_all=0; fi
done
if [ "$have_all" -eq 1 ]; then
  if env -i HOME="$HOME" PATH="$SANDBOX/all" /bin/bash "$ROOT/bootstrap.sh" --check >/dev/null 2>&1; then
    ok "bootstrap --check passes when all prerequisites are present"
  else
    bad "bootstrap --check should pass with a complete sandbox PATH"
  fi
else
  echo "skip: bootstrap pass-case (host lacks a prerequisite binary)"
fi

# --- summary ----------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "test-bootstrap: PASS"
else
  echo "test-bootstrap: $fails failure(s)"
  exit 1
fi
