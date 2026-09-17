# History payload schema — sessions.json and telemetry.db

## Producers

- `automation/jobs/sessions-feed.py` — sole producer of
  `automation/dashboard/sessions.json` (top-level object). Sources:
  `readout.json` roster rows (hngh store `~/.hngh-automation/store`,
  bridge store, `/tmp/hngh-heartbeat-*`, `/tmp/hngh-auto-*`), omp
  transcripts (`~/.omp/agent/sessions`), jcode
  (`~/.jcode/sessions`), opencode sqlite (`~/.local/share/opencode`),
  pi (`~/.pi/agent/sessions`). Cadence 1m
  (`automation/cadence/1m/10-sessions-feed.sh`) plus per-PID tmp file
  to avoid concurrent-write corruption.
- `automation/jobs/telemetry.py emit` — append-only producer of the
  sqlite store `~/.hngh/db/telemetry.db` (WAL, table `events`;
  dashboard/telemetry.db is a historical path, now under the userspace
  home seam via `HNGH_HOME_DIR`). Best-effort, never fails a tick.
- `automation/dashboard-server.py` — read-only HTTP server:
  `GET /session/<id>?tail=N` (server-side slice of sessions.json),
  `GET /telemetry.json` (24h aggregate over events, 30s in-process
  cache, zeroed payload on sqlite error).
- Retired: `automation/dashboard/sessions.js` is a stub redirect to
  `sessions-view.js`; sessions.json "just carries parsed entries now."

## Consumers

- `automation/dashboard/sessions-view.js` — session observatory tab:
  sidebar from roster rows, conversation rendered from
  `detail.entries` (kinds: message/user, assistant, thinking,
  tool_call, tool_result, code, system; tool_call↔tool_result paired
  via `call_id`), legacy `detail.tail` (record.lisp receipt) fallback.
- `automation/dashboard/gantt.js` — cascading gantt engine; mounted by
  `schedule-view.js` (schedule.json feed), shares the theme key with
  the sessions tab. It consumes schedule data, not sessions.json.
- `automation/dashboard/overview-view.js` — spend stat from
  `/telemetry.json`.
- Other readers: `jobs/system-feed.py` (probe_sessions counts omp/bridge
  rows), `jobs/schedule-feed.py` (degrades if unreadable),
  `jobs/dashboard-self-review.py` (feed validity, per-key freshness
  60s), `jobs/patrol.py` (staleness 600s tier), cadence digest jobs
  (`07-budget-digest.sh`, `20-model-saturation.sh`, `25-wiki-health.sh`,
  `digest-html.py`, `digest-ledger.py`, `context-ratio.py`) read
  telemetry.db directly via `HNGH_TELEMETRY_DB`/`HNGH_HOME_DIR` seam.

## sessions.json payload schema (observed, canonical)

```json
{
  "generated": "2026-09-15T12:34:56Z",        // UTC ISO feed build time
  "sessions": [                                // roster + discovered rows
    {
      "id": "run-20260915T120347Z-172269",     // run id or omp/prefix row id
      "state": "live|complete|working|dead|evacuated|...", // chip state
      "mission": "morning digest 2026-09-15 0800",         // clipped title
      "source": "automation|bridge|heartbeat|auto|omp/<proj>|pi/<proj>|opencode/<proj>",
      "age": 3374.7,                           // seconds since start (nullable)
      "last_active_age": 12,                   // seconds since mtime (some rows)
      "model": "glm-5.3",                      // opencode rows only
      "cost": 0.12,                            // opencode rows only
      "title": "short", "title_full": "...",   // appended post-build by feed
      "detail": {                              // enrichment result (fail-open
                                               // per row: degraded rows keep
                                               // entries:[] + reason)
        "transcript": "/abs/path/to/record.lisp-or-jsonl", // or null
        "tail": "(:IDENTIFIER ...)",           // record.lisp receipt tail
                                               // (TAIL_LINES=80) or log lines
        "truncated": false,                    // transcript not fully read
        "entries": [                           // parsed conversation, last
                                               // ENTRY_CAP=400, ~192KB budget
          {
            "ts": "2026-09-14T15:03:30.591Z",
            "role": "user|assistant|toolResult|system",
            "kind": "message|thinking|tool_call|tool_result|code|system",
            "text": "...",                     // credential-redacted, per-kind
                                               // TEXT_CAP (msg 8000, thinking/
                                               // tool 4000, system 500)
            "tool": "edit",                    // tool_call only
            "call_id": "c1"                    // tool_call/tool_result pairing
          }
        ],
        "counts": {"shown": 12, "user": 2, "assistant": 0, "thinking": 1,
                   "tool_call": 1, "tool_result": 1},
        "reason": null                         // degradation reason when entries
      }                                        // are empty
    }
  ]
}
```

Guarantees: fail-closed write path (broken readout leaves prior feed
untouched; per-session enrichment failure degrades only that row;
per-PID tmp + `os.replace` atomic publish). Display layer only, never
governance input. Credential regex redaction mirrors
`verify-candidate.py CREDENTIAL_PATTERN`.

## telemetry.db `events` table schema (verbatim from telemetry.py)

```sql
CREATE TABLE IF NOT EXISTS events(
  ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT,
  model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,
  wall_s REAL, subject TEXT, refs TEXT, body TEXT);
```

- `kind` includes `session-cost` (per delegated session) and cadence
  tick kinds; `lane`, `unit`, `tokens_in`, `tokens_out`, `cost_usd` come
  from `--data` (whitelist-enforced); additive-only schema.
- `/telemetry.json` payload:
  `{"generated": ISO, "window": "24h",
    "buckets": [{"hour": "2026-09-15T08", "spend": F, "tokens_in": N,
                 "tokens_out": N, "runs": N}],
    "legs": {"<model|(none)>": count}, "spend": F}` (rounded 6dp;
  zeroed payload if the db is missing/locked).
