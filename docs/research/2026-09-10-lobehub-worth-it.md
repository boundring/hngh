# LobeHub Value Sanity Check (2026-09-10)

Operator question: is the lobehub quota worth it for the features it offers,
weighed against the work to meaningfully integrate lobehub with hngh?

## 1. Cost math, recomputed honestly

The earlier doc (lobehub-api-research.md s3) claimed "$4.30 just for input"
for a 28.6k-token call at "$0.15/M input tokens". That is off by 1000x:
28,600 x $0.15/1M = **$0.0043**, not $4.30. Confirmed live (keyless OpenRouter
/api/v1/models, 2026-09-10): z-ai/glm-5.3-flash = $0.15/M prompt,
$0.50/M completion. LobeHub routes through OpenRouter, so this is the billing
shape behind the leg.

Representative bounded research/summarization call (2k output), using the
in-pipeline telemetry row (2026-09-11T01:05Z: wall_s 30.44, tokens_in 24638,
tokens_out 14; tokens_out modeled at 2000 for the comparison):

| Route | Input tokens | Output | Input $ | Output $ | Total | Wall |
|---|---|---|---|---|---|---|
| lobehub (agent route) | 24,638 | 2,000 | $0.00370 | $0.00100 | **$0.0047** | 30.4 s |
| ocgo (opencode-go GLM) | ~1,000 | 2,000 | $0 (sub) | $0 (sub) | **$0.00** | 0.67 s |
| openrouter direct (plain model id) | ~1,000 | 2,000 | $0.00015 | $0.00100 | **$0.0012** | ~5-15 s |

The 24.5k platform scaffold (measured after our 28.6k -> 24.6k slim; the
remaining floor is LobeHub-owned and unremovable from our side) is an input
tax, not a cost blowout: at flash pricing it is 3/10 of a cent. The real
taxes are **latency (30.4 s vs 0.67 s ocgo)** and the **Cloudflare 30 s edge
timeout**, which caps output and historically 524s the leg.

Agent scaffold content, GET-verified today: systemRole is a 651-char slim
summarization contract ("respond in plain text, follow length limits, ground
every claim in sources, security items first"). It is hngh-orientation that
prompt-slimming already bought us once -- but the same 651 chars can be
pasted into an ocgo/openrouter system prompt for free. It substitutes for no
work the ocgo/openrouter routes cannot do with one line of prompt.

## 2. Feature tradeoff (the three RFCs)

| Option | What it buys | Integration work | Operator value |
|---|---|---|---|
| RFC 112 MCP client: LobeHub drives hngh (hngh exposes MCP server; LobeHub's agents call hngh's read-only tools) | hngh becomes a tool inside a LobeHub UI; LobeHub's GLM quota burns on LobeHub's side driving hngh | 2-4 agent sessions: wrap the existing automation/mcp/hngh_mcp_server.py surfaces for LobeHub's Streamable HTTP transport, plus operator-side binding/testing in the LobeHub UI | Low-medium: another UI to look at hngh state; omp already consumes the same MCP server |
| RFC 153 agent runtime: LobeHub spawns hngh as child CLI agent | LobeHub-hosted agent sessions that shell into hngh | 4-8 sessions: stdin/stdout stream-json protocol adapter, stream hygiene, error mapping | Low: duplicates what omp/bili already delegate to hngh |
| RFC 151 IM bot: LobeHub agent as Discord/Slack bot | Mobile/IM access to an hngh-ish assistant | 3-6 sessions: LobeHub-side channel setup, then the same MCP exposure as RFC 112; hngh's own phone channel is already parked on Termux/Telegram (BACKLOG.md) | Moderate IF the operator wants IM presence; the parked Telegram channel is the smaller sibling |

Key structural fact: every LobeHub-driven option makes **hngh the tool and
LobeHub the client** -- quota flows through LobeHub's session model, not
into hngh's chain. So the "integration" does not feed hngh any quota at all;
it is a UX/investment in a second operator surface. Meanwhile the reverse
direction (hngh consuming lobehub as a leg) is already built and working.

## 3. Verdict

**DEMOTE-to-opportunistic.** Set `lobehub-research-share` from 6 to 0 and
leave every other row and the leg machinery untouched. Minimum-work path:
one cadence-params row edit (config-only, the same mechanism env
LOBEHUB_RESEARCH_SHARE provides). The leg keeps its tests, telemetry,
credential-health probe, and pacing; if the operator ever wants it back,
flip the row to a nonzero share and it is live again -- zero rebuild.

Reasoning, no sunk cost:
- The quota buys almost nothing ocgo does not: ocgo is the same GLM-5.3-flash
  at $0 marginal cost (subscription), 45x faster (0.67 s vs 30.4 s), no
  platform scaffold tax, no Cloudflare 30 s edge ceiling. OpenRouter direct
  is $0.0012/call with no scaffold tax. LobeHub's only differentiator at
  $0.0047/call is nothing.
- The premium plan's ~15M credits/month are billed to the operator whether
  or not hngh arms the leg, so the quota itself is not being "wasted" by
  demoting -- it is simply not worth routing automation traffic through the
  slowest, most constrained path to the same model.
- No lobehub-unique feature justifies integration work. RFC 112/153/151 all
  invert the relationship (hngh as tool inside LobeHub) and buy a second
  operator UI, not capability; the one genuinely novel surface (IM/mobile
  presence) is better served by the already-parked Termux/Telegram channel.
- The in-pipeline row (wall_s 30.44, 24.6k in) closed the evidence gap; the
  leg is proven, it is just dominated by ocgo on every axis that matters for
  bounded research calls.

If the operator later wants IM presence: build the Telegram channel (parked
BACKLOG row), not a LobeHub Discord bridge -- it is smaller, operator-owned,
and does not depend on a third-party platform's RFC schedule.

Applied 2026-09-11: share row flipped to 0 per this verdict (see
automation/cadence-params.tsv; commit hash recorded in the session report).
