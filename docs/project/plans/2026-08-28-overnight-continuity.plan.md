<!-- plan: status=accepted risk=normal accepted=2026-08-28T03:20:00Z -->
# 2026-08-28 — overnight continuity

Continuous operation wave: overnight work loop, budgeted remote GLM
leg, research-line lifecycle, Winamp skin v2, plan lifecycle (this
file), Clean-Architecture subsystem anatomy. Full spec authored in the
operator session; this ledger copy is the execution record.

## Steps

- [x] Remote GLM leg: config keys, remote_chat, model_call insert (AUTO `362a10a`)
- [x] Verify dormant remote path (breadcrumb + unsloth fallback)
- [x] research-lines.tsv seed + beat lifecycle rewrite + feed lines array
- [x] Verify: three research beats advance a line through crystallization (gantt-legibility planned→expanding 03:12Z, expanding→contracting 03:31Z, contracting→crystallized 03:35Z; five lines crystallized into docs/research/)
- [x] overnight-cycle.sh + hngh-overnight.timer/service + Makefile wiring
- [x] Verify: manual overnight beat (overnight-lead handoffs ×3, telemetry rows ×3, live flock-skip rc=0 08:38Z)
- [x] Winamp skin v2: classic tokens, radius/margin sweep, bevels, LCD insets, shade opt-in
- [x] Verify: ui-audit 0 violations + screenshot reads as classic skin (fresh run 0 violations 08:55Z; screenshot passes all five classic cues — bevels, LCD insets, square corners, playlist stripes, charcoal+green)
- [x] plans/README contract + this self-hosted ledger entry + plan-feed.py + 30m mount
- [x] HNGH ceremony: subsystem-anatomy doc + advancement-record framing correction + CHANGELOG + push (candidate `5fe88ae0`, commit `16f6344`, ceremony-driven 2026-08-28; whitespace normalization of the four research docs was the only gate refusal on the way)
