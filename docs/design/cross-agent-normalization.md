# Cross-agent normalization (card 111A) — lane/FINAL → case-base schema

Relation to situation-scoring.md: that doc defines L2 recognition + L3
scoring over a single agent's stream. Step 6 (book §8, build order) is
the **cross-agent artery**: normalize what tandem seats actually
reported (lanes, worklogs, FINAL-*, benchmark-log) into the situation
case-base so the L2/L3 brain learns from real sessions — not only from
auto-detected windows.

Status: DESIGN (Seu 2026-08-09). Impl (feed path + fixtures) = card
111B, coder lane, after this gate. No code yet.

## 0. Goal

Every time a seat hits a real failure class (loop, false-death report,
model-drift pause, blocked gate, red herring, launch bug) or a human
steers it, that event should land in the case-base as a scored,
attributable, dedup-able record — the same shape the live detectors
write, so one review pass sees both sources.

## 1. Source documents and what maps where

The lane corpus (per seat, under `~/.hngh-night/tandem-<seat>/` and the
breadcrumbs/FINAL files) contains four line kinds; each maps to a
record:

| Source line | Example (lived today) | Maps to |
|---|---|---|
| `STATE:` / worklog bullet | "found multi-seat false-death bug: tmux list-panes returned both panes" | situation detect + action |
| `STEER:` received | "check inbox per phase; verify 104" | human steering signal |
| `FINAL-*.md` closeout | "make test exit 0 with 38/38; make check exit 2 on pre-existing failure" | outcome + attribution |
| `benchmark-log.md` rows | model/cost/outcome rows | score/weight calibration input |
| `model-error` / `model-status` | "negotiated=missing status=paused" | situation = model drift |

## 2. Normalization schema (case-base record)

The feed path SHALL emit records in the existing case shape
(`src/plugins/situation-casebase.lisp` `make-case`), with these field
rules:

| field | meaning | mapping from lane |
|---|---|---|
| `:id` | monotonic, seeded from journal | generated |
| `:ts` | universal-time | line timestamp (DATE at START of the source entry when a per-line ts is absent) |
| `:window` | which seat/session | `tandem-<seat>` lane name, or `owner` for breadcrumbs/plan docs |
| `:situation` | one of the six target situations + open taxonomy | classifier (§3) |
| `:score` | L3 score 0..1 | computed from impact×urgency×spread×confidence, human steer = 1.0 |
| `:action` | log/steer/interrupt/ask/none | recorded action the seat took (or `:human-steer` when a human steered) |
| `:outcome` | none/pending/resolved/failed | derived from the NEXT line (fix landed? FINAL says green?) |
| `:weight` | 1.0 auto; >1 human | human steer/override ⇒ 2.0 (per §7.5 highest-weight ground truth) |
| `:source` | `:auto` or `:human` | `:auto` for lane-detected; `:human` for recorded human steers |
| `:attribution` | "tandem <seat> — <model> via <provider>" | FINAL-* line or lane attribution footer; fallback `hngh/<lisp-version>` |

Extra lane pieces SHALL ride in a `:meta` plist (unknown fields are
ignored by the journal consumer, matching model_catalog's
unknown-fields-ignored stance): `:evidence` (quote the triggering
line), `:file` + `:line`, `:commit` (when a commit is named),
`:preceding` (the previous STATE: line, for recovery-stage checks).

## 3. Situation classification (deterministic first)

Map the text to a situation class with a small keyword set — mirror
Tier-0: no model in the feed hot path for the common classes, fail
closed to `:uncategorized` otherwise.

| keywords (casefold, substring) | situation class |
|---|---|
| "loop", "ping-pong", "identical", "retry", "re-run", "no progress", "stuck", "false-death", "dead pane", "pane is dead" | `loop-or-stuck` (target 1/2) |
| "model drift", "negotiated", "mismatch", "paused", "fallback", "provider" | `model-drift` (target 6-adjacent; novel) |
| "blocked", "gate", "owner-gated", "red herring", "wrong gate", "acceptance" | `policy-or-gate` (target 5 adj.) |
| "steer", "steered", "guidance" | `human-steer` (target n/a — ground truth) |
| "crash", "killed", "died", "hang", "GPU", "system hang" | `infra-failure` (open class) |
| "missing", "no such", "exit 127", "unreadable", "absent" | `env-gap` (open class) |
| "make test", "make check", "fixture", "PASS", "FAIL", "exit 0", "exit 2" | `verification` (target 6-adjacent) |
| otherwise | `:uncategorized` (weight 0.5, still recorded) |

Overrides: a line containing an explicit `:situation` tag wins.

## 4. Triggers — what causes a feed

The feed path runs as a **post-session sweep**, not per-line mid-run
(cheap, batch, no hot-path cost):

1. A seat's `FINAL-*.md` appears (seat closed its shift) → feed its
   whole lane: every `STATE:` line, `STEER:` line, and the FINAL
   outcome.
2. A lane `model-error` file appears or changes → immediately feed one
   `model-drift` record (fail-closed: this is the dashboard's red
   banner signal).
3. `benchmark-log.md` changes → feed rows whose outcome implies a
   situation (cost wall, quota exhausted, garbled output).
4. Human /steer lines land in any inbox → feed as `:human` at end of
   session.

Dedup: `sha256(file + line-number)` stored in `:meta :dedup-key`;
`record-case` skips a key already present in the journal. Re-running
the sweep is idempotent.

## 5. Outcome resolution (next-line lookahead)

A `STATE:` line's `:outcome` is provisional (`:pending`) until the
sweep sees a later line in the same lane that resolves it:

- "fixed", "closed", "green", "exit 0", "PASS" after the same topic ⇒ `:resolved`
- "blocked", "red herring", "dead end", "FAIL", "exit 2" ⇒ `:failed`
- FINAL-* says green but earlier line named a failure ⇒ that failure's
  outcome = `:resolved` (context collapse), the recorded action worked.

## 6. Acceptance (this card)

- Schema doc (this file) approved → gate for 111B.
- 111B: feed path over the REAL tandem-seu/tandem-cibo lanes renders
  expected records (fixtures copy the lane files into a fixture home);
  idempotent on re-run (dedup key); `make test` green.
- One review pass (run-review-pass) can read both auto-detected and
  lane-fed cases with no shape change — verified in the fixture by
  calling situation-distribution after a feed.

## 7. Open questions for owner (not blocking)

- Where the sweep lives: a plugin on FINAL-* appearance, or a cron/manual
  `hngh normalize-lanes` command. Recommendation: both — plugin for
  trigger 2 (model-error is urgent), CLI for the batch sweep.
- Retention: case-base is append-only by design; no purge.

Attribution: tandem seu — deepseek/deepseek-v4-flash-0731, hermes TUI,
2026-08-09. Informed by situation-scoring.md (§7 self-improving loop, §8
step 6) and situation-casebase.lisp make-case field shape.