# Patrol report sample renders (viz-design synthesis input)

Status: SAMPLES — dramatized renders of real 2026-09-14 patrol findings,
for the viz-design synthesis to consume. Not canonical records.

Register: `docs/design/display-register-spec.md`. Each sample keeps the
two-layer contract: the literal fact renders first and complete; the
perceptual caption is optional decoration (`perceptual:true`), one or two
sentences, sentence case, never changing the fact, never entering a record.
Co-presence rule: any alias renders with its literal term alongside.

Sources sampled: `~/.hngh/archive/digest/PATROL-2026-09-14.md`
(23:20:13Z run), `scripts/report-queue --list` patrol alerts
(2026-09-14 20:20:41Z handoffs, 22:26:10Z gate-cure-refused), and the
`findings_md` two-pass format in `automation/jobs/patrol.py` (Supportive /
Adversarial / The rounds).

---

## Sample 1 — Quiet rounds (all green)

Source shape: a run with zero FAILs (e.g. the morning run before the
handoffs accumulation crossed threshold).

### Literal layer (canonical, always rendered)

```
Patrol 2026-09-14 06:00 UTC, 14 surfaces walked, 14 pass, 0 fail.
Feeds fresh (plans 1343s, operator-items 24s, sessions 23s).
Blocker ledger: 3 active, 3 parked. Gate crumbs green.
Paper edition present. No items need the operator.
```

### Perceptual layer (optional, perceptual:true)

> The rounds came back quiet. Nothing needs the operator this morning.

Dosage rung: 1 (kernel plain terms) + one caption. No alias used.
Grade notes: one caption per snapshot; plays once, never replays while
state is unchanged.

---

## Sample 2 — Handoffs accumulation plus gate red (the 23:20Z shape)

Source shape: real 2026-09-14T23:20:13Z run — 14 passes, 2 standing FAILs:
`handoffs/agent-handoffs.md: bad-execution, 7 dead/cancelled in last 10
rows` and `automation-gate/hngh-automation: gate-red, make test rc=2`.
Alert identities `patrol:handoffs`, `patrol:automation-gate` filed with
24h dedup windows.

### Literal layer (canonical, always rendered)

```
Patrol 2026-09-14 23:20 UTC, 14 pass, 2 fail.
FAIL handoffs/agent-handoffs.md: bad-execution — 7 dead/cancelled
  in last 10 rows (threshold 3).
FAIL automation-gate/hngh-automation: gate-red — make test rc=2.
Rounds: handoffs -> agent-handoffs.md; automation-gate -> gate log.
Top item for operator attention: gate-red (blocks ceremony commits).
```

### Perceptual layer (optional, perceptual:true)

> Two doors stuck on the round. The gate reads red, and seven of the last
> ten handoffs came back dead.

Dosage rung: 1 + one caption. "Doors" and "the round" are plain nouns,
not lexicon aliases; literal terms (`bad-execution`, `gate-red`, counts)
stay alongside in the literal layer. Sentence case; no ALL-CAPS beyond
the recorded `FAIL` token.

Viz note: this is the two-red case — the synthesis should show how two
simultaneous FAILs stack without nag: one caption, then the literal list,
then settle.

---

## Sample 3 — Unknown journal error (the unclaimed-err shape)

Source shape: same run's third FAIL, appeared between runs:
`journal-error/unknown-journal-error: unclaimed-err — 2 err+ lines no
signature claims; latest: Bluetooth: hci0: ACL packet for unknown
connection handle 3837`. Pair auto-queues a research subject on the
second consecutive run per the patrol repeat rule.

### Literal layer (canonical, always rendered)

```
Patrol 2026-09-14 23:20 UTC, journal-errors: FAIL.
unknown-journal-error: unclaimed-err — 2 err+ lines since last run
  match no signature in config/journal-patrol.tsv.
Latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837.
Action: none taken (unknown errors are never silenced). Repeats once
  more and the patrol queues a research subject.
```

### Perceptual layer (optional, perceptual:true)

> Something knocked in the walls twice, and no watch-list name fits it.
> It is logged, not answered.

Dosage rung: 1 + one caption. "Watch-list" is plain speech for the
signature table, not a lexicon alias; the literal term
`unknown-journal-error` and the config path render alongside. The caption
states the policy (logged, not answered) without inventing a cause —
no claim about Bluetooth, no severity inflation.

Viz note: this is the novel-finding case — the synthesis should show how
an unmapped state renders its literal term (per the unmapped-state
fallback grade hook) with a quiet caption that admits ignorance.

---

## Synthesis handoff

- Three shapes covered: quiet, standing red (handoffs + gate), novel
  unknown (journal unclaimed-err). All drawn from real 2026-09-14 data.
- Each sample separates literal and perceptual layers so the viz design
  can render rung 1 alone or rung 1 + caption.
- Open for synthesis: which surface earns the first named-surface alias
  pack (dosage rung 2), and whether any caption copy here deserves to
  persist as a script constant or stay one-off.
