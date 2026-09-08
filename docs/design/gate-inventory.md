# Gate inventory -- the antagonistic review of our own gating

2026-09-06. Every gate the machine faces, one verdict each. The operator
directive: improve as fast as it safely can, interrupted only by real
events. A gate is JUSTIFIED when authority, credentials, money, or
kernel law demands it; UNNECESSARY when the machine could safely
self-serve.

| Gate | Site | Verdict | Rationale / recommendation |
|---|---|---|---|
| Critical-class plans park for operator | automation/scripts/accept-plans.py:257 | JUSTIFIED | Authority by design: systemd, credentials, provider config, non-prune deletions are the operator's alone. |
| Keyword park (provider/credential/token/systemd/security/secret/delet) | automation/scripts/overnight-cycle.sh:128 | JUSTIFIED | Same authority classes, enforced at the dispatch layer too. |
| design-hold: plan held until its referenced design exists | automation/scripts/accept-plans.py:274 | JUSTIFIED | Machine self-serves: the hold auto-demands the design via the research beat and re-proposes when it lands (accept-plans.py:252). No human in the loop. |
| missing-authority causes park, never retry | automation/lib/causes.sh:36 | JUSTIFIED | Retrying a permission denial is a loop; the supervision rubric already treats repeats as a loop. |
| IMMEDIATE alert class (credential/ceremony failures) | automation/scripts/notify-email.py:162, automation/jobs/credential-health.sh | JUSTIFIED | Credential and ceremony failures are the one class where digest latency costs real money or security. |
| system units never touched | automation/scripts/service-ctl.sh:17 | GRANTED (operator 2026-09-07) — with discipline | Standing grant recorded in decisions.md 2026-09-07: service-ctl stays the single path, every action remains a recorded disposition with cause and evidence, and a failure is an alert, never a retry-in-the-dark. |
| Overnight spend cap (MAX_SESSIONS_DAY=4) | automation/scripts/overnight-cycle.sh:45 | JUSTIFIED | Money. Note: on 2026-09-06 the cap hit while all plans sat gate-blocked, so paid capacity went unused; consider refunding a blocked-day's budget only after the gate fix proves out. |
| Agent-stall supervision (STALLED, never terminal) | automation/jobs/agent-supervision.py:146 | JUSTIFIED | Detection, not a gate. The 2026-09-01 standing-auth grant already removed the push-confirmation stall class that fed it. |
| Loop-history guard (code-surface commits must ride the loop) | hngh tests/scripts/test-loop-history-guard.py | JUSTIFIED | This is the ceremony law itself. Cost is real: 526cd3f (a bypass commit) held the whole machine red 2026-09-06; cured same-day by declare + re-land. Cheaper than the alternative (silent law erosion). |
| schedule-heartbeat clean-tree precondition | hngh scripts/schedule-heartbeat.py worktree_clean() | JUSTIFIED gate, missing consumer (fixed 2026-09-06) | The gate is right for a mutation lane; but nothing committed the machine's own doc ledgers after 2026-08-31, so the tick postponed forever. Fixed: hourly kernel-ledger-sync (automation cadence/hour/30). |
| No action card = no action | hngh docs/project/heartbeat/README.md | PARTLY UNNECESSARY | The card is the operator's "lane ready" statement; for a 12-day window nobody mounted one and the lane idled. Recommendation: the cadence may mount read-only `.worker` recon cards itself; `.rotation` (mutating) cards stay operator-mounted. |
| run-worker refuses no-worker-transport | hngh src/main.lisp:1723 | UNNECESSARY in effect | Rung-18 first slice ships the transport injection point but no CLI wiring, so the mounted recon lane refuses every run (proven live 2026-09-06). Fix: an operator-file worker transport in the kernel CLI, mirroring review's `reviewer=` file path. Kernel work; ready to dispatch. |
| Rotation runner "operator-owned" scheduling note | hngh docs/project/queue.md scheduling section | OBSOLETE | The note predates the cadence tiers. schedule-heartbeat is now mounted (automation cadence/hour/31); queue.md should say the cadence owns the clock. |
| Wake-mutation-lane slice unimplemented | hngh docs/project/backlog.md (certificate-bound wake lane) | READY TO DISPATCH | The top queued rotation item is a full multi-slice kernel change (:wake-mutation action). Gate green, transport gap identified, recon scoped. Needs an overnight lead; not launched by this audit. |

## What the audit changed today

- Kernel gate back green (526cd3f declared + re-landed through the loop).
- First live heartbeat (#1) recorded and committed; the rotation clock
  is mounted and will fire every ~3h.
- Write-only artifacts wired or closed: BENCH digest, email-qa trend,
  RESEARCH-REVIEW disposition files.
