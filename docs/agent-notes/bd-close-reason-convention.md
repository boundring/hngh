# bd close --reason convention (2026-09-19)

Every `bd close` MUST carry a reason. Bare closes leave no audit trail.

## Form

    bd close <id> --reason "<what-landed>: <commit> — <behavior>; Tests: <evidence>"

- Long reasons (>1 line): `bd close <id> --reason-file -` (heredoc via stdin).
- Multi-close: one `--reason` applies to all IDs, or repeat `--reason`
  once per ID; reasons map positionally (first flag -> first ID).
- Never rely on the no-ID fallback in scripts/agent sessions: it is an
  error there by design (interactive terminals only).

## Content of a good reason

Commit hash + what changed + verification evidence. Two landed precedents:

- `hngh-f7j` (preferred): structured `close_reason` field —
  "STUDIO-AWARE VERDICT landed in 8b8a49e6 ... Tests: 15 wrapper tests
  green ... make test full gate green ... Studio probed live: ...".
- `hngh-wc4` (older pattern): close comment instead of `close_reason` —
  "LOCAL-RESERVE landed (commit 5b58cc4f) ... Tests: ... bash -n clean".
  Prefer `--reason` over a post-hoc comment; the field is queryable
  (`bd list --status closed --json` shows `close_reason`).

## Counter-precedent

- `hngh-4eh`: closed with no `close_reason` and no comments — no audit
  trail of what verified the close. Do not repeat this.
