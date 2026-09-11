# 2026-09-11 — Secret scrub (push-protection cure)

## What happened
GitHub push protection (GH013) blocked `git push origin main` because
OpenRouter/OpenCode-shaped API keys were committed to
`docs/research/2026-09-10-lobehub-api-research.md` (commits 13007a85,
857d1dee — both inside the unpushed range). The keys were never public:
the remote rejected the push before anything landed.

## What was done
- Redacted at HEAD (commit fd5ad3a / rewritten acd3d9f): raw key tokens
  replaced with `OPENROUTER_API_KEY=<redacted 2026-09-11; value lives in
  env_vars.sh / 1Password>`. The `$$CREDENTIAL_...$$` placeholder form was
  already sanctioned and kept.
- Rewrote the entire unpushed range with `git filter-branch --tree-filter`
  (git-filter-repo unavailable), replacing every raw key value with
  REDACTED. Post-rewrite verification: zero key-shaped strings in
  `git log origin/main..HEAD -p`; all 80 commit subjects byte-identical
  pre/post; working tree of foreign files untouched.
- Pushed cleanly with NO force: `9100b4a..569f879`, 0 ahead after push.
- New standing gate: `automation/tests/test-doc-secrets.py` (wired into
  `make test`) — scans every git-tracked file for known key prefixes
  (sk-or-v1-, sk-ant-, AKIA, ghp_, xox) plus credential-assignment-shaped
  long tokens, allowing sanctioned placeholders. This complements the
  2026-08-08 credential-redaction audit.

## Rotation note (operator action, not done by automation)
The committed keys were exposed only to local disk and a blocked push —
never fetched by anyone. Rotation is still recommended at operator
convenience via 1Password: rotate the OpenRouter key and the OpenCode
key, then update `env_vars.sh` (values live there / in 1Password, never
in git).