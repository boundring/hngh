# gitlog entry JSON shape — recent-history spine (node hist-gitlog-dedupfmt-shape)

Date: 2026-09-15. Read-only spec; no repo files edited. All claims verified
against live `git log` output in this repo and the pinned validator
`automation/jobs/viz_schema.py` (source of truth for the history/1 family).

## 1. What git actually emits here (verified commands)

```
$ git log --pretty=format:'%H|%h|%s|%an|%ae|%aI' -n 3
d6d239d0151034bfd7218ba8a9317112228dc823|d6d239d0|research: fail-...|Fixture|fixture@example.invalid|2026-09-15T08:39:26-04:00
```

Field facts measured on this repo:

- `%H` full hash: always 40 lowercase hex chars (50/50 sample).
- `%h` abbrev: 8 chars in this repo (50/50 sample), NOT 7. Note
  `scripts/generate-publication:109` truncates to 7 via `sha[:7]`; a new
  producer should use git's native `%h` (8) and not re-truncate, to avoid a
  second abbreviation convention.
- `%an` author name: 5 identities repo-wide (`git shortlog -sne --all`):
  boundring, omp-undo-redo, Fixture, hngh-machine, Cibo. `%ae` emails exist
  but are low-value for a history view (see field table).
- `%aI` strict ISO 8601 WITH numeric offset: `2026-09-15T08:39:26-04:00`.
  `%aI` vs `%cI` differ in only 1/500 recent commits (rebase artifact).
- `%s` subject: max 292 chars in last 500; 297/1000 recent subjects contain
  non-ASCII (em dash etc.); 0/500 contain tab, newline, or `|`; commas,
  colons, parens, hyphens common (498/500). JSON handles all of this; the
  producer must write UTF-8 (or `json.dumps` default `ensure_ascii=True`,
  which escapes to `\uXXXX` and is still valid JSON).
- Merge commits exist (`git log --merges` non-empty). The existing spine
  `scripts/generate-publication:103-111` (`git log --format=%s%x09%h
  --since --until`) does NOT pass `--no-merges`, so the gitlog feed includes
  merges by default to stay consistent with the publication spine.
- The tab separator `%x09` is the established in-repo convention
  (generate-publication:105) and is safe here (0 subjects contain a tab).

Recommended producer command (fields in spec order, tab-separated):

```
git log --since=<window-start> \
        --pretty=format:'%H%x09%h%x09%an%x09%aI%x09%s'
```

Window and cap are owned by sibling nodes (hist-gitlog, hist-gitlog-dedupfmt-cap).

## 2. Envelope (pinned; producer must not invent)

Already fail-closed-pinned by `automation/jobs/viz_schema.py:72-85` and the
acceptance gate `automation/tests/test-viz-schema-history.py`:

```json
{ "schema": "history/1", "entries": [ <entry>, ... ] }
```

- Exactly two envelope keys: `schema` (literal string `"history/1"`) and
  `entries` (list). Unknown envelope keys, missing keys, non-string schema,
  unknown version, malformed JSON, wrong types: all ERROR / exit 2
  (viz_schema.py docstring:22-40, `_ENVELOPE_FIELDS`/`_REQUIRED_FIELDS`).
- history/1 deliberately carries NO `generated_at` in the envelope (that is
  graph/1's shape). Feed freshness is the file's mtime / server stamp,
  consistent with how the patrol family omits it.
- Empty feed: `{"schema": "history/1", "entries": []}` is VALID (entries is
  a list; no min-length rule in the validator).

## 3. Per-entry field spec (the deliverable)

Core fields (required, fail closed if missing/wrong type — viz_schema.py:304-306):

| field    | type | rule                                                                 |
|----------|------|----------------------------------------------------------------------|
| `key`    | str  | `"gitlog:" + <full %H hash>`; regex `^gitlog:[0-9a-f]{40}$`. This is the dedup key (sibling node hist-gitlog-dedupfmt). Full hash, not the 8-char abbrev, because abbrev collisions are possible in principle and merged-feed dedup must be exact. The `gitlog:` prefix disambiguates from sibling sources (`journal:...`, `records:...`) in the merged recent-history feed. |
| `ts`     | str  | Author date `%aI`, normalized to UTC Z form `YYYY-MM-DDTHH:MM:SSZ` (e.g. `2026-09-15T08:39:26-04:00` -> `2026-09-15T12:39:26Z`). Z form matches the committed fixtures (`test-viz-schema-version.py:94` `_NOW = "2026-09-15T00:00:00Z"`) and graph-data.py's `generated_at` strftime `%Y-%m-%dT%H:%M:%SZ` (automation/jobs/graph-data.py:536), so every feed timestamp sorts lexicographically and shares one format. Author date chosen over commit date: it is the semantic "when the work happened"; `%aI`==`%cI` in 499/500 recent commits, and the merged feed sorts by `ts` (not git's internal commit-date order), so no ordering inconsistency arises. |
| `summary`| str  | Subject line `%s`, verbatim, 1:1 from git, never truncated by the producer (cap/truncation is owned by hist-gitlog-dedupfmt-cap; max observed here is 292 chars). May contain non-ASCII and punctuation. Never empty in this repo. |

Additive scalar fields (optional; ride the WARN-accept lane today, then get
formalized by widening the allowed-entry set in viz_schema.py as an additive
bump — NOT a schema/2, since the envelope is unchanged):

| field   | type | rule                                                                 |
|---------|------|----------------------------------------------------------------------|
| `author`| str  | `%an` author name, verbatim (e.g. `"Fixture"`, `"boundring"`). Author email is excluded: it adds no rendering value and is one more identity datum on an unauthenticated GET surface (see node sg-session-detail-exposure-decision for the exposure-precedent). |
| `short` | str  | git-native `%h`, 8 lowercase hex chars, regex `^[0-9a-f]{8}$`. Display convenience so consumers never re-abbreviate the 40-char hash themselves. |

Per the pinned validator (viz_schema.py:309-322): an unknown scalar entry key
WARNs and is accepted; an unknown key carrying a nested object/array fails
closed. Therefore entries are FLAT — no nested bodies, no arrays. Anything
richer (files touched, body text) is a future schema/2 question, out of scope.

Duplicate `key` values fail closed (viz_schema.py:323-329) — the dedup
contract from sibling node hist-gitlog-dedupfmt is enforced by the same gate.

Ordering: `entries` newest-first (`ts` descending, tie-break `key`
ascending for determinism). Truncation rule (newest-wins) is spec'd by
hist-gitlog-dedupfmt-cap.

## 4. Concrete example (real repo data, verified)

Input row (this repo, HEAD at time of writing):

```
d6d239d0151034bfd7218ba8a9317112228dc823  d6d239d0  Fixture  2026-09-15T08:39:26-04:00  research: fail-20260914-What-is-the-current-maximum-length-of-se reviewed-adopted
```

Emitted payload (single-entry feed shown; multi-entry feeds repeat the entry
object newest-first):

```json
{
  "schema": "history/1",
  "entries": [
    {
      "key": "gitlog:d6d239d0151034bfd7218ba8a9317112228dc823",
      "ts": "2026-09-15T12:39:26Z",
      "summary": "research: fail-20260914-What-is-the-current-maximum-length-of-se reviewed-adopted",
      "author": "Fixture",
      "short": "d6d239d0"
    }
  ]
}
```

This exact object passes the live validator today (core keys clean; `author`
and `short` flag two additive WARNs, exit 0). Empty-window case:

```json
{ "schema": "history/1", "entries": [] }
```

## 5. Producer obligations and test seam

- Serialization discipline (pinned by schema-tests-version-gate): payload
  must round-trip `json.loads(json.dumps(payload))` and still validate.
- Producer should validate its own output through
  `automation/jobs/viz_schema.py::validate_history` before writing (rc 2
  contract on reject).
- Hermetic tests: env seam for the git invocation (fake `git log` output or
  a fixture repo) is spec'd by parent node hist-gitlog-dedupfmt; the shape
  tests assert the table above against parsed fixture rows.
- Widen `viz_schema.py`'s allowed-entry set to accept `author`/`short`
  silently when the producer lands (currently they WARN as unknown extras —
  accepted, so landing order is not blocked).

## 6. Executed verification (closes the gap below)

- `python3 automation/jobs/viz_schema.py --schema history/1 <example>`:
  accepted, 2 additive WARNs (`author`, `short`), rc=0.
- Empty feed `{"schema": "history/1", "entries": []}`: `ok`, rc=0.
- Duplicate-key payload (same `key` twice): rejected, rc=2, detail
  `duplicate entry key` — the dedup gate is live.
- Round-trip `json.loads(json.dumps(payload))` then
  `validate_history`: ok=True with the same 2 WARNs.
- CLI gotcha recorded for producers: the seam's argv is
  `viz_schema.py --schema <tag> <payload-path>` (the tag is a flag, not a
  positional; my first invocation got that wrong and rc=1'd on usage).

## 7. What I did not check

- Did not spec the extraction window, cap value, or dedup/merge mechanics —
  owned by hist-gitlog / hist-gitlog-dedupfmt / hist-gitlog-dedupfmt-cap.
- Did not verify whether any dashboard JS consumer would choke on non-ASCII
  escaped sequences (no history consumer exists yet; viz_schema round-trip
  rule covers the transport).
- Did not measure subjects older than the last 1000 commits for control
  characters (recent window is the feed's actual scope).
