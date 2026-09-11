# LobeHub Grunt-Work Trial (2026-09-11)

Operator question, verbatim framing: before dropping LobeHub entirely, "we should
at least get some grunt-work out of it, no? If that's useful enough grunt work,
maybe we'll keep lobehub anyway." And: "Maybe it could be useful for scraping,
if there's a search quota to take advantage of?"

Scope per operator interjection: judge ONLY on quota utility the existing legs
(kimi judgment work, ocgo glm-5.3-flash background at $0 marginal, openrouter
fallback, local bench-gated unattended beats) cannot provide. The search/scrape
question is the live candidate. No model-comparison runs; all POSTs stay on the
agent's existing route (glm via agent-id).

## Probe log (4 bounded live calls, --max-time 28, key from
~/.config/hngh/lobehub-key, value never printed)

| # | Call | Latency | Result |
|---|------|---------|--------|
| 1 | POST /api/v1/responses, search probe: "Search the web for information about ainglish.org ... top 3 results as title+url+one-line summary. If you cannot search, say exactly: NO-SEARCH-CAPABILITY", max_output_tokens=400 | 28s | HTTP 000 (curl bound; no response body) |
| 2 | GET /api/v1/agents/agt_6sB8IcJhaTg6 | 0.6s | HTTP 200, full config returned (see below) |
| 3 | POST retry of call 1, phrasing tightened, max_output_tokens=350 | 28s | HTTP 000 (no response body) |
| 4 | POST plain differential (same shape as the 2026-09-10 verified 15-20s smoke test): "Name the single most notable CVE fixed in OpenSSH in 2025...", max_output_tokens=150 | 28s | HTTP 000 (no response body) |

Calls used: 4/4. All outputs above are complete; there were no bodies to trim
(except the agent config, reproduced below).

### Call 2 agent config, verbatim (GET .data)

```
agencyConfig: null   chatConfig: null   params: {}   provider: null
model: null          files: []          knowledgeBases: []
systemRole: <651-char slim summarization contract, unchanged since 2026-09-10>
id: agt_6sB8IcJhaTg6  slug: flies-rice-composition-thread  title: hngh
updatedAt: 2026-09-10T22:40:30.319Z
```

## Search/scrape verdict: DOES-NOT-WORK

Three independent pieces of evidence:

1. **No plugin surface exists to enable.** The GET-verified agent schema exposes
   exactly: agencyConfig, avatar, chatConfig, createdAt, description, id, model,
   params, provider, slug, systemRole, title, updatedAt, files, knowledgeBases.
   There is no plugins field, and params/files/knowledgeBases are empty. Nothing
   to PATCH-enable, so the mission's fallback path (enable a search/crawler
   plugin, restore afterwards) is unavailable.
2. **Plugin architecture is UI-side only** (docs/research/2026-09-10-lobehub-api-research.md
   section 2d): LobeHub plugins are OpenAPI-schema function-calling integrations
   wired in the desktop/UI session, not configurable through the agents REST API.
3. **Tonight the endpoint delivered zero completions**, including the plain
   prompt shape that completed in 15-20s on 2026-09-10. Three POSTs, three 28s
   timeouts, empty bodies -- the service did not clear the Cloudflare 30s edge
   at any point during the trial window. Even if a server-side search were
   firing on the search-shaped prompts (unprovable from outside -- the two
   search POSTs and the plain POST timed out identically), it exceeds the bound
   that makes the leg usable at all.

## Grunt-work sample

None. No search = no source-fetching sample to save. The remaining quota shape
is a plain LLM call on glm via agent-id -- strictly worse than ocgo (same model
class, $0 marginal, 5h-window paced, no 24.6k platform scaffold tax per call).

## Last differentiators, honestly

- **Model variety:** the agent route serves one model: the agent's bound glm.
  Agent config has model=null/provider=null -- the model is LobeHub-side, not
  addressable by us (earlier PATCH-model probes: non-agent routes fail
  server-side). The account's model list is a UI picker feature; per operator
  instruction no route probes were run. For hngh purposes "the models it's got
  available" collapses to one callable model through the one leg we hold.
- **Credits/limits:** 50/day cap (cadence-params lobehub-daily-cap) with daily
  reset only; every call burns ~24.6k input tokens of unremovable platform
  scaffold before our prompt. No account/credits endpoint was probed (budget);
  the 2026-09-10 doc's quota-shape findings stand.
- **Free context from the 24.5k scaffold:** none observed. The scaffold carries
  platform/persona text, not reusable context for hngh tasks; it is pure
  per-call overhead (the historical 524s and the Cloudflare-edge fragility
  trace partly to it).

## Recommendation: no differentiator -- drop

The only candidate differentiator (server-side search/scrape that ocgo,
openrouter, kimi, and local legs cannot do) is absent: no plugin field, UI-only
plugin architecture, and the endpoint did not complete a single call within the
28s bound tonight (0/3 POSTs, including the previously-verified 15-20s shape).
The quota buys nothing ocgo does not already provide at $0 marginal with less
latency, less overhead, and working pacing.

If the operator ever wants search-grounded research beats, the real path is the
existing research-beats lane fetching sources via curl and summarizing through
ocgo/local -- no LobeHub dependency. Re-arming lobehub-research-share and a
pinned task shape would only be justified by a capability change on LobeHub's
side (e.g. agents-API plugin support); nothing in tonight's evidence suggests
one is coming.