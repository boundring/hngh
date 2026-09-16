# Memory Systems Survey: jcode / Mnemopi (omp) / hngh

## 1. jcode memory (source: /home/bricker/src/jcode)
- Crates: `crates/jcode-memory-types/src/lib.rs` (schema+search), `crates/jcode-base/src/memory.rs`
  (store, JSON persistence), `crates/jcode-base/src/memory_agent.rs` (sidecar extraction,
  judge rerank, maintenance), `crates/jcode-embedding/`, `crates/jcode-ambient-types/`.
- On-disk: `~/.jcode/memory/global.json` + `.bak`, and per-project under
  `~/.jcode/memory/projects/<hash>.json`. Single JSON file per scope, `graph_version:2`.
- Schema (`jcode-memory-types/src/lib.rs:233` `MemoryEntry`): id (`mem_<ts>_<u64>`), category,
  content, tags, search_text, created_at/updated_at, access_count, source, trust (High/Medium/Low),
  strength (reinforcement count), active + superseded_by, reinforcements[] (session_id,
  message_index, timestamp), embedding Option<Vec<f32>> (384-d MiniLM, model-tagged, e.g.
  `minilm-l6-v2` or `openai:text-embedding-3-small`), confidence f32 (decays, boosted on use).
- Garden/maintenance ops (`memory_agent.rs`): post-retrieval confidence boost on
  judge-verified / decay on rejected (~:1291 `MaintenanceConfidence{boosted,decayed}`),
  `discover_links` (:1730), `refine_clusters` (:1374), `prune_low_confidence` (:1527),
  `infer_context_tag` (:1622), backfill_embeddings (`memory.rs:930`).
  Retrieval: hybrid BM25 + dense, RRF fusion; judge-verified carry-forward.

## 2. oh-my-pi / Mnemopi (found locally)
- omp installed via bun (`~/.bun/bin/omp`); no Mnemopi source checkout found on disk
  (only referenced in omp README: `memory.backend` = local | Hindsight | Mnemopi).
- Store: `~/.omp/agent/memories/mnemopi/mnemopi.db` (SQLite, WAL) plus per-project
  banks under `memories/mnemopi/banks/<project>-<id>/mnemopi.db` (3 banks present).
- Schema: multi-table. `working_memory` (id TEXT, content, embed_text, importance REAL,
  veracity, memory_type, recall_count, valid_until, superseded_by, scope, trust_tier,
  validator/validated_at/validation_count, event_date+precision, temporal_tags, corrected_by),
  `facts` (subject/predicate/object triples with confidence + FTS5),
  `episodic_memory` (tiered, binary_vector BLOB), plus gists, scratchpad, graph_edges,
  memoria_kg, consolidation_log, memory_validations, memory_embeddings (embedding_json + model).
  657 rows in `facts` in the agent bank.
- Access: tools inside omp (retain/recall/reflect/memory_edit/learn); NO standalone
  `mnemopi` CLI on PATH. hngh could only reach it via `omp` runs or direct SQLite reads.

## 3. Conflict analysis / translation seam
- IDs: jcode `mem_<ts>_<u64>` vs mnemopi free TEXT PKs, namespaced per bank DB.
- Content model: jcode = flat entries + tags; mnemopi = SPO triples (facts) + episodic
  + working layers. A bridge must map jcode fact/category content -> triple or working_memory.
- Embeddings: both are model-tagged (jcode Vec<f32> in-entry; mnemopi JSON in
  memory_embeddings). Dims may differ per model; never compare across models.
- Semantics overlap: superseded_by/active (jcode) vs superseded_by/corrected_by (mnemopi);
  confidence vs importance+confidence; trust enum vs trust_tier+validator.
- Recommended seam: a one-way export/sync job (mnemopi is the superset store, or a
  neutral third format) rather than two writers to one store.
- Double-apply risk: jcode's ambient garden decays/prunes/confidence-boosts its own
  graph. If pi wrote into `~/.jcode/memory/`, the garden would decay mnemopi-sourced
  entries it did not author, and mnemopi's own consolidation_log/validation would
  duplicate the same judgments. Keep writers exclusive per store; bridge only reads.

## 4. hngh memory-adjacent surfaces
- `automation/agent-handoffs.md` (284 lines): append-only run outcomes (overnight-lead,
  respawn-refused, operator-dismiss). Writers: automation lanes; read-back: manual +
  some scripts. Unbounded growth, no dedup.
- `docs/records/` (142 files): authoritative dated architecture history, committed.
  Read by agents at orientation. Permanent retention.
- Report queue (`scripts/report-queue`, MCP `queue_report`): dispatch items with
  dismissals; operational, not memory.
- `automation/state/` (11 files: beat-blockers.tsv, correction-sightings.tsv, etc.):
  per-domain scratch state; task-scoped, mostly write-only.
- None of these is a queryable memory graph; a unified memory layer would be new.
