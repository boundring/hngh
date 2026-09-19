# Secret hygiene: OpenCode key verdict, doc-secrets gate hardening, op-whoami deprecation — 2026-09-19

Bead: hngh-dzf (P0). Three parts, all verified live.

## 1. The committed OPENCODE_API_KEY is dead (rotated)

`docs/research/2026-09-10-lobehub-api-research.md` lines 11 and 80 carried
the full `sk-7ZXC…` OPENCODE_API_KEY value in plaintext (committed in the
48e26071-era machine ledger sync; GitHub push-protection never saw it
because it is not an sk-or- shape).

Liveness verdict, probed against the real endpoint
(`opencode.ai/zen/go/v1/chat/completions`, values never printed):

- garbage key / no auth -> 401 (auth checked first);
- doc key, no session header -> 400 `MissingSessionID` (edge auth passed),
  with `x-opencode-session` header -> **401 `Invalid credential` from the
  upstream = the doc key is DEAD**;
- current `env_vars.sh` OPENCODE_API_KEY (different value, sha differs) ->
  **429 `GoUsageLimitError` (weekly) = the current key is LIVE** (auth
  valid, weekly quota exhausted at probe time).

No rotation action needed; the leaked value is already rejected upstream.
Both doc lines redacted in place to the `<redacted 2026-09-19; …>` form.

**Extra catch while triaging the hardened gate:**
`docs/project/secret-scan-report.md:61` quoted a raw `ghp_…` 40-char
high-entropy token (a fixture quote from the retired system;
`tests/unit/test-sentry.lisp` does not exist in this repo). The row's own
prose claimed "value is a placeholder token" — it is not; it is a
credential-shaped string. Redacted in place. Liveness not probed (retired
system, out of hngh scope); treat as dead-until-proven, flagged for the
operator if the retired system ever had a live GitHub connection.

## 2. The doc-secrets gate was blind to docs/ — fixed

`automation/tests/test-doc-secrets.py` had two coverage holes:

1. **ROOT bug (the big one):** `ROOT = Path(__file__).resolve()
   .parent.parent` resolved to `automation/`, not the repo root, so
   `git ls-files` listed only `automation/` files. `docs/` — the tree
   that actually leaked in 2026-09-11 — was never scanned. Now
   `parent.parent.parent` (repo root).
2. **ALLOW_RE blanket line-skip:** a raw key sharing a line with a
   `<redacted` note (exactly the doc's line 11) was skipped wholesale.
   `scan_text` now masks sanctioned placeholders out of the line and
   scans the residual, so shared-line keys are caught while true
   placeholder forms stay allowed.

Regex hardening: generic `sk-[A-Za-z0-9]{16,}` added (catches OpenCode-
style keys; short prose like `sk-learn` stays clean); explicit prefixes
(`sk-or-v1-`, `sk-ant-`, `xox[bap]-`) now require a value suffix so prose
that merely enumerates prefix names does not false-positive. Dead
duplicate `continue` lines removed. Tests red-first: shared-line catch,
generic sk- catch, bare-prefix allowance, short-sk allowance (8 tests
total, all green; full gate run fails-then-passes across the redaction
slice).

## 3. `op whoami` prescriptions replaced with the service-account seam

Per docs/records/2026-09-09-1password-service-account-interface.md,
`op whoami` misreports "account is not signed in" under desktop-app
integration even with a valid `OP_SERVICE_ACCOUNT_TOKEN`. Updated the
stale prescriptions:

- `docs/design/credentials-posture.md` §2 (session auth check) and §5
  (execution-time live check): `op account list`, never `op whoami`;
  §5 also names the headless service-account token path.
- `docs/design/keyring.md` §1 (integration prerequisite): same
  replacement, with the misreport rationale and record cross-link.

## Verification

- 8/8 gate tests green; probe calibration (401/400/429 matrix) printed
  HTTP codes only; key values hashed, never echoed.
- Redactions verified: `grep -rl sk-7ZXC docs/` -> none; gate repo scan
  passes over the full tracked tree.
