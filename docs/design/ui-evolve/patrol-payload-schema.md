# Patrol payload JSON schema (viz-design synthesis input)

Status: DRAFT -- a derived schema, not yet an emitted contract. Every field
below is derivable 1:1 from what `jobs/patrol.py` already writes today
(stdout machine contract, findings doc, report-queue alerts). Nothing
emits this JSON yet; the section exists so the viz synthesis can consume
one stable shape instead of parsing three text formats. If the viz lands,
the emitter goes into `patrol.py` behind the `hngh.patrol.v1` tag and this
doc becomes its spec.

Register: `docs/design/display-register-spec.md` -- the literal layer of
this payload is the canonical record side of that contract; a caption is
never part of the payload. Companion to `patrol-report-samples.md`
(human-render shapes); the worked example below is the same 2026-09-14
23:20Z run that Samples 2+3 dramatize.

Sources (evidence):

| Source | What it pins | Ref |
| --- | --- | --- |
| `automation/jobs/patrol.py:1151-1162` | route row shape (`load_routes`) | R |
| `automation/jobs/patrol.py:1372-1384` | per-check result envelope, check-crash fail-open | R |
| `automation/jobs/patrol.py:1404-1409` | stdout `PASS`/`FAIL` machine contract | R |
| `automation/jobs/patrol.py:1259-1286` | findings doc two-pass section (`findings_md`) | R |
| `automation/jobs/patrol.py:1321-1341` | alert row text, identity, window, evidence | R |
| `automation/jobs/patrol.py:1445-1510` | morning rounds aggregation (`morning_report`) | R |
| `automation/config/patrol-routes.tsv:12-17` | route columns (patrol-id, surface, check, freq-tier, finding-class) | R |
| `automation/jobs/dashboard-self-review.py:97-134` | feed-validity findings vocabulary (`check_feed_valid`) | C |
| `automation/jobs/dashboard-self-review.py:72-77` | two-tier finding status vocabulary | C |
| `docs/project/reports.md:1-7` | ledger row format `| timestamp | kind | id | first line | body |` | L |

R = patrol runtime, C = companion self-review (sibling feed watcher), L = ledger row format.

---

## 1. Top-level object: `hngh.patrol.v1`

```json
{
  "schema": "hngh.patrol.v1",
  "run_ts": "2026-09-14T23:20:13Z",
  "date": "2026-09-14",
  "tier": null,
  "patrol_count": 17,
  "pass_count": 14,
  "fail_count": 3,
  "quip_present": true,
  "results": [
    { "id": "handoffs", "surface": "handoffs-accumulation", "check": "handoff-deaths", "tier": "30m", "finding_class": "bad-execution", "passes": [], "fails": [ { "artifact": "agent-handoffs.md", "cause": "bad-execution", "detail": "..." } ] }
  ],
  "rounds": [
    { "id": "handoffs", "surface": "handoffs-accumulation", "artifact": "agent-handoffs.md", "cause": "bad-execution" }
  ],
  "queued_subjects": [],
  "alerts": [
    { "identity": "patrol:handoffs", "window": 86400, "text": "...", "evidence": "..." }
  ]
}
```

Field rules (all derived from real emitter behavior):

- `run_ts` -- UTC `%Y-%m-%dT%H:%M:%SZ`, identical to the `## <ts> run`
  findings-doc header and the alert timestamps of the same run (patrol.py:1261).
- `tier` -- `"30m"`, `"day"`, or `null` (a `--patrol ID` single walk).
  Mirrors the `--tier` choices at patrol.py:1391.
- `patrol_count` -- `len(results)`: surfaces walked, i.e. matching
  patrol-routes rows (patrol.py:1367-1384).
- `pass_count` / `fail_count` -- sums over `results[].passes` / `results[].fails`.
  Invariant: `pass_count + fail_count >= patrol_count` (a route can emit
  several of each; e.g. feed-freshness emits one pass per feed file, patrol.py:153-165).
- `quip_present` -- boolean only. The quip line is a perceptual-layer
  decoration (`_..._`, patrol.py:1263-1265) and never carries facts, so
  the payload records presence, not content (register: perceptual text
  never enters a record).
- `rounds` -- present only when at least one FAIL exists (patrol.py:1280-1285).
- `queued_subjects` / `alerts` -- empty arrays on an all-green run.

## 2. `check-result` -- one walked route

```json
{
  "id": "handoffs",
  "surface": "handoffs-accumulation",
  "check": "handoff-deaths",
  "tier": "30m",
  "finding_class": "bad-execution",
  "passes": [ { "name": "feed-freshness:plans.json", "detail": "age=1343s" } ],
  "fails": [ { "artifact": "agent-handoffs.md", "cause": "bad-execution", "detail": "7 dead/cancelled in last 10 rows" } ]
}
```

- `id`/`surface`/`check`/`tier`/`finding_class` -- the patrol-routes.tsv
  row verbatim (load_routes, patrol.py:1160-1161). `tier` is the row's
  `freq-tier` (`30m`|`day`); `finding_class` is the row's bestiary class
  (all current rows are `bad-execution`; the field stays because the
  column, not the check, owns the classification).
- `id` is also the report-queue identity suffix: alert identity is
  `patrol:<id>` (patrol.py:1435-1436).
- Failure modes preserved as data:
  - unknown route check -> one fail with `cause: "unknown-check"`,
    `artifact = surface` (patrol.py:1376-1378);
  - check crash -> fail-open: `passes: []`, one fail with
    `cause: "check-crash"`, remaining routes still walked (patrol.py:1381-1383);
  - runner crash -> no `hngh.patrol.v1` object at all; exactly one
    `patrol:runner` alert, exit 0 (patrol.py:1518-1524). A missing run in
    the feed is a gap signal, not a zero-finding signal.

## 3. `pass-item` and `fail-item`

```json
{ "name": "feed-freshness:plans.json", "detail": "age=1343s" }
```

```json
{
  "artifact": "agent-handoffs.md",
  "cause": "bad-execution",
  "detail": "7 dead/cancelled in last 10 rows (threshold 3)"
}
```

- `pass-item.name` -- the `PASS <patrol>/<name>` stdout token
  (patrol.py:1406-1407); `<name>` may itself be `check:surface`
  qualified (e.g. `feed-freshness:sessions.json`,
  `systemd-units:hngh-automation.timer`).
- `fail-item.artifact` -- the thing the FAIL names; per check it is a
  file (`agent-handoffs.md`, `STATE.md`, `logs/budget.md`), a ledger row
  id (`blocker-escalated` rows, stalled research lines), a unit name, a
  service name, or a synthesized label (`overnight`, `kernel`, `github-actions-latest`).
  Renderers must not assume a path.
- `fail-item.cause` -- open enum; the cause vocabulary observed in
  patrol.py today (patrol.py:148-1123):
  `feed-missing, feed-stale, blocker-escalated, ledger-unreadable,
  bad-execution, gate-stale, gate-red, gate-cure-refused, digest-missing,
  digest-empty, deck-a-empty, service-down, disk-full, stalled-line,
  budget, check-crash, unknown-check, processed-missing, feedback-flood,
  manga-stale, components-pending, send-failed, ghost-row,
  transient-left-running, adopted-no-followon, timer-dead,
  transient-escalation, unit-not-practiced, restart-guard, restart-failed,
  propose, alert, unclaimed-err, config-bug, journal-unreadable`.
  Unknown causes are data, not schema errors -- the journal rounds file
  new causes by design (unclaimed errors must stay visible,
  patrol.py:1042-1049).
- `detail` -- the human-readable remainder, always rendered with the
  literal tokens; truncation at the emitter (e.g. `latest` clipped to
  100-120 chars in journal/email checks) is already applied upstream and
  is not a renderer concern.

## 4. `round-item` and `alert-ref`

```json
{ "id": "handoffs", "surface": "agent-handoffs.md", "artifact": "agent-handoffs.md", "cause": "bad-execution" }
```

- `round-item` -- one per FAIL, the morning-checklist row (`ROUNDS`
  lines, patrol.py:1283-1285); `surface` here is the route surface the
  operator should look at, `artifact` the concrete named thing.
- `alert-ref`:

```json
{
  "identity": "patrol:handoffs",
  "window": 86400,
  "text": "patrol handoffs: bad-execution on agent-handoffs.md -- 7 dead/cancelled in last 10 rows",
  "evidence": "7 dead/cancelled in last 10 rows"
}
```

- One alert per FAIL, filed with `--window 86400` and `--evidence
  <detail>` so dedup re-fires only when the condition recurred
  (patrol.py:1321-1341, 1432-1436). These rows appear in the shared
  report ledger as `| <run_ts> | alert | <8-hex id> | <text> |
  <run_ts>-alert-<id>.md |` -- the ledger row format of
  `docs/project/reports.md:1,7` -- and remain the cross-run memory; the
  JSON payload is per-run and carries no history.

## 5. Worked example -- the 2026-09-14 23:20Z run

Same run as `patrol-report-samples.md` Samples 2+3 (Sample 2 = fails
1-2, Sample 3 = fail 3; the samples split one run into two render
studies). Counts dramatized as in the samples: abbreviated to the
distinguishing rows.

```json
{
  "schema": "hngh.patrol.v1",
  "run_ts": "2026-09-14T23:20:13Z",
  "date": "2026-09-14",
  "tier": "30m",
  "patrol_count": 14,
  "pass_count": 14,
  "fail_count": 3,
  "quip_present": true,
  "results": [
    {
      "id": "feeds",
      "surface": "dashboard-feeds",
      "check": "feed-freshness",
      "tier": "30m",
      "finding_class": "bad-execution",
      "passes": [
        { "name": "feed-freshness:plans.json", "detail": "age=1343s" },
        { "name": "feed-freshness:operator-items.json", "detail": "age=24s" },
        { "name": "feed-freshness:sessions.json", "detail": "age=23s" }
      ],
      "fails": []
    },
    {
      "id": "handoffs",
      "surface": "handoffs-accumulation",
      "check": "handoff-deaths",
      "tier": "30m",
      "finding_class": "bad-execution",
      "passes": [],
      "fails": [
        {
          "artifact": "agent-handoffs.md",
          "cause": "bad-execution",
          "detail": "7 dead/cancelled in last 10 rows"
        }
      ]
    },
    {
      "id": "automation-gate",
      "surface": "automation-gate",
      "check": "gate-crumbs",
      "tier": "30m",
      "finding_class": "bad-execution",
      "passes": [],
      "fails": [
        {
          "artifact": "hngh-automation",
          "cause": "gate-red",
          "detail": "make test rc=2"
        }
      ]
    },
    {
      "id": "journal-error",
      "surface": "user+kernel-journal",
      "check": "journal-errors",
      "tier": "30m",
      "finding_class": "bad-execution",
      "passes": [],
      "fails": [
        {
          "artifact": "unknown-journal-error",
          "cause": "unclaimed-err",
          "detail": "2 err+ line(s) no signature claims; latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837"
        }
      ]
    }
  ],
  "rounds": [
    { "id": "handoffs", "surface": "handoffs-accumulation", "artifact": "agent-handoffs.md", "cause": "bad-execution" },
    { "id": "automation-gate", "surface": "automation-gate", "artifact": "hngh-automation", "cause": "gate-red" },
    { "id": "journal-error", "surface": "user+kernel-journal", "artifact": "unknown-journal-error", "cause": "unclaimed-err" }
  ],
  "queued_subjects": [],
  "alerts": [
    {
      "identity": "patrol:handoffs",
      "window": 86400,
      "text": "patrol handoffs: bad-execution on agent-handoffs.md -- 7 dead/cancelled in last 10 rows",
      "evidence": "7 dead/cancelled in last 10 rows"
    },
    {
      "identity": "patrol:automation-gate",
      "window": 86400,
      "text": "patrol automation-gate: gate-red on hngh-automation -- make test rc=2",
      "evidence": "make test rc=2"
    },
    {
      "identity": "patrol:journal-error",
      "window": 86400,
      "text": "patrol journal-error: unclaimed-err on unknown-journal-error -- 2 err+ line(s) no signature claims; latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837",
      "evidence": "2 err+ line(s) no signature claims; latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837"
    }
  ]
}
```

Rendering contract over this payload (mirrors the samples doc):

- Literal layer = the payload itself, complete; `detail` strings render
  verbatim with their tokens (`gate-red`, `unclaimed-err`, counts).
- Perceptual layer = the `quip` / captions: `quip_present: true` may earn
  one caption, which renders from the findings doc's italic line at
  display time and is never stored in the payload.
- `rounds` drives the operator checklist section; `alerts` drive the
  xN/badge state; `results[].fails[].cause` drives any color mapping.

## 6. Companion vocabulary (dashboard-self-review, not merged)

`check_feed_valid` findings (dashboard-self-review.py:97-134) use the
same three-part shape but a different envelope:
`check = "feed-valid:<feed>"`, two-tier status
(`unacceptable-now` / `acceptable-for-now`, dashboard-self-review.py:72-77),
identity prefix `dash-selfreview:`. This schema deliberately does NOT
merge the two watchers: patrol findings are route-attributed and
tier-cadenced; self-review findings are feed-attributed and per-tick.
A future `hngh.finding.v1` common envelope is a synthesis decision, not
assumed here. If the viz renders both, key on the identity prefix
(`patrol:` vs `dash-selfreview:`).

## 7. Known gaps (honest, unresolved)

- The repeat-research rule (same patrol+cause on two consecutive runs ->
  research-subjects entry, patrol.py:1289-1318) is readable only from
  consecutive payloads plus the previous run's FAIL set; the schema has
  no `repeat: true` field yet. Renderer must diff run N-1, or the
  emitter must add `repeated_from_previous: bool` per fail-item.
- `read_runs` history depth is yesterday + today only (patrol.py:1229-1256);
  anything rendering streaks longer than that needs the ledger, not the payload.
- Morning rounds top-3 selection and cause histogram (patrol.py:1445-1510)
  are derivable but not included here; add a `morning` envelope only if
  the viz needs the digest-inline shape.
