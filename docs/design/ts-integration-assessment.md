# Typesafe integration assessment (hngh-ypb synthesis)

Status: ASSESSMENT - synthesis of banked artifacts only, no new analysis.
Absorb entry: `docs/project/decisions.md` 2026-09-18 (hngh-4m1 absorb-and-record;
tracked remainder exactly this bead). Propagation record:
`docs/records/2026-09-18-beads-jev-propagation.md` (`801a2e3c`).

## 1. typesafe.py wrapper (`10cccb2d`)

Thin Jev/Typesafe inference wrapper (`automation/lib/typesafe.py:1-107`):
`ask_noul` (`typesafe.py:40-56`) and `ask_choice` (`typesafe.py:59-81`)
go through `TypeSafeClient.system_one` with Noul/Choice/Score calls at
~0.6s each (`typesafe.py:4`), never agent-grade inference. Fail-closed:
without `TYPESAFE_API_KEY` every helper returns None and the caller falls
back (`typesafe.py:41-45`, `typesafe.py:60-64`); values are never logged,
one breadcrumb per UTC day max on fallback (`typesafe.py:7`, `typesafe.py:27-37`).

SDK spike numbers (banked, propagation record): tested live at noul 0.92
in ~1s; fail-closed path returns None without key. Without the SDK
installed and no live key, the deterministic rule applies (absorb-and-record
rather than keep-open) per the decisions.md 2026-09-18 entry.

## 2. Beat-skip gate (`d740d967`)

Jev beat-skip gate in `model_call` (`automation/lib/model.sh:937-966`):
before touching local Unsloth, `beat_skip_gate` (`typesafe.py:84-97`,
threshold `v >= 0.5` at `typesafe.py:97`) asks whether the operator is
actively using the machine. `SKIP_LOCAL=1` bypasses both Unsloth sites
(primary at `model.sh:967` and the ranked-fallback loop at `model.sh:974-984`).
Verdict cached 30s in `$AUTOMATION_ROOT/tmp-beatskip.txt`
(`model.sh:945-966`; safe 2/min lane: at most ~2 inference calls per minute
even under beat bursts, `model.sh:941-942`). Fail-open: without key or on
any error the existing quiet guards decide, never this gate (`model.sh:942`).

## 3. vip-gate (`f1a43f9f`)

Midnight gate + defer guard for heavy Unsloth runs
(`automation/lib/vip-gate.sh:1-67`): midnight window 00:00-05:00 local
(`vip-gate.sh:24-25`) first, then the beat-skip verdict file consumer
(`vip-gate.sh:53-67`; missing/unreadable file is fail-open). Wired into
`automation/jobs/model-bench.sh:13-17` and
`automation/jobs/night-research.sh:11-15` as fail-closed exit 0 with a
`vip-defer` breadcrumb. Verified: bash -n clean on all three scripts;
dry-run matrix (daytime defer, in-window keep proceed, in-window skip defer,
job-level exit 0 with breadcrumb).

## 4. Decision map (banked per-bead questions)

From the propagation record: `hngh-4m1` absorb = Choice (asked, fail-closed,
deterministic rule applied); `hngh-vip` Unsloth = Noul beat-skip (wired);
`hngh-4j4` reviewer gates = Score per gap (pending, not this bead).

## 5. Safe / burst lanes

The beat-skip gate runs on the safe 2/min lane (`model.sh:941`): the 30s
verdict cache bounds Typesafe inference to ~2 calls/minute even under beat
bursts. Heavy Unsloth work (fleet bench, night research) is the burst lane:
full-model inference gated to the overnight window by vip-gate, and further
deferred while the safe-lane verdict says the operator is active. Direction
is inward: bursts never preempt sessions; guards fail toward existing paths.

## Remainder

None banked beyond this doc. `hngh-4j4` Score gates and any new Typesafe
questions are separate beads, not remainder of this synthesis.
