# Benchmark Sourcing — Design Brief

**Compiled**: 2026-08-06. Research: delegated subagent (deepseek-v4-flash,
Hermes delegation) plus direct verification of every data path from this host.

**Purpose.** Ground hngh's local-model selection (8B–35B open-weight GGUFs on an RX 7900 XT) against (a) published leaderboard data, (b) offline harnesses that hit the local OpenAI-compatible endpoint, and (c) the same probe suite run against remote free models. Everything procedural, no LLM judging. Designed to plug into `data/model-probes.lisp` (12-probe suite, `run-probe` is the TODO stub) and complement `scripts/fetch-model-benchmarks.sh` (OpenRouter catalog + LM Arena PPE + Aider HTML).

**As-of.** All URLs/commands below verified live on 2026-08-06 from this host.

---

## 1. Online reference: HuggingFace Open LLM Leaderboard v2

Two datasets on the hub: `open-llm-leaderboard/contents` (one row per evaluated model, the leaderboard table) and `open-llm-leaderboard/results` (one row per evaluation run, full nested per-task scores).

### 1.1 `contents` — leaderboard table, parquet (use this)

Parquet conversion exists and is a single ~1.1 MB file (verified 302 → `x-linked-size: 1109997`):

```
https://huggingface.co/datasets/open-llm-leaderboard/contents/resolve/refs%2Fconvert%2Fparquet/default/train/0000.parquet
```

Read it without installing anything heavy — duckdb reads parquet straight from the URL:

```bash
duckdb -c "SELECT fullname, \"#Params (B)\", \"Average ⬆️\", \"Hub License\", Precision, MoE,
                  \"IFEval Raw\", \"BBH Raw\", \"MATH Lvl 5 Raw\", \"GPQA Raw\", \"MUSR Raw\", \"MMLU-PRO Raw\"
           FROM read_parquet('https://huggingface.co/datasets/open-llm-leaderboard/contents/resolve/refs%2Fconvert%2Fparquet/default/train/0000.parquet')
           WHERE \"#Params (B)\" BETWEEN 8 AND 35 ORDER BY \"Average ⬆️\" DESC"
```

(Python alternative: `pip install pyarrow pandas; pd.read_parquet(url)`.) Discover current shards dynamically if `0000` ever shards:

```bash
curl -s "https://datasets-server.huggingface.co/parquet?dataset=open-llm-leaderboard%2Fcontents" | jq -r '.parquet_files[].url'
```

**Columns (verified):** `eval_name`, `fullname` (clean `org/model`), `Model` (HTML link), `Model sha`, `Precision`, `Weight type`, `Architecture`, `Type`, `T`, `#Params (B)`, `Hub License`, `Hub ❤️`, `MoE`, `Flagged`, `Chat Template`, `Merged`, `Official Providers`, `Available on the hub`, `CO₂ cost (kg)`, `Average ⬆️`, `IFEval Raw`/`IFEval`, `BBH Raw`/`BBH`, `MATH Lvl 5 Raw`/`MATH Lvl 5`, `GPQA Raw`/`GPQA`, `MUSR Raw`/`MUSR`, `MMLU-PRO Raw`/`MMLU-PRO`, `Upload To Hub Date`, `Submission Date`, `Generation`, `Base Model`.

**Units (important, verified from a real row):** `* Raw` columns are 0–1 accuracies; the bare columns are scaled — IFEval and MATH Lvl 5 are percentages (0.3303 → 33.03), BBH/GPQA/MUSR/MMLU-PRO are logit-normalized 0–10 (MMLU-PRO Raw 0.116 → 1.82). `Average ⬆️` is the leaderboard's aggregate (e.g. 8.91). For the hngh comparison table use the Raw columns to keep everything on a 0–1 scale, or the same normalization for all.

Per-model raw detail lives in sibling datasets named `open-llm-leaderboard/<org>__<model>-details` (link pattern visible in the `Model` column).

### 1.2 `results` — raw per-run rows, rows API (no parquet)

**No parquet conversion exists** — `datasets-server /parquet` returns `failed: config-parquet` (verified). The `rows` endpoint is also broken dataset-side (`/rows?config=default` → `"The dataset generation failed … Couldn't cast array of type struct<task…>"`, a HF arrow-cast bug — verified). Use the **`first-rows`** endpoint instead (verified working, returns the full nested row):

```
https://datasets-server.huggingface.co/first-rows?dataset=open-llm-leaderboard%2Fresults&config=default&split=train
```

```bash
curl -s "https://datasets-server.huggingface.co/first-rows?dataset=open-llm-leaderboard%2Fresults&config=default&split=train" \
  | jq -r '.rows[].row | [.model_name, (.config.model_num_parameters|tostring), (.results.leaderboard["acc_norm,none"]|tostring), (.date|tostring)] | @tsv'
```

**Row fields (verified):** `model_name`, `model_name_sanitized`, `model_source`, `model_sha`-ish via `config.model_sha`; `config` includes `model`, `model_num_parameters`, `model_dtype`, `batch_size`, seeds, `gen_kwargs`; `results` = nested per-task metrics dicts keyed like `leaderboard`, `leaderboard_bbh_*`, `leaderboard_gpqa[_diamond|_extended|_main]`, `leaderboard_ifeval`, `leaderboard_math_*_hard`, `leaderboard_mmlu_pro`, `leaderboard_musr_*`; each metric dict holds `acc_norm,none` / `exact_match,none` / `inst_level_*` / `prompt_level_*` plus `_stderr`; plus `date`, `start_time`, `end_time`, `total_evaluation_time_seconds`, `chat_template`, `chat_template_sha`, `max_length`, `task_hashes`. (No license/precision columns here — those come from `contents`.)

### 1.3 Suggested integration

Extend `fetch-model-benchmarks.sh` with source 4: fetch the `contents` parquet via duckdb/curl+pyarrow, filter `#Params (B)` 8–35 ∧ `Available on the hub` ∧ `MoE=false|true` (keep flag), and merge `fullname → {average, ifeval_raw, gpqa_raw, mmlu_pro_raw, math_raw, bbh_raw, musr_raw, params_b, precision, license}` into the snapshot under `"hf_ollv2": {…}`. **Caveat:** leaderboard scores are run on bfloat16 full-precision checkpoints, not GGUFs — treat them as an upper bound, not the quant's score.

---

## 2. Offline evaluation frameworks against the local endpoint

All four local models are served via unsloth/ollama's OpenAI-compatible API at `http://127.0.0.1:11434/v1` (chat completions + `/v1/chat/completions`). Every framework below speaks that protocol directly.

### 2.1 lm-evaluation-harness (EleutherAI) — accuracy benchmarks

```bash
# install (venv recommended; the [ifeval,math] extras pull the task-specific deps)
python -m venv ~/venvs/lm-eval && source ~/venvs/lm-eval/bin/activate
pip install "lm_eval[ifeval,math]"

# enumerate tasks (grep for what we care about)
lm_eval --tasks list | grep -iE 'ifeval|jsonschema|leaderboard|humaneval|mbpp|gpqa|mmlu_pro|bbh|math'
```

Exact invocation against ollama (chat completions backend):

```bash
lm_eval --model local-chat-completions \
  --tasks leaderboard_ifeval,jsonschema_bench,humaneval,mbpp \
  --model_args model=gemma-4-12b-it-qat,base_url=http://127.0.0.1:11434/v1/chat/completions,num_concurrent=8,max_retries=3,tokenized_requests=False \
  --apply_chat_template --fewshot_as_multiturn \
  --output_path data/lm-eval/gemma-4-12b --log_samples
```

Notes: `base_url` must end in `/v1/chat/completions` for `local-chat-completions` (use `local-completions` + `/v1/completions` for non-chat endpoints; ollama only serves chat). `tokenized_requests=False` is required for server-side tokenization. Add `--limit 100` for smoke runs; `--tasks leaderboard` runs the exact Open LLM Leaderboard v2 group locally.

**Workload mapping:**
| hngh probe category | lm-eval task(s) |
|---|---|
| `:json` (P5) | `jsonschema_bench` (JSON-schema conformance — direct match) |
| `:instruct` (P6) | `ifeval` / `leaderboard_ifeval` (instruction following, loose+strict) |
| `:code` (P7) | `humaneval`, `mbpp` (pass@1, Python) |
| `:debug`/`:plan`/`:refactor`/`:test` | no standard task — covered by probes/promptfoo/aider |
| `:bash`, `:elisp`, `:cl` | **no standard task exists anywhere** — probe suite is the only coverage |
| `:doc`/`:summarize` (P4, P12) | `cnn_dailymail` (summarization, optional, low signal) |

### 2.2 promptfoo — probe-suite twin, YAML-defined

```bash
npm install -g promptfoo        # or: npx promptfoo
```

`promptfooconfig.yaml` — local vs remote in one file:

```yaml
providers:
  - id: openai:chat:gemma-4-12b-it-qat
    config:
      apiBaseUrl: http://127.0.0.1:11434/v1
      apiKey: ollama            # ignored by ollama, required by the client
      temperature: 0
  - id: openai:chat:qwen-agentworld-35b-a3b
    config: { apiBaseUrl: http://127.0.0.1:11434/v1, apiKey: ollama, temperature: 0 }
prompts:
  - "Write a Common Lisp function READ-LINES that takes a pathname and returns a list of strings…"
  - "Output ONLY a JSON object matching this schema: {\"type\":\"object\",…}"
tests:
  - vars: {}
    assert:
      - type: contains        # P3 :cl
        value: "with-open-file"
      - type: is-json         # P5 :json
        value:
          type: object
          required: ["id", "status"]
          properties:
            status: { enum: ["pending", "running", "done"] }
      - type: not-contains    # P6 :instruct (no markdown)
        value: "```"
      - type: latency
        threshold: 30000      # ms — cheap procedural perf gate per probe
```

```bash
promptfoo eval -c promptfooconfig.yaml --output data/promptfoo-results.json --json
promptfoo view   # web UI
```

Assertions are all procedural: `contains`, `not-contains`, `regex`, `is-json` (+schema), `javascript` (arbitrary code), `latency`, `cost`, `python`. This is the closest drop-in for mechanically running the 12 probes with zero code — but note the probe suite's weighted scorers are richer, so use promptfoo for quick matrix runs and `run-probe-suite` for the canonical score.

### 2.3 Aider polyglot benchmark — end-to-end code editing

Benchmark = 225 Exercism exercises (C++, Go, Java, JS, Python, Rust), measures real file edits + test passes. Heavyweight (docker, multi-hour) — schedule it, don't run it ad-hoc.

```bash
git clone https://github.com/Aider-AI/aider.git && cd aider
mkdir tmp.benchmarks
git clone https://github.com/Aider-AI/polyglot-benchmark tmp.benchmarks/polyglot-benchmark
./benchmark/docker_build.sh                 # one-time image build
./benchmark/docker.sh                       # drop into the container
# inside container:
pip install -e .[dev]
./benchmark/benchmark.py hngh-gemma-4-12b \
  --model ollama_chat/gemma-4-12b-it-qat \
  --edit-format whole --threads 4 \
  --exercises-dir polyglot-benchmark
# outside container, stats only:
./benchmark/benchmark.py --stats tmp.benchmarks/<run-dir>
```

Key report fields: `pass_rate_1`, `pass_rate_2`, `percent_cases_well_formed`, `edit_format`. Model wiring: `ollama_chat/<name>` for local ollama; `openrouter/<org>/<model>` for remote (leaderboard convention, e.g. `aider --model openrouter/google/gemma-3-27b-it`). Covers `:refactor`/`:debug`/`:test`/`:plan`-adjacent skills far better than any MCQ benchmark; does **not** cover Lisp/Elisp/bash (exercises are the 6 mainstream languages).

### 2.4 Decision matrix

| Need | Tool |
|---|---|
| Capability numbers comparable to public leaderboards | lm-eval `leaderboard` group / `mmlu_pro`,`gpqa`,`bbh` |
| JSON conformance, instruction following | lm-eval `jsonschema_bench`,`ifeval`; promptfoo asserts |
| The user's actual Lisp/Emacs/bash workload | **model-probes.lisp only** (no public benchmark covers it) |
| End-to-end code editing | aider polyglot (docker, scheduled) |
| Quick local-vs-remote matrix + latency gate | promptfoo |

---

## 3. Procedural local performance measurement

### 3.1 Tokens/sec and TTFT — per-request timing from the ollama API (primary, verified)

Ollama 0.30.6 is live on this host. `/metrics` (Prometheus) returned **404** here, so do not depend on it; the per-request timing fields in the API response are the stable, version-independent source:

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{
  "model": "gemma-4-12b-it-qat",
  "messages": [{"role": "user", "content": "Write a Common Lisp function READ-LINES…"}],
  "stream": false, "options": {"temperature": 0}}'
```

Response timing fields (all nanoseconds, verified schema): `total_duration`, `load_duration` (model load, first call only), `prompt_eval_count`, `prompt_eval_duration` (prefill), `eval_count`, `eval_duration` (decode). Derived:

```
tokens/sec = eval_count / (eval_duration / 1e9)
prefill ms  = prompt_eval_duration / 1e6        # ≈ TTFT for the whole prompt
total ms    = total_duration / 1e6
```

Run each probe 3× with the model pre-loaded (`ollama run <model> hello` first) and take the median; report `load_duration` separately (cold-start tax). Probe latency is dominated by prefill for `:doc`/`:summarize` and by decode for `:code`.

### 3.2 VRAM — sysfs (rootless, verified) + rocm-smi + /api/ps

```bash
# rootless, exact bytes — verified on this host (card1 = RX 7900 XT, PCI 0x744c, 21,458,059,264 B ≈ 20 GiB)
cat /sys/class/drm/card1/device/mem_info_vram_total
cat /sys/class/drm/card1/device/mem_info_vram_used

# same values via ROCm (GPU[0] = 7900 XT; GPU[1] is the 512 MiB iGPU — ignore)
rocm-smi --showmeminfo vram --showuse --showtemp | sed -n '1,20p'

# what ollama itself claims for each loaded model (size_vram is the loaded footprint)
curl -s http://127.0.0.1:11434/api/ps
```

Sample VRAM delta around a probe run: read `mem_info_vram_used` before/after loading, and again after each probe; `peak = max over run`.

### 3.3 Snapshot schema — `data/model-benchmarks-local-YYYYMMDD.json`

Shaped to merge cleanly into the existing `fetch-model-benchmarks.sh` snapshot (add a `"local"` key alongside `"catalog"/"ppe"/"aider"`):

```json
{
  "fetched": ["ollama-timing", "sysfs-vram", "rocm-smi"],
  "date": "2026-08-06",
  "host": {
    "gpu": "AMD Radeon RX 7900 XT",
    "vram_total_bytes": 21458059264,
    "drm_card": "card1",
    "ollama_version": "0.30.6"
  },
  "models": {
    "gemma-4-12b-it-qat": {
      "endpoint": "http://127.0.0.1:11434/v1",
      "params_b": 12.0,
      "quant": "qat",
      "vram": {
        "load_delta_bytes": 8500000000,
        "peak_used_bytes": 10200000000,
        "ollama_size_vram_bytes": 9900000000
      },
      "perf": {
        "tokens_per_sec_median": 61.2, "tokens_per_sec_samples": [58.1, 61.2, 63.0],
        "ttft_ms_median": 420.0, "load_duration_ms": 1850.0,
        "eval_count_total": 12400
      },
      "probes": {
        "cl-read-lines": { "score": 1.0, "tokens_per_sec": 60.1, "ttft_ms": 431.0, "eval_count": 214 }
      },
      "aggregate_score": 0.83
    }
  }
}
```

Writer: extend `run-probe-suite`/the runner to emit one `probes` entry per probe with `(score, eval_count, eval_duration_ns, prompt_eval_duration_ns, tokens_per_sec, ttft_ms)` and wrap it with the `host`/`vram` block. Same schema (minus perf/vram, plus `provider: "openrouter"`) for the remote-free run in §4, so both land in one dated snapshot for `model-pareto.md`.

---

## 4. Scoring remote free models on the same probes

### 4.1 Discover `:free` endpoints (extend the existing catalog source)

```bash
curl -s https://openrouter.ai/api/v1/models \
  | jq -r '.data[] | select(.id | endswith(":free")) | [.id, (.pricing.prompt|tostring), (.context_length|tostring)] | @tsv'
```

At 8–35B scale the relevant ones typically include `google/gemma-3-27b-it:free`, `deepseek/deepseek-r1-distill-qwen-32b:free`, `qwen/qwen2.5-coder-32b-instruct:free`, `mistralai/mistral-small-3.2-24b-instruct:free`, plus larger reference points (`meta-llama/llama-3.3-70b-instruct:free`). Verify at runtime — the catalog filter is the source of truth.

### 4.2 One-shot scoring — same OpenAI-compatible client, no code change

`run-probe-suite` already takes `model-endpoint` + `model`; point it at OpenRouter:

```lisp
(run-probe-suite :model-endpoint "https://openrouter.ai/api/v1"
                 :model "google/gemma-3-27b-it:free")
```

The runner must add two headers (OpenRouter attribution requirements): `HTTP-Referer: https://github.com/boundring/hngh` and `X-Title: hngh`. One shot per probe per model (`temperature 0`, per-probe `timeout` respected), aggregate = weighted mean exactly as the local run, so scores are directly comparable.

```bash
# smoke test before the full suite
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "HTTP-Referer: https://github.com/boundring/hngh" \
  -H "X-Title: hngh" \
  -d '{"model":"google/gemma-3-27b-it:free","messages":[{"role":"user","content":"Write a Common Lisp function READ-LINES…"}],"temperature":0}'
```

### 4.3 Caveats

- **Rate limits:** free endpoints are throttled (nominally ~20 req/min and ~50 req/day per model, subject to change) — a 12-probe suite fits comfortably; on 429, back off per `Retry-After` and skip that model if it stays down (mark `"status": "rate-limited"` in the snapshot). Some `:free` models flip offline; the fetch script's "skip cleanly on failure" pattern applies.
- **Comparability:** compare only probe **scores** (capability). Tokens/sec and TTFT from OpenRouter are meaningless vs. local (different hardware/quantization) — record them in the remote snapshot as `null` or informational only. Local-vs-remote perf comparison is only fair for `:free` models that are also served locally (e.g. gemma-3-27b class) and even then hardware differs.
- **Honesty rule:** leaderboard data (§1) and local runs (§3) must never be blended into one number; keep `hf_ollv2` (bfloat16 reference), `local` (GGUF, this machine), and `remote_free` (hosted) as three separate keys in every snapshot.

---

## Appendix — verified gotchas (2026-08-06)

- `open-llm-leaderboard/results`: no parquet; `/rows` broken (arrow cast bug); `/first-rows` works. `contents`: single `0000.parquet`, ~1.1 MB, clean.
- `Average ⬆️` and the bare task columns in `contents` are normalized; use `* Raw` for 0–1.
- Ollama `/metrics` 404 on 0.30.6 — use `/api/chat` timing fields (all durations in **nanoseconds**).
- Sysfs `card1` = RX 7900 XT (20 GiB total); rocm-smi `GPU[0]` matches; `GPU[1]` = iGPU, ignore.
- lm-eval `base_url` for `local-chat-completions` ends in `/v1/chat/completions`; always pass `tokenized_requests=False`.
- Aider polyglot is the only framework here with meaningful `:refactor`/`:debug` coverage, and it needs docker + hours; the probe suite remains the only coverage for Lisp/Elisp/bash — keep `run-probe` as the canonical score.

---

**What I did:** read the existing `model-probes.lisp` and `fetch-model-benchmarks.sh` to align the brief; verified every data path live (HF datasets-server parquet/rows/first-rows endpoints and their exact columns; ollama 0.30.6 API timing fields, `/api/ps`, sysfs VRAM, rocm-smi on this machine); confirmed lm-eval's `local-chat-completions` CLI + task list (incl. `jsonschema_bench`, `ifeval`, `leaderboard` group), promptfoo provider/assertion syntax, and the aider polyglot harness invocation from the official benchmark README.

**Files created/modified:** none (per instructions — brief returned as text above; save to `~/Projects/etc/hngh/docs/design/benchmark-sourcing.md`).

**Issues:** `open-llm-leaderboard/results` has no parquet conversion and its `/rows` endpoint is broken dataset-side (documented workaround: `/first-rows`); ollama `/metrics` 404s on this host (documented fallback: `/api/chat` timing fields); `data/model-probes.lisp`'s `run-probe` remains a stub — the brief specifies the exact response fields the implementation should capture, but the implementation itself was out of scope.