# Memory Bridge Design: mnemopi <-> jcode -> hngh (one-way, read-only)

Status: design only, no code. Date: 2026-09-15.
Scope: a neutral export format plus one-way export contracts so hngh can
consume memory from the mnemopi (omp) and jcode stores without either
garden's dynamics cross-contaminating the other.

Sources verified locally (2026-09-15):
- `.agent-scratch/consider/memory-systems.md` (hydrated survey).
- `~/.omp/agent/memories/mnemopi/mnemopi.db` — schema + counts via
  `sqlite3 'file:...mnemopi.db?mode=ro'` (read-only URI mode).
- `~/.jcode/memory/global.json` and `projects/de81be18d5553f87.json`.
- `automation/lib/context-pack.sh`, `automation/lib/jcode-delegate.sh`,
  `automation/lib/ocgo-delegate.sh`, `automation/lib/launch-session.sh`,
  `automation/jobs/digest-public.py`.

---

## 0. Verified store facts (evidence)

### mnemopi (agent bank `~/.omp/agent/memories/mnemopi/mnemopi.db`, WAL)

Counts (2026-09-15): facts 657, working_memory 172, episodic_memory 59,
triples 82, graph_edges 2849, gists 59, memory_embeddings 228,
memory_validations 0. Per-project banks exist too:
`memories/mnemopi/banks/{20260815-2dwrk40i9wotk, etc-3ilbrhgii8gwt, sysconfig_mgmt-407tzp7446tl}/mnemopi.db`.

- `facts` — SPO triples: `fact_id TEXT PK, session_id, subject, predicate,
  object, timestamp, source_msg_id, confidence REAL DEFAULT 1.0,
  created_at`; FTS5 via `fts_facts` (insert/delete triggers).
- `working_memory` — richest row: `id TEXT PK, content, embed_text,
  source, timestamp, session_id, importance REAL, metadata_json,
  veracity ('unknown'|'tool'), memory_type ('fact'|'episode'),
  consolidated_at, recall_count, last_recalled, valid_until,
  superseded_by, scope, author_id/author_type/channel_id,
  trust_tier ('STATED'), validator, validated_at, validation_count,
  event_date + event_date_precision, temporal_tags, corrected_by,
  created_at.`
- `episodic_memory` — same provenance columns plus `tier INTEGER` (all 1
  today), `summary_of`, `binary_vector BLOB`.
- `triples` — SPO with bitemporal `valid_from/valid_until` + confidence.
- `memory_embeddings` — `memory_id TEXT PK, embedding_json TEXT, model,
  created_at`. **Verified model: `BAAI/bge-base-en-v1.5`, 768 dims** (all
  228 rows). The 384-dim assumption in the task brief is wrong for
  mnemopi; see Section 5.
- `memory_validations` — trigger `trim_validations_to_3` keeps last 3
  per memory; 0 rows in practice, so `trust_tier`/`validator` columns
  are currently all defaults (`STATED`/NULL).
- Also present: `scratchpad`, `gists`, `graph_edges`, `memoria_*`
  (facts/timelines/instructions/preferences/kg), `consolidation_log`.
- Access: tools inside omp only (retain/recall/reflect/memory_edit/
  learn). **No standalone CLI on PATH** — direct SQLite read is the only
  machine-usable seam.

### jcode (`~/.jcode/memory/global.json`, `graph_version:2`)

Single JSON object: `graph_version, metadata, memories{id->entry},
edges, reverse_edges, tags, clusters`. Observed global store: 1 entry;
per-project file has several (trust high/medium/low observed).

`MemoryEntry` shape (verified sample, `jcode-memory-types/src/lib.rs:233`):

```json
{
  "id": "mem_1789399244269_14828478131731274774",
  "category": "fact",
  "content": "...",
  "tags": ["billion-context", "omp", "...", "verified"],
  "search_text": "...(lowercased content + tags)...",
  "created_at": "2026-09-14T15:20:44.269285537Z",
  "updated_at": "2026-09-14T22:59:50.990571867Z",
  "access_count": 1,
  "source": "session_ant_1789393909885_032dd7c23ec2c61f",
  "trust": "medium",
  "strength": 1,
  "active": true,
  "superseded_by": null,
  "reinforcements": [],
  "embedding": [/* 384 floats */],
  "embedding_model": "minilm-l6-v2",
  "confidence": 0.0
}
```

Garden ops (jcode-base/src/memory_agent.rs): judge-verified confidence
boost, rejected decay, `discover_links` :1730, `refine_clusters` :1374,
`prune_low_confidence` :1527, `infer_context_tag` :1622,
backfill_embeddings (memory.rs:930). Retrieval: BM25 + dense, RRF.

---

## 1. Neutral superset JSON shape

One file: a JSON Lines export (`.jsonl`), one record per memory unit,
self-describing, additive-only (new fields allowed, none removed).
Consumers must ignore unknown fields.

```json
{
  "bridge_id": "mnemopi:working_memory:<id>",
  "origin": {"system": "mnemopi|jcode", "store": "<path>",
             "bank": "<bank|null>", "native_table": "working_memory",
             "native_id": "<id>"},
  "kind": "triple|proposition|episode|gist",
  "content": "string (canonical text; for triples: 'subject predicate object')",
  "subject": "string|null", "predicate": "string|null",
  "object": "string|null",
  "tags": ["string"],
  "created_at": "RFC3339|null",
  "updated_at": "RFC3339|null",
  "event_date": "RFC3339 date|null",
  "event_date_precision": "day|month|year|unknown|null",
  "valid_until": "RFC3339|null",
  "superseded_by_bridge_id": "string|null",
  "corrected_by": "string|null",
  "confidence": 0.0,
  "importance": 0.0,
  "veracity": "unknown|stated|tool|validated|rejected|null",
  "trust_tier": "STATED|VALIDATED|OPERATOR|null",
  "validator": "string|null",
  "validation_count": 0,
  "strength": 0,
  "access_count": 0,
  "recall_count": 0,
  "source": "string|null",
  "session_id": "string|null",
  "scope": "global|project:string|null",
  "active": true,
  "embedding_model": "string|null",
  "embedding": {"dim": 384, "values": []},
  "exported_at": "RFC3339",
  "export_query": "string (provenance of the exact SELECT that produced it)"
}
```

### Field mapping and lossiness

Both sides map into the superset; every lossy step is named.

| Neutral field        | mnemopi source | jcode source | Lossiness |
|---|---|---|---|
| `bridge_id`          | `mnemopi:<table>:<id>` | `jcode:<scope>:<id>` | lossless; stable join key |
| `content`            | `content`; facts: `subject \|\| ' ' \|\| predicate \|\| ' ' \|\| object` | `content` | jcode entries often embed several facts in one paragraph; cannot be split back into triples without NLP — recorded as one `proposition` |
| `subject/predicate/object` | facts/triples columns | null | lossy for jcode: triple structure is not recoverable; consumers must treat null-triple propositions as unstructured text |
| `tags`               | `temporal_tags` JSON | `tags` | different vocabularies; no normalization attempted in v1 |
| `created_at/updated_at` | `timestamp`/`created_at` | `created_at`/`updated_at` | mnemopi has no updated_at; use `created_at` (lossy: edits invisible) |
| `event_date(+precision)` | dedicated columns | absent | lossy for jcode: dates inside content text only |
| `valid_until`        | column | absent | lossy for jcode |
| `superseded_by_bridge_id` | `superseded_by` | `superseded_by` | lossless join via bridge_id; jcode `active=false` + null `superseded_by` -> `active:false` with no successor |
| `corrected_by`       | `corrected_by` (INTEGER, working/episodic) | absent | lossy for jcode: corrections exist only as content-level restatements |
| `confidence`         | facts.`confidence`; wm/em: use `importance` as proxy | `confidence` (decays) | **not comparable**: mnemopi confidence is extraction-time, jcode confidence is garden-time and decays to 0.0 (observed). Consumers must not rank across origins on this field alone |
| `importance`         | `importance` | absent | lossy for jcode (no equivalent; strength is nearest but counts reinforcements, not a prior) |
| `veracity`           | `veracity` (`unknown`, `tool`) | absent | lossy for jcode |
| `trust_tier`/`validator`/`validation_count` | columns (all `STATED`/NULL today) | absent | jcode `trust` (high/medium/low) is a different axis: it is the author's claim, not a validator's verdict. Map jcode `trust` -> **separate** field `trust_claim` (add to shape) rather than overloading `trust_tier` |
| `strength`           | absent (nearest: `validation_count`, `recall_count`) | `strength` | lossy for mnemopi: reinforcement history exists only as recall_count |
| `access_count`/`recall_count` | `recall_count`/`recall_count` | `access_count` | different semantics (recall vs retrieval); keep both raw under origin-specific names if needed; do not merge |
| `source`/`session_id` | columns | `source` (session id) | lossless; jcode has no separate session field |
| `scope`              | `scope` column + bank name | file scope (global vs `projects/<hash>`) | jcode per-project hash is opaque; record as `project:<hash>` without resolving the path |
| `active`             | derived: `valid_until IS NULL AND superseded_by IS NULL` (no boolean column) | `active` | mnemopi activity is inferred; note derivation in `export_query` |
| `embedding`(+model)  | `memory_embeddings.embedding_json` + `model` | `embedding` + `embedding_model` | **never cross-compare**: 768-d bge vs 384-d MiniLM; see Section 5 |
| `kind`               | facts/triples -> `triple`; wm memory_type=fact -> `proposition`; em -> `episode`; gists -> `gist` | always `proposition` | lossy for jcode |

Rejected alternative: making jcode `MemoryEntry` itself the neutral
format. It cannot express SPO triples, event dates, veracity, or
validation provenance without a lossy reshuffle, and it would couple the
bridge to jcode's private schema (`graph_version:2`), which the garden
rewrites at will.

## 2. One-way export contracts

Both exports are pure reads producing the neutral file. Neither writes
anything back to a source store. Export layout (userspace data home,
never committed):

```
~/.hngh/memory-bridge/
  mnemopi-agent.jsonl        # agent bank export
  mnemopi-<bank>.jsonl       # one per project bank
  jcode-global.jsonl
  jcode-project-<hash>.jsonl
  manifest.json              # store path, mtime, row counts, exported_at, queries used
```

(`~/.hngh/` is the sanctioned userspace data home, 2026-09-13 operator
directive; the layout contract's listed dirs do not include a memory dir,
so this is a new sibling — see open questions.)

### 2a. mnemopi -> neutral (SQLite read; no CLI exists)

Invocation seam: `sqlite3 'file:<db>?mode=ro'` (read-only URI; WAL side
files must not be written). Run only when no omp session is actively
consolidating (WAL allows concurrent reads; worst case is a slightly
stale snapshot, which is acceptable for export).

Queries (exact, agent bank):

```sql
-- propositions (working_memory), active only:
SELECT 'mnemopi:working_memory:'||id, id, content, embed_text, source,
       timestamp, session_id, importance, metadata_json, veracity,
       memory_type, recall_count, last_recalled, valid_until,
       superseded_by, scope, trust_tier, validator, validated_at,
       validation_count, event_date, event_date_precision, temporal_tags,
       corrected_by, created_at
FROM working_memory
WHERE consolidated_at IS NOT NULL   -- skip unconsolidated scratch
  AND (valid_until IS NULL OR valid_until > strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  AND superseded_by IS NULL;

-- episodes: same column list FROM episodic_memory (add tier, summary_of).

-- triples (facts), full history retained but flagged:
SELECT 'mnemopi:facts:'||fact_id, fact_id, session_id,
       subject, predicate, object, timestamp, source_msg_id,
       confidence, created_at
FROM facts;

-- triples (triples table): + valid_from/valid_until window.

-- embeddings joined separately (PK memory_id matches wm/em ids):
SELECT memory_id, model, embedding_json FROM memory_embeddings;
```

Determinism notes: `ORDER BY created_at` for stable diffs; hash rows
into the manifest so a rerun with no upstream change produces an
identical file. `binary_vector BLOB` from episodic_memory is **skipped**
(undocumented format, likely a proprietary index artifact, not a
portable embedding). `memoria_*`, `graph_edges`, `scratchpad`,
`consolidation_log` are excluded in v1: session-scoped or internal
machinery with no hngh consumer (documented as deliberate non-goals).

### 2b. jcode -> neutral (global.json read; garden-owned store)

`jq`/python read of `~/.jcode/memory/global.json` and
`projects/<hash>.json`. Transformation rules:

- Pass through: id, category (-> `tags` alongside? no: category ->
  `origin.native_category`, content, tags, created_at/updated_at,
  access_count, source, strength, active, superseded_by, reinforcements
  count, confidence, embedding, embedding_model).
- `search_text` is dropped (derived data, recomputable).
- `trust` -> `trust_claim` ("high"|"medium"|"low"), never mapped onto
  mnemopi's `trust_tier`/`veracity` axes.
- `active:false` rows are exported with `active:false` (tombstones are
  signal), never filtered.
- The garden owns this store: **read-only from outside, always.** No
  bridge process may create, edit, boost, decay, or delete entries; no
  foreign `source` ids injected. The only writer is jcode itself (the
  memory garden and its sidecar agent).

## 3. Conflict rules

1. **Exclusive writers per store.** mnemopi's writer is omp/mnemopi's
   own consolidation and validation machinery. jcode's writer is the
   jcode memory garden. hngh bridge processes are readers of both and
   writers of neither source store (their only write surface is
   `~/.hngh/memory-bridge/`).
2. **Never cross-write.** The strongest verified reason: jcode's garden
   decays/prunes/clusters *every* entry in its store regardless of
   author (memory_agent.rs boost/decay/prune pass over the whole graph).
   Foreign mnemopi-sourced entries would be confidence-decayed toward
   `prune_low_confidence` deletion by a process that never validated
   them, while mnemopi's own `consolidation_log`/`memory_validations`
   would record the same judgments on its side — double-application of
   lifecycle. Symmetrically, mnemopi's consolidation would rewrite
   jcode entries it cannot judge under its validator model.
3. **Reads are bridged, not synced.** There is no merge, no dedup, no
   identity resolution between stores in v1. The same fact appearing in
   both exports stays two records (`bridge_id` namespaces prevent
   collision). Consumers rank by provenance + recency + text relevance,
   never by cross-origin `confidence`.
4. **No writes on the mnemopi side either** — no INSERT/UPDATE/DELETE,
   and specifically no `omp` recall/retain invocations from the bridge,
   because those mutate `recall_count`/`last_recalled` (read-path
   side effects). Export SQL must be pure SELECT.
5. **Failure is closed**: unreadable/corrupt store, schema drift
   (missing expected column), or parse error -> export that store's
   partition as empty + error in `manifest.json`, keep the other
   partition; hngh consumers must tolerate a missing partition.

## 4. hngh consumption path

Two sanctioned surfaces, both existing, both bounded; no new job is
created in v1 — the export generation rides existing jobs:

1. **Context pack sibling (primary).** `automation/lib/context-pack.sh`
   assembles one bounded orientation file per delegated session (hard
   cap `CONTEXT_PACK_BYTES=1500`, `head -c` enforced, line
   `context-pack.sh:19,93`). A memory block joins the pack as a new
   section rendered by a small helper that reads the neutral export and
   emits at most N top lines (relevance = text match against the
   session objective; field order: `content`, origin, date). The cap
   already guarantees memory can only *displace boilerplate*, never
   exceed the budget — and the existing ordering rule (project block
   first, generic boilerplate truncates first, context-pack.sh:80-83)
   keeps memory lower priority than repo orientation. Consumers: every
   launch path already funnels through this one generator
   (lib/launch-session.sh, watchdog respawn).
2. **Lessons tail (secondary, zero new code).**
   `lib/jcode-delegate.sh:71-86` and `lib/ocgo-delegate.sh:101` inject
   `tail -n 5` of `automation/state/ocgo-agent-lessons.md` into the
   prompt as failure-class steering. The memory bridge does not replace
   this: lessons are per-run corrections; the bridge is background
   knowledge. If a memory row is a correction-class lesson, the writer
   of that lesson appends it to the lessons file as today — no direct
   pipe from neutral export to prompts.

Where the export job itself lives: the natural host is the existing
digest/newspaper job family (`automation/jobs/digest-public.py` already
walks repo state into bounded digests) or the overnight forethought
pass, both of which already run on cadence and write userspace data.
Running the export at launch time (inside context-pack.sh) is rejected:
it would put two subprocess spawns (sqlite3 + jq) and a store read on
the hot launch path, and launch is the worst place to discover a store
problem. Cadence-generated export + at-launch *render* only.

Boundary check: nothing here touches kernel `src/`, `tests/`, `Makefile`,
`hngh.asd`, or repo-root `scripts/`; it is pure automation-layer + userspace
data, inside the free-commit lane. No daemon, watcher, or scheduler is
started (the export runs inside existing cadence jobs; the boundary rule
"do not start a daemon" is respected).

## 5. Open questions for the operator

1. **Embedding mismatch is worse than briefed — confirmed hard rule.**
   Verified: mnemopi = 768-d `BAAI/bge-base-en-v1.5` (228/228 rows),
   jcode = 384-d MiniLM (`minilm-l6-v2`). Not "384 vs 384 different
   models" but different dimensionality outright. Vectors are never
   cross-compared, full stop; the neutral record carries
   `(embedding_model, dim, values)` and consumers doing similarity must
   either (a) embed query text with each store's own model at render
   time, or (b) match on text only (recommended v1). Question: is a
   shared re-embedding pass (re-embed both corpora into one model under
   `~/.hngh/`) ever wanted, or is text-only matching a permanent rule?
2. **Export location + retention**: `~/.hngh/memory-bridge/` as a new
   sibling of the layout contract dirs (newspaper/manga/wiki/db/archive/
   dispatch), or fold under `~/.hngh/db/`? The layout contract lists
   six dirs + `catalog.tsv`; a memory export needs a name the contract
   either gains or maps into `db/`.
3. **Private content boundary**: mnemopi working/episodic rows include
   session chatter (`veracity: tool`, author/channel fields) from
   unrelated projects (banks: sysconfig_mgmt, etc, a dated bank). The
   context pack has a hard no-secrets law (context-pack.sh:9-10);
   should the bridge filter mnemopi rows by scope/author before they
   can reach an hngh pack, or export everything and trust the byte cap?
4. **Confidence semantics**: mnemopi `confidence` (extraction-time,
   observed 0.5-1.0) vs jcode `confidence` (garden decay, observed 0.0
   after a day). Should v1 export both raw under separate names, or is
   there an operator-approved normalization (e.g. rank by
   origin-relative percentile only)?
5. **Per-project jcode stores**: `projects/<hash>.json` hashes are
   opaque. Resolve hash -> project path at export time (requires
   reading jcode's config, coupling to another private layout), or
   carry the opaque hash (`project:<hash>`) and let the operator map?
6. **mnemopi banks**: three project banks exist. Export all always, or
   only banks matching an allowlist (the same content-boundary question
   as #3, per bank)?
7. **jcode trust vocabulary**: jcode `trust` (high/medium/low, author's
   claim) vs mnemopi `trust_tier` (STATED/VALIDATED/OPERATOR, process
   verdict). The design keeps them separate (`trust_claim` vs
   `trust_tier`); confirm no future requirement to unify them into one
   axis, which would force lossy judgment calls.

## 6. What this design deliberately does not do

- No code, no scripts, no schema changes anywhere (design doc only).
- No merge/dedup/identity resolution between stores.
- No write path into either store, ever, from the bridge.
- No new daemon/scheduler; export rides existing cadence jobs.
- No kernel surface touched; hngh-side work, when approved, is
  automation-layer only (context-pack.sh renderer + one export helper),
  fixture-backed per engineering rules, with a failing test written
  before production behavior at implementation time.
