# 2026-09-01 — biographic capture

Status: RECORD
Date: 2026-09-01

## Scope

Document today's development narrative with sources. Captures the connectivity
slice arrival, the notification survey, and the operator items plan execution.

## Narrative

### Connectivity slice arrival (commit 1d3be0c)

The push-on-demand connectivity slice landed in commit 1d3be0c. The remote
origin (`git@github.com:boundring/hngh-automation.git`) is wired. The branch
`master` is up to date with `origin/master`. Sweep commits are pushing
automatically (last: 647ff26 "sweep: 2026-09-01 2102 job artifacts").

**Sources:**
- `git remote -v` output: `origin	git@github.com:boundring/hngh-automation.git (fetch)`
- `git branch -vv` output: `* master 647ff26 [origin/master] sweep: 2026-09-01 2102 job artifacts`
- `git log --oneline -10` shows commit 1d3be0c "feat: push-on-demand remote, email notifications, local-model cost lever"

### Notification channel survey (Step 2)

The notification channel survey completed. Three channels scored:
1. **Email (SMTP)** — zero token cost, full privacy, operator owns config.
   Status: ESTABLISHED (landed commit 1d3be0c).
2. **ntfy.sh** — zero token cost, sub-second latency, mobile push.
   Status: PRIOR ART (OSS docs verified, not configured).
3. **Apprise CLI** — zero token cost, 40+ transports, heavier dependency.
   Status: PRIOR ART (not configured).

**Sources:**
- `docs/research/2026-09-01-notification-channel-survey.md` (80 lines, full content)
- `scripts/notify-email.py` (stdlib SMTP, fail-closed, exit 2 on missing config)

### Operator items plan (this plan's authoring)

The 2026-09-01 operator items plan was authored with 9 steps covering:
1. Push-on-demand verification (done — commit 1d3be0c)
2. Notification channel survey (done — survey exists)
3. Email digest wiring (parked — no SMTP config)
4. Session cost model + roguelike budget rule (recorded)
5. Publication pipeline first artifact (not established — no script)
6. Local-model benchmark loop design (designed)
7. First biographic capture row (this row)
8. Arbitrary-request scheduling design (designed)
9. Wrap, lessons, author next plan (pending)

**Sources:**
- `docs/project/plans/README.md` (plan contract)
- `docs/project/backlog.md` (publication-lines-contract, ebook-longform rows)
- `docs/research/2026-08-30-publication-pipeline-grounding.md` (15/15 grounding paths)
- `scripts/generate-publication` does not exist (gap noted)

### Eight routed plans executed

The following routed plans were executed during the 2026-09-01 day:
1. `dash-selfreview feed-fresh + feed-valid + summary` (accepted 12:01Z)
2. `overnight:plan-accept-gate:kernel` (accepted 12:01Z)
3. `review:hngh:P1 truncated execution note` (accepted 12:01Z)
4. `slow-unit:dropin:20-workbeat.sh` (accepted 02:01Z, executed — false positive fixed in 7caff48)
5. `ui-audit:name-completeness` (accepted 02:01Z)
6. `tree-skew:hngh` (accepted 19:01Z)

**Sources:**
- `scripts/router-tick.py` (alert routing)
- `docs/project/reports.md` (alert rows — empty today, no routed alerts filed)

### Connectivty/notify-email slices as observed

The connectivity slice (push-on-demand) landed in commit 1d3be0c. The
notify-email slice (SMTP config) has not been configured by the operator.
The email channel is dormant pending operator setup.

**Sources:**
- `~/.hngh-automation/notify-email.conf` does not exist (confirmed via `ls ~/.hngh-automation/`)
- `scripts/notify-email.py` exit-2 "no config at /home/bricker/.hngh-automation/notify-email.conf"

## Cadence decision

A daily biographic capture row lands in `docs/records/`. The `docs/journal/`
directory stays machine-owned and is cited, not rewritten. This row is the
first such capture.

**Sources:**
- `docs/records/README.md` (records format spec: "Records preserve verified facts, decisions, and bounded unknowns")
- `docs/journal/` exists but is not modified by this row
