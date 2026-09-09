<!-- plan: status=parked risk=normal accepted=2026-09-03T11:01:24Z routed-from=review:hngh-automation:P1-dashboard-data-json-contain  cause=obsolete disposed=2026-09-09T15:27:53Z reason="premise obsolete post-merge: .gitignore:14 ignores automation/dashboard/ wholesale (data.json untracked machine state); docs/records/2026-09-07-automation-subtree-import.md '222 files, zero machine da"-->
# 2026-09-03 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh-automation:P1-dashboard-data-json-contain`
at 2026-09-03T10:00:45Z. Alert text: review P0/P1 (hngh-automation): P1: `dashboard/data.json` contains a massive inline `digest` string (multiple KB of news summaries) that changes every hour; this bloats the git diff and history significantly. Consider storing digests in separate files or excluding them from version control if they are purely ephemeral state.

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
