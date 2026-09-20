# Git history secret scrub + dashboard allowlist (2026-09-20)

Operator-directed security pass, executed 2026-09-20 ~13:20-13:41 UTC by
session_bear. Two related mitigations, both explicitly authorized.

## 1. Dashboard LAN exposure mitigation

- `automation/dashboard-server.py` now enforces a source-IP allowlist
  (`client_allowed`, fail closed): loopback + `DASHBOARD_ALLOWLIST`
  entries; default `127.0.0.1,::1,100.64.0.0/10` (tailnet CGNAT range,
  unreachable off-tailnet). GET and POST both gated; 403 otherwise.
- `DASHBOARD_ALLOWLIST=""` is a deny-all kill switch (even loopback);
  unset env = default list. Unit-tested in
  `automation/tests/test-dashboard-allowlist.py` (10 cases).
- `hngh-dashboard.service` (user unit) restarted on the new code;
  localhost serving verified (HTTP 200).
- Residual for operator: `sudo ufw delete allow from 192.168.0.0/24 to
  any port 8890` (sudo needs a password; app layer already denies LAN).

## 2. OPENCODE_API_KEY git-history scrub

The rotated (dead) OPENCODE_API_KEY value remained in pushed history
(docs/research/2026-09-09/2026-09-10 lobehub files; 51 occurrences, one
distinct value; also generic sk-/ghp_ shapes swept). Operator confirmed
the key was already rotated and authorized immediate history cleanup.

- Executed via git-filter-repo 2.47.0 in a scratch clone with
  replace-text rules (exact value + `sk-`/`ghp_` regex shapes ->
  `git-history-redacted-2026-09-20`).
- Pre-rewrite backup bundle (contains the secret; never push):
  `~/.hngh-automation/store/history-backup/hngh-pre-rewrite-bd5f1d61.bundle`
  (0600, two-home secrets side).
- Force-pushed with lease: origin/main `bd5f1d61 -> b7ee5f1f` (forced).
- Live repo converged via stash -> reset --hard origin/main -> stash
  pop; worker uncommitted state preserved.
- Verification: 0/18,960 rewritten-clone objects and 0 pickaxe hits
  carry the value or ghp_ shape; local omp-undo-redo snapshot refs and
  reflogs (which alone still reached pre-rewrite objects) were deleted
  and `git gc --prune=now` removed all pre-rewrite objects
  (`cat-file bd5f1d61` now fails). raw.githubusercontent serves the
  rewritten main.

## Caveats for other hngh stations

Any other clone still holds pre-rewrite objects locally (harmless:
value is rotated/dead) and will see non-fast-forward on push; session
close does `git pull --rebase`, which replays already-applied patches
as empty and converges. Do not force-push old history back.

GitHub may retain unreachable old objects server-side for a time
(platform gc); moot while the value stays rotated.

## Follow-ups

- hngh-pon (ghp_ liveness probe) and hngh-n28 (OpenRouter key
  archaeology) can close against this scrub if their probes find no
  further live shapes; ghp_ shape count in rewritten history is 0.
- Bead for the ufw rule deletion (operator-sudo lane).
