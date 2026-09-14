# fail-20260910-push-blocked-openrouter-key-hngh

## Question

Why did GitHub push protection keep declining origin/main pushes carrying
the OpenRouter API key in docs/research/2026-09-10-lobehub-api-research.md
(lines 11, 81), and is the block cleared now?

## Evidence read

- Routed plan docs/project/plans/2026-09-10-routed-push-blocked-openrouter-
  key-hngh.plan.md: routed by scripts/router-tick.py at
  2026-09-10T19:00:18Z from alert identity `push-blocked:openrouter-key-
  hngh`; alert text names commits 13007a8 (push-protection decline) and
  857d1de; re-occurred 2026-09-10T20:00:18Z (dedup expired) and
  2026-09-11T06:38Z (candidate f2f04e3 ceremony push still declined, with
  the secret-scanning unblock URL in the plan).
- HEAD content check (2026-09-14T09Z): the redaction commit acd3d9f
  ("security: redact committed API key references from research doc", node
  reachable from origin/main) replaced the OpenRouter key value with a
  redaction marker; 0 raw `sk-or-`/`OPENROUTER_API_KEY=sk` matches in
  HEAD:docs/research/2026-09-10-lobehub-api-research.md. The value moved to
  env_vars.sh / 1Password per the redaction note in the doc itself.
- History reachability (2026-09-14T09Z): the key-carrying commits 13007a8
  and 857d1de are NOT reachable from origin/main; the blocked gate-fix
  commits d78a622 and candidate f2f04e3 are also not reachable — main was
  advanced past them, so the push range no longer carries the flagged
  blobs.
- Push state (2026-09-14T09Z): `git rev-parse origin/main main` both give
  2a2abe0 (origin/main == main), `git log origin/main..main` is empty, and
  `git push origin main` returns "Everything up-to-date". The block is
  cleared without needing this session to allowlist anything.

## Doctrine applied

- Obsolete-state lesson (automation/state/ocgo-agent-lessons.md repeats
  obsolete rows through 2026-09-14): check current ledger/tree state before
  acting — the 09-10 "operator action unchanged" instruction was satisfied
  upstream by redaction plus history advance before this Delve ran.
- Credentials stay operator-owned: this session did not touch any key
  material or provider configuration; it verified state from git history
  and push output only.

## Findings

1. Root cause of the declined pushes: the plaintext OpenRouter key in the
   09-10 lobehub research doc (commits 13007a8, 857d1de) matched GitHub
   secret-scanning; the push range covering those blobs never cleared
   until the key was redacted (acd3d9f) and main advanced past the
   key-carrying commits.
2. Disposition: killed — resolved before research. The alert's underlying
   condition (push declined) no longer reproduces: main == origin/main,
   push green, no raw OpenRouter key in HEAD. Rotation/redaction and the
   repush happened operator-side between 2026-09-11 and 2026-09-14.
3. Residual finding (new, operator-owned): the sibling `OPENCODE_API_KEY`
   value is still plaintext on origin/main in the same research doc
   (grep of HEAD shows the unredacted value verbatim at the lines
   describing the Pi/OpenCode-Go feed). GitHub push protection never
   flagged that pattern; the value has been public since the 09-10 ledger
   sync. Rotation and redaction are operator actions; filed as alert row
   `opencode-key-exposed` on docs/project/reports.md (value redacted from
   the alert text).

## Recommended next line

Operator: rotate the exposed OPENCODE_API_KEY keyed by the new alert row,
then redact its value in docs/research/2026-09-10-lobehub-api-research.md
(same shape as the 2026-09-11 redaction). No further machine work on this
subject.
