# Staging notes and roadmap evidence — 2026-09-03

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: the operator's 2026-09-03 direction ("What work can we stage
for today? Are there roadmap items we should note?"), the interim
summary for the window 2026-09-01 → 2026-09-03, and the per-stage
roadmap evidence status requested. All observations checked
2026-09-03 ~13:05Z unless a timestamp is quoted.

## 1. Interim summary 2026-09-01 → 2026-09-03

- **Kernel HEAD unchanged at 37f6ae0, everything pushed.** `git log
  -1` shows `37f6ae0 hngh: candidate f16dde2…` (landed 2026-09-01)
  and `git status` shows no unpushed kernel commits; the working tree
  carries machine-owned dirty paths only (docs/journal/ 09-02 and
  09-03, docs/project/reports.md, ui-grades.md, current-overlay.json,
  queue.md, plan-file ticks, .omp/) plus untracked routed plans and
  research docs — all machine-owned, none ceremony candidates.
- **The continuous cycle executed machine sessions through the
  window.** hngh-automation logs/budget.md records session-run rows
  for `overnight|2026-09-01-operator-items` on 09-02 (00:05, 00:35,
  01:09, 02:06Z) and 09-03 (00:10, 00:33, 01:17, 02:03Z); overnight
  run logs exist per beat (logs/overnight-2026-09-01-operator-items-*.log).
  The alert→plan routing loop routed fresh 2026-09-03 one-steppers
  (plan-accept-gate, repeat-crumbs, tree-skew, ui-audit
  name-completeness, two review P1s) and auto-accepted them
  (reports.md rows fd054e2a / 0f745a8c at 2026-09-03T11:01:24Z) — the
  acceptance machinery landed by the 2026-08-31 fix is working
  end-to-end without a human demanding it.
- **Spend is far under target.** reports.md row e9fdb98b
  (2026-09-03T09:05:46Z): "daily budget digest 2026-09-03: overnight
  sessions=4 (overnight,2026-09-01-operator-items) remote_model_calls=0
  remote_cost_usd=0 [vs operator target $10-20/day]". Two-day spend
  ≈ $0.00/$0.13 per the staging brief's sweep; the daily digests are
  the standing evidence surface.
- **One session stalled and was recovered.** An overnight session
  stalled awaiting operator push confirmation; the recovery and the
  standing-authorization encoding are being landed by the sibling
  automation slice 2026-09-03 (cited by slice name, not by hash — it
  lands in parallel; verify its commit in hngh-automation when
  reading this record later).
- **No email channel yet.** reports.md "Step 3 park (2026-09-02T01:00Z)":
  notify-email SMTP config at ~/.hngh-automation/notify-email.conf not
  found — operator setup item; digest composer verified in report
  mode. Daily digests are composed (logs/email-digest-2026-09-0{1,2,3}.md,
  sent=dormant per row 32e80b2e).
- **Bench finding (verified from the jsonl, correcting the brief).**
  stats/model-bench-2026-09-03.jsonl shows TWO models at 5/5:
  unsloth/Ornith-1.0-35B-GGUF (5/5 on all three days 09-01→09-03) and
  bartowski/Qwen3.8-27B-GGUF (4/5, 5/5, 5/5). The brief's "no local
  model at 5/5" is not what the data says. The delegated-lane
  fallback to paid is a SERVING problem, not a fleet-capability
  problem: 127.0.0.1:8080 was unresponsive at check time (curl code
  000) and Ollama :11434 hosts only Ornith-1.0-9B (5/5 on 09-01 and
  09-02, 3/5 on 09-03 — variance worth a multi-day gate). The
  gemma-4-12B variants scored 4/5 with p1_reader=0 on all three days;
  whether that is judge mis-calibration (strict keyword match on
  `#+`/reader/syntax/malformed/sharp) or genuine misses is staged as
  research step 2 of the 2026-09-03-staging plan.

## 2. Roadmap notes — per-stage evidence status (stages 0–5)

Per the operator's ask; stage states from docs/project/roadmap.md,
evidence as verified today.

- **Stage 0 — kernel & governance: done.** `make test` green at
  HEAD 37f6ae0; every kernel commit is certificate-bound (the
  dogfood loop; HEAD message is a candidate hash); loop-history guard
  silent in recent ceremonies.
- **Stage 1 — self-watch: done.** The self-review, oversight
  alerts, and watchdog demonstrably ran through the window: the
  09-03 routed one-steppers were born from oversight alerts
  (repeat-crumbs, tree-skew, ui-audit, plan-accept-gate) and from
  review P1s — the machine caught its own drifts and routed them.
- **Stage 2 — one interface: landing.** Verified: the dashboard
  answers HTTP 200 on :8890 (checked 2026-09-03 ~13:05Z). Remaining
  unverified exit criteria: every tab renders at desktop AND mobile
  widths; cold deep-links mount; operator items flow
  open→handled→dismissed. Staged for cheap real checks in
  2026-09-03-staging step 3.
- **Stage 3 — roguelike delegation live: landing.** Verified:
  wrapped sessions exist (budget.md session-run rows; overnight run
  logs per beat). Remaining unverified exit criteria: one full
  delegation cycle witnessed live end-to-end (run-start → observatory
  working → run-end disposition), and a seeded stall flagged and
  replaced without human intervention. The 09-02→03 stall recovery by
  sibling automation slice 2026-09-03 is candidate evidence for the
  second criterion but must be verified from logs, not the brief.
- **Stage 4 — system harness D/E: queued.** Exit criteria
  (governed package upgrade through the certificate loop; config
  lanes declaratively listed and backed up on cadence) unmet.
  Partially in place: config-backup runs every 30m (reports.md rows
  6f20e8cb through 09-03T13:00:45Z, ok 9 files); the governed upgrade
  lane is design-staged in 2026-09-03-staging step 6 and parked as
  operator-supervised (kernel-side update lanes are forbidden to
  machine sessions).
- **Stage 5 — research alternation institutionalized: queued, with
  the alternation machinery now live.** Routed plans + machine
  acceptance execute grow↔research alternation without a human
  (six 09-03 routed plans accepted; the 2026-09-03-staging plan
  itself alternates G/R per master-plan §4). The remaining exit
  criterion — a research beat landing a parseable artifact through
  the standard gates without a human demanding it — is being
  exercised by exactly these steps.

## 3. Queue depth

docs/project/queue.md holds 19 rows with status=queued (of 36 total
rows; 12 done). wake-mutation-lane is named Next (rotation-scale,
certificate-ready per the queue Scale section) and is staged as
2026-09-03-staging step 1.

## 4. Operator-action-reduction trajectory

The standing directive (reduce operator actions, simplify UX with
prompts for acceptance) is advancing on two fronts, both landing in
hngh-automation via the sibling automation slice 2026-09-03 (kernel
docs record the trajectory only): (a) an email-setup prompter —
notably, the notify-email SMTP config gap (§1) is exactly the kind of
operator setup item a prompter should surface; (b) an operator-items
section in the daily digest, so pending operator decisions ride the
existing dormant digest channel instead of ad-hoc alerts. No kernel
capability change is admitted by this record.

## 5. Staging outcome

The 2026-09-03 work is staged as
docs/project/plans/2026-09-03-staging.plan.md (7 steps, strict
grow↔research alternation, contract-valid front-matter), grounded in
the sources it cites, non-duplicative of the 2026-09-01-operator-items
plan (all 9 steps still unchecked at authoring time) and of the six
accepted 09-03 routed one-steppers.
