#!/usr/bin/env bash
# test-worker-render.sh — fixture-backed tests for the viz-transport slice.
# Hermetic: no model, no network. Helper .mjs files read the module URL
# from $RB_URL at runtime, so the heredocs are fully quoted (no shell or
# backtick expansion inside). Exit 0 on pass, 1 on any failure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
fails=0
pass() { echo "ok: $1"; }
fail() {
 echo "FAIL: $1"
 fails=$((fails + 1))
}
. "$HERE/../lib/launch-jcode.sh"
export RB_URL="file://$HERE/../jcode/render-blocks.mjs"
RB="$HERE/../jcode/render-blocks.mjs"

node --check "$RB" 2>/dev/null && pass "render-blocks parses" || fail "render-blocks parses"

cat >"$SCRATCH/check-extract.mjs" <<'EOF'
const { extractRenderBlocks: x } = await import(process.env.RB_URL);
const t = ['hello', '```hngh-render chart', 'a: 1', '```', 'mid',
 '```hngh-render chart', 'a: 1', '```',
 '```hngh-render unclosed', 'zzz'].join('\n');
const b = x(t);
if (b.length !== 1) { console.error('blocks=' + b.length); process.exit(1); }
if (b[0].kind !== 'chart' || b[0].payload !== 'a: 1') process.exit(2);
if (x(null).length !== 0 || x(42).length !== 0) process.exit(3);
EOF
node "$SCRATCH/check-extract.mjs" &&
 pass "extract blocks/dedupe/fail-closed" || fail "extract blocks/dedupe/fail-closed"

cat >"$SCRATCH/check-roundtrip.mjs" <<'EOF'
const { buildEnvelope: b, formatRenderSection: f, parseRenderSection: p } = await import(process.env.RB_URL);
const turn = { text: 'hi\n```hngh-render table\nx|y\n```\ntail', toolCalls: [{name:'Read',output:'ok'}], usage: {input:3,output:5} };
const env = b(turn);
if (env.v !== 1 || env.kind !== 'turn-render') process.exit(1);
if (env.blocks.length !== 1 || env.blocks[0].kind !== 'table') process.exit(2);
const log = 'hi\ntail' + f(env);
const out = p(log);
if (!out.text.includes('tail') || out.text.includes('HNGH-RENDER')) process.exit(3);
if (out.envelopes.length !== 1 || out.envelopes[0].blocks[0].payload !== 'x|y') process.exit(4);
if (env.text !== undefined) process.exit(5);
EOF
node "$SCRATCH/check-roundtrip.mjs" &&
 pass "envelope round-trip" || fail "envelope round-trip"

cat >"$SCRATCH/check-parseclosed.mjs" <<'EOF'
const { parseRenderSection: p, RENDER_BEGIN: B, RENDER_END: E } = await import(process.env.RB_URL);
const r1 = p('a\n' + B + '\nnot json{{{\n' + E + '\nafter');
if (r1.envelopes.length !== 1 || r1.envelopes[0].ok !== false) process.exit(1);
if (!r1.text.includes('after') || r1.text.includes('HNGH-RENDER')) process.exit(2);
const r2 = p('keep\n' + B + '\ndangling');
if (!r2.text.includes('dangling')) process.exit(3);
EOF
node "$SCRATCH/check-parseclosed.mjs" &&
 pass "parse fails closed" || fail "parse fails closed"

cat >"$SCRATCH/check-sidechannel.mjs" <<'EOF'
const { writeSideChannel: w } = await import(process.env.RB_URL);
const fd = Number(process.argv[2]);
const expect = process.argv[3] === 'true';
if (w({v:1,kind:'turn-render',blocks:[],tools:[]}, fd) !== expect) process.exit(1);
EOF
# "closed fd" is probed at 109, not 9: node >= 26 recycles freed LOW fd
# numbers for its own internals (pipes, mmap'd files) before user code
# runs, so a shell-closed fd 9 is no longer closed from node's view —
# writing into a recycled mmap'd file region bus-errors the process
# (SIGBUS, uncatchable). A high fd number stays genuinely closed and
# exercises the real contract: not open -> false, never fatal.
node "$SCRATCH/check-sidechannel.mjs" 109 false 109>&- &&
 pass "side-channel closed-fd fails soft" || fail "side-channel closed-fd fails soft"
node "$SCRATCH/check-sidechannel.mjs" 3 true 3>"$SCRATCH/fd3.json" &&
 pass "side-channel fd3 write" || fail "side-channel fd3 write"
python3 -c "import json;d=json.load(open('$SCRATCH/fd3.json'));assert d['v']==1" &&
 pass "side-channel JSON valid" || fail "side-channel JSON valid"

cat >"$SCRATCH/stub-render.mjs" <<'EOF'
const { buildEnvelope, formatRenderSection, writeSideChannel } = await import(process.env.RB_URL);
const turn = { text: 'stub turn text', toolCalls: [], usage: { input: 1, output: 1 } };
const env = buildEnvelope(turn);
process.stdout.write(turn.text + formatRenderSection(env));
writeSideChannel(env, 3);
EOF
export JCODE_PROMPT_FILE="$SCRATCH/prompt.txt" JCODE_LOG="$SCRATCH/out.log"
export JCODE_WORKER_BIN="$SCRATCH/stub-render.mjs"
export JCODE_WORKER_RENDER=both JCODE_RENDER_LOG="$SCRATCH/render.jsonl"
printf 'stub prompt\n' >"$JCODE_PROMPT_FILE"
launch_jcode_worker && pass "stub turn rc 0" || fail "stub turn rc 0"
grep -q "stub turn text" "$JCODE_LOG" && pass "stub text in log" || fail "stub text in log"
grep -q "HNGH-RENDER-BEGIN" "$JCODE_LOG" && pass "markers in log" || fail "markers in log"
python3 -c "import json;d=json.load(open('$SCRATCH/render.jsonl'));assert d['kind']=='turn-render'" &&
 pass "fd3 capture valid" || fail "fd3 capture valid"
unset JCODE_WORKER_RENDER JCODE_RENDER_LOG

printf 'stub prompt\n' >"$JCODE_PROMPT_FILE"
launch_jcode_worker && pass "default mode rc 0" || fail "default mode rc 0"

echo "----"
[ "$fails" -eq 0 ] && echo "PASS" || {
 echo "FAIL ($fails)"
 exit 1
}
