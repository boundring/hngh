# Cistern v6 intake queue — index

Source repo: `/home/bricker/Projects/etc/20260830/cistern` (HEAD d638e3f at
queue time, tree clean, suite canonical 140/140). Contracts live THERE and
stay single-source: `docs/v6/V6-SPEC.md`, `docs/HANDBRIEF-TEMPLATE.md`,
`docs/FAILURE-LEDGER.md`, `docs/PROCESS-RETRO.md`. Procedure:
[cistern-intake/README.md](README.md) in the same directory.

## Packets

| Pkt | Directive | Wave | Status | Commit(s) |
|-----|-----------|------|--------|-----------|
| P01 | V6-01 LAY layout object + camera + click geometry | 1 | LANDED | d059270 |
| P02 | V6-02 Header strip reflow — priority elision | 1 | LANDED | beb3fff |
| P03 | V6-03 Size classes + sector themes + new-game signature | 1 | QUEUED | — |
| P04 | V6-04 Level record + st restructure | 2 | QUEUED | — |
| P05 | V6-05 Overworld gen + tile vocabulary | 2 | QUEUED | — |
| P06 | V6-06 Navigation verbs + cross-level cursor | 2 | QUEUED | — |
| P07 | V6-07 Ambient-lite tick + level-aware spawns | 2 | QUEUED | — |
| P08 | V6-08 Faction homes — warband march, guild settlement | 2 | QUEUED | — |
| P09 | V6-09 Unit browser | 2 | QUEUED | — |
| P10 | V6-10 Feral entities + predator-prey valve | 2 | QUEUED | — |
| P11 | V6-11 Self-balancing sweep | 2 | QUEUED | — |
| P12 | V6-12 Ecology surfaces — copy + inspector | 2 | QUEUED | — |
| P13 | V6-13 Keymap overhaul | 3 | QUEUED | — |
| P14 | V6-14 Remap system | 3 | QUEUED | — |
| P15 | V6-15 Automation engine | 3 | QUEUED | — |
| P16 | V6-16 Meta-automation | 3 | QUEUED | — |
| P17 | V6-17 Rules browser | 3 | QUEUED | — |
| P18 | V6-18 Log channels + routing | 3 | QUEUED | — |
| P19 | V6-19 Summarizer | 3 | QUEUED | — |
| P20 | V6-20 Browser channels | 3 | QUEUED | — |
| P21 | V6-21 Tail tags + banner summary + ELSEWHERE | 3 | QUEUED | — |

Update the status column at every green boundary; the packet file carries
the full outcome. BLOCKED = a gate is unsatisfied or an open recovery block
exists.

## Wave gates (from V6-SPEC §3)

- **Wave 1** (P01–P03): V6-01 → V6-02 strictly sequential; V6-03
  parallel-safe after V6-01 (vast maps need the camera viewable, but gen is
  view-independent). LANDED except P03.
- **Wave 2** (P04–P12): gate — wave 1 COMPLETE (V6-03/P03 landed first).
  Inside wave 2: V6-04 → V6-05 → V6-06 (struct → gen → verbs); V6-07 after
  V6-04 and BEFORE V6-08; V6-08 after V6-05 + V6-06; V6-09 after V6-04;
  ecology V6-10 → V6-11 → V6-12 strictly sequential, V6-10 needs only
  V6-04 and may run parallel to V6-05..V6-09.
- **Wave 3** (P13–P21): gate — wave 2 COMPLETE. Two independent lanes:
  lane A V6-13 → V6-14 → (V6-15 → V6-16 → V6-17); lane B V6-18 first,
  V6-19 after V6-18, V6-20 after V6-18+V6-19, V6-21 after V6-18+V6-19.
  Lanes A and B may run concurrently.

## Halt state at handoff (cistern ledger L-112, verbatim recovery block)

> `docs/FAILURE-LEDGER.md` L-112 is authoritative; quoted here so a Hngh
> cycle never re-discovers it. P03 executes this block.

L-112 (2026-09-08, run: v6-wave-1 — GENTLE HALT for Hngh handoff, mid-wave):

- HALT STATE: V6-01 LANDED (d059270), V6-02 LANDED (beb3fff), V6-03
  NOT STARTED (pending, per clean-boundary rule). Tree clean at
  beb3fff; suite canonical ALL 140 TESTS PASSED; ledger range this
  run L-110..L-112. GREEN-BOUNDARY SYNC done: five src files copied
  to ~/.emacs.d/lisp/ (.elc cleared), no running cistern instance to
  relaunch (pgrep empty).
- RECOVERY for the next implementer (V6-03 first, then wave 2):
  1. V6-03 = size classes + `cistern--sector-themes' + `cistern--new-game
     (&optional seed size theme)' (W2). Red first in tests/test-v6.el
     (pattern: cistern-test-v6--root load block + run.el registration).
  2. BYTE-IDENTITY ANCHORS (captured pre-wave, sha256 of
     prin1-to-string of (map seed rng rpg-pos toilets tanks)):
     seed 42 → c75da91421e5a7545593ecb4501d29661aa84889670ac697b8f39fab18f79798
     seed 1 → 83cc3c517505cea55eb2be5ae2fc9c8b2d6ff7efc2c496248a215acfe22ced55
     seed 20260830 → e01b8ee933dd6adb24e6c2b15558057126d3f802ea8ff30f5b9a504388aa719e
     The theme/size knobs MUST NOT add or remove a sim-LCG draw on the
     standard theme (extras gated on knob > 0, appended after gen-map's
     existing draws).
  3. DOC DRIFT to rule on: WORLD W2.2 says "nil → seed 1" but the code
     default is 20260830 and the binding acceptance is "defaults
     byte-identical — existing tests stay green unchanged". Pinned
     reading: nil seed → 20260830 (code is the pinned reading; fix the
     doc when convenient).
  4. Theme knob plan (L-110/L-111 contiguous): :rubble-mult (collapsed
     ×3), :flood-seeds (wet 2, EXACT count — place via set-cell +
     flood-born so the count is seed-invariant, WO2.2), :cache-bonus
     (wet 1 / gallery 2), :manifold-bonus (gallery 1), :cross-walls
     (collapsed 2 = narrower corridors, gallery 0 = fewer walls),
     :spread-mult (wet = the ONE new domain constant, read at the two
     cistern-spread-pct sites: cistern--accident + phase-hazards). st
     gains a `theme' slot (default standard); V6-04 moves it into the
     level record.
  5. WO2.1 soak: extend cistern-run-soak to (&optional seed size);
     600-tick vast ≤ 4× standard wall time; RECORD the measured timing
     in the ledger (L-099 envelope: no indexes shipped). Owner rule for
     any GUI probe: ONE launch, hard timeout 20, output to a file.
  6. C1'/LAY pointers: cistern-view--layout carries :body-cols; render
     nil-lay default = 200×60 synthetic (batch tests byte-identical);
     cell-at is (st lay line col); driver cistern--current-lay is the
     single derivation (refresh + click + resize callback).
  7. Tooling lessons this run: emacs 31.1 batch cannot `load' relative
     paths (file-missing despite default-directory — use expand-file-
     name); for a paren imbalance, `(car (syntax-ppss (point-max)))'
     gives the net depth instantly and a per-(defun depth walk
     localizes the short defun — the L-017 check-parens class cost
     four debug cycles this run when skipped.
- Next: V6-03 (L-113) → wave 2 order per V6-SPEC §3 (V6-04 → V6-05 →
  V6-06; V6-07 after V6-04; V6-10+ ecology lane parallel after V6-04).

---

## BACKLOG — carried structural findings (post-playtest, NOT v6 build)

These are deliberately excluded from the v6 packet queue. Per the review
authority split (HANDBRIEF-TEMPLATE), structural findings are ledgered,
never fixed in passing; they become packets only after the v6 build
closes and the owner calls for the post-playtest pass. Each is already
recorded with its owning phase in the cistern ledger.

**From L-094 (review-v4) — five v4 items:**

1. Event tiles never resolve to the pinned kind (`cistern--phase-events`
   expires `!` tiles silently to FLOOR; the tile-place effect drops its
   `:arg`). Owner: first narrative-surface pass (V4-22).
2. Story hook tier selection ignores the per-act drift (fixed 60/90
   thresholds vs §7.4 drift; only dialogue implements it). Owner: wave-2
   follow-up (V4-16).
3. Story/dialogue d20 rolls are 0-based against the pinned 1-based formula
   (STORY §6.2) — every margin one lower than the doc reading; fixtures pin
   the current sequences; doc and code must move as ONE decision. Owner:
   wave-2/3 narrative owner (V4-16/V4-21).
4. Dialogue tree-selection draw fires every tick, not once per cooldown
   window (consumes stream 2 with no eligible tree). Owner: wave-3 (V4-21).
5. `cistern--story-tier-face` has no production consumer — wire story line
   faces to `:tier` or retire the mapping. Owner: wave-3 residual
   (V4-21/V4-22).

**From L-094 carried:** L-033#2 multi-char popup glyph renders in one cell
— still carried; owner remains the post-playtest presentation pass.

**From L-108 (review-v5):**

- Item 5 (open): `src/cistern-domain.el` is 3501 lines (sim + combat + RPG
  + social/romance + comedy consts); the combat/social/comedy const blocks
  and the hostiles phase are the natural first split. Splitting is
  structural per the review authority split. (L-108 items 1–4 — comedy
  delivery, log-at-source renderer, social rows 9/11, star-crossed-raid —
  LANDED in L-109; suite 136/136 then.)

**From L-111 (deferred, least-active):**

- The "shortens before vanishing" middle stage for the goals/pressure
  header segment — segments drop whole today; add shortening when a real
  width between full and dropped is reported.

**From L-112 (doc-only, rides P03):** WORLD W2.2 "nil → seed 1" vs code
default 20260830 — P03 fixes the doc in its green commit (pinned reading:
nil → 20260830). Listed here so the doc drift is visible in the backlog
audit too.

Backlog packets, when the owner calls for them, follow the same packet
format (P-B1…, added to this table with a `backlog` wave) and the same
claim procedure.

---

## Reverse pointer

The cistern repo carries `docs/v6/HANDOFF.md`: "v6 queue accepted at
hngh `docs/project/cistern-intake/` — QUEUE.md is the index of record."
That file is the committed anchor back into this directory; keep the two
pointers in sync if either path moves.
