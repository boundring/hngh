# bili (billion-context) applicability to the LobeHub leg

Date: 2026-09-10. Status: complete.
Scope: read-only research; this file is the only artifact.
Predecessor evidence: history://QueueDeps (killed mid-probe; all reads re-verified here).

## VERDICT (centerpiece)

NO -- bili cannot help the lobehub_chat leg, because the 28.6k-token
system prompt is SERVER-SIDE in the LobeHub agent. It never transits the
client, so there is nothing on the wire for bili to compress.

Evidence, automation/lib/model.sh:356-364 (_lobehub_body): the client
payload is a stateless single-turn Responses call:

    {"model": "<agt_6sB8IcJhaTg6>", "input": "<short prompt>",
     "max_output_tokens": N}

- model = the LobeHub agent id (model.sh:381, cadence-params row
  lobehub-agent-id); the agent's 28.6k-token system prompt is stored in
  the LobeHub agent config server-side.
- NO "messages" array, NO system role, NO conversation history -- the
  comment in model.sh:357-358 says exactly this ("model field = LobeHub
  agent id; NO messages").
- Each call is independent: no previous_response_id, no state carried
  (grep of automation/lib/model.sh: zero hits for previous_response_id).
- The prompt hngh sends (the task prompt) is short: job prompts are
  single paragraphs to a few KB. The 28.6k tokens ride only inside the
  LobeHub server between call arrival and model dispatch.

## Why per-call compression is moot

bili compresses CONVERSATION HISTORY on the wire (see Q1). On this leg
the wire carries only a short input string. The 24s+ latency and the
Cloudflare HTTP 524 cuts (STATE.md rows 2026-09-08) are caused by the
server-side prompt size -- LobeHub assembles agent prompt + input
inside their infra before the model call. No client-side proxy can
shrink what never leaves the client.

## Q1: What bili actually compresses/rewrites

Sources: ~/.npm-global/lib/node_modules/billion-context/README.md
(471 lines); ~/.npm-global/bin/bili (67,535-line esbuild bundle;
src/mitm.ts visible at line ~57970).

1. Compression target = conversation history. README.md:29-51: the
   proxy "parses the request (Anthropic or OpenAI shape), runs
   acp-kernel compression on the conversation, injects a compress tool
   ... forwards to the real model API". It folds consumed conversation
   into layered summaries -- i.e., it needs a multi-turn messages/input
   array to have something to fold.

2. Two modes (README.md:55-115):
   - Launcher/plugin mode (bili omp, bili pi): the agent is ACP-native
     with the bili extension; the agent executes compress locally; the
     summary rides on the tool call in the agent's own history.
   - Proxy mode (plain client, /bili/ prefix): the proxy executes
     compress server-side; summaries ride as acp_summary user messages.

3. MITM scope: launcher MITM is HOST-WHITELISTED, not arbitrary.
   Bundle src/mitm.ts: DEFAULT_MITM_DOMAINS = api.anthropic.com,
   api.openai.com, chatgpt.com (line ~57976); plus domains discovered
   from the client's own config (README.md:168-170: "the client's own
   config is READ to discover which HTTPS upstream hosts it talks to")
   plus BILI_MITM_DOMAINS env (bundle line 48636, 66599) and
   --mitm-domain flag (README.md:183). Everything else is blind-tunnel
   ("blind TCP, not decrypted", bundle ~58110). app.lobehub.com is in
   NONE of these lists -- pointing HTTPS_PROXY at bili from curl would
   just tunnel it un-decompressed unless the domain were added.

4. Responses API shape: recognized (bundle line 59535 and 60600:
   inferWireProtocol maps paths ending /responses to protocol
   "responses"; adapters at 48398-50110 parse input_text/output_text
   parts). So a MITM'd Responses payload would not be mangled -- but
   shape support does not create a conversation to compress.

## Q3: Are the other legs covered?

- Delegated sessions (bili omp): YES, already compressed. Both
  launch-session.sh (automation/lib/launch-session.sh:42-53:
  "timeout -> bili -> omp", bctx_bin=$(command -v bili)) and the
  operator's fish wrappers (omp.fish/pi.fish = command bili omp --)
  route omp sessions through bili launcher mode. omp session
  transcripts are client-side conversation history -> exactly what
  bili plugin-mode compression folds. No action needed.
- kimi leg: NO help. automation/lib/model.sh:296-316 + _kimi_body:
  single-turn chat/completions, messages = [user only]. Same story:
  no client-side history exists; nothing to fold. (Kimi's own gateway
  prompt is server-side, same as LobeHub.)
- opencode-go leg: NO help, same reason -- stateless single-turn
  chat calls carry only the prompt.

## Q4: Gotchas (if anyone wires bili onto arbitrary curl legs anyway)

- CA trust for curl: NODE_EXTRA_CA_CERTS is Node-only. curl reads
  CURL_CA_BUNDLE (or --cacert). bili ships a combined bundle at
  ~/.local/share/billion-context/ca/combined-ca.pem (bundle: caDir =
  XDG_DATA_HOME/.local/share + billion-context + /ca, COMBINED_CA_FILE
  at bundle lines 47579/47595/52500-52524; file is created lazily by
  ensureRootCA on first MITM); the launcher armors
  node clients via NODE_EXTRA_CA_CERTS (line 65778) and codex/trae via
  SSL_CERT_FILE (line 65784, README.md:178-182) -- there is NO
  curl/python armoring in the launcher; it would be manual:
    HTTPS_PROXY=http://127.0.0.1:<bili-port>
    CURL_CA_BUNDLE=<combined-ca.pem>
    BILI_MITM_DOMAINS=app.lobehub.com   # else blind tunnel, no compression
- Payload shape after MITM: preserved. bili recognizes the Responses
  path (protocol "responses") and forwards model/input/max_output_tokens
  untouched; unknown shapes are forwarded verbatim ("forwarding raw
  body verbatim", bundle ~59550). Risk is low -- but pointless here.
- MITM'd HTTPS + long completions adds a proxy hop; Cloudflare 524 is
  server-to-origin, a client-side hop changes nothing about it.

## Hypothetical minimal wiring (for the record -- NOT recommended)

If bili DID have anything to compress on a curl leg, the whole wiring
is three env vars in lobehub_chat's _post_chat call site
(automation/lib/model.sh:390-391):

    export HTTPS_PROXY=http://127.0.0.1:8787
    export CURL_CA_BUNDLE="$HOME/.local/share/billion-context/ca/combined-ca.pem"
    export BILI_MITM_DOMAINS=app.lobehub.com   # before starting bili

and bili must already be running (bili, or any bili omp session's
spawned proxy). No model.sh code change. Recording this only because
the same three lines WOULD apply to any future multi-turn client-side
leg (e.g., a chat-completions agent with a real messages history).

## The real action

The limiter is LobeHub-side, not client-side: slim the hngh agent's
28.6k-token system prompt in the LobeHub agent config (agent
agt_6sB8IcJhaTg6). That cuts per-call latency/524 exposure and the
input-token burn on every one of the ~4,000+ monthly GLM quota calls.
bili's quota burn on omp sessions is already handled by bili omp.
