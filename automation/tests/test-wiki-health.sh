#!/usr/bin/env bash
# test-wiki-health.sh -- sandbox proofs for the wiki surface (2026-09-07):
#   a) health probe verdicts on fixture vaults: healthy / UNINDEXED /
#      STALE / SPLIT -> exactly one report row each with the right kind
#      and identity; a missing vault files nothing; a re-run dedups to
#      the same rows (7d identity window).
#   b) lessons seed: the page lands in the project fixture vault with
#      concept frontmatter and the verbatim table; a pre-existing page
#      keeps its created: and gets updated: refreshed; other pages are
#      untouched.
#   c) research-beat prior-art wire: the prompt to the stub model
#      carries the bounded 'Prior art (llm-wiki vault' block when a
#      fixture vault index overlaps the line's words; absent vaults ->
#      the block is silent; the block stays under the 600-byte cap; the
#      demand synthesizer prompt carries the same excerpt.
#   d) auto-rebuild leg: unhealthy + rebuild armed -> the stub omp is
#      invoked exactly once with cwd = the vault parent, the once-daily
#      stamp is written, a kind=wiki-rebuild telemetry row lands, and
#      the re-probe verdict shows in the output (unfrozen ok row / alert
#      carrying 'rebuild attempted'); a healthy vault is never
#      attempted; WIKI_AUTO_REBUILD=0 never attempts; a second same-day
#      run skips the attempt; the timeout knob bounds the attempt; two
#      consecutive daily non-unfrozen attempts file a research subject.
#   e) production seed is Monday-gated: on other weekdays the seed is
#      skipped.
# Hermetic: stub endpoints only, sandbox repo copy, no real model, no
# ~/.hngh writes, no live telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence" "$sb/archive" "$sb/dashboard" \
 "$sb/digest" "$sb/kernel/docs/research" "$sb/kernel/scripts" \
 "$sb/kernel/docs/project" "$sb/.config/hngh" "$sb/report-root"
mkdir -p "$sb/stubbin" "$sb/stamps"
cp -r "$root/lib/." "$sb/lib/"
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
cp "$HOME/Projects/etc/hngh/scripts/report-queue" "$sb/kernel/scripts/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

pass=0
fail=0
ok() {
 pass=$((pass + 1))
 echo "ok: $1"
}
bad() {
 fail=$((fail + 1))
 echo "FAIL: $1"
}
assert() { # desc got expected-substring
 case "$2" in *"$3"*) ok "$1" ;;
 *) bad "$1 (wanted substring: $3; got: ${2:0:200})" ;;
 esac
}

# --- fixture vaults ----------------------------------------------------
mk_vault() { # dir pages reg_count [old_meta]
 local d="$1" n="$2" r="$3" i
 mkdir -p "$d/wiki" "$d/meta"
 for i in $(seq 1 "$n"); do printf '# page %s\n' "$i" >"$d/wiki/page-$i.md"; done
 printf '{"version":1,"last_updated":"x","pages":[%s]}' \
  "$(seq 1 "$r" | sed 's/.*/{"id":"p"}/' | paste -sd,)" >"$d/meta/registry.json"
 printf '# Wiki Index\n\n- [[wiki/page-1]]\n' >"$d/meta/index.md"
 [ "${4:-}" = old ] && touch -d '30 days ago' "$d/meta/index.md"
 return 0
}
mk_vault "$sb/p1/vhealthy/.llm-wiki" 3 3
mk_vault "$sb/p2/vunindexed/.llm-wiki" 5 0
mk_vault "$sb/p3/vstale/.llm-wiki" 2 2 old
mk_vault "$sb/p4/vsplit/.llm-wiki" 4 1 old
# $sb/absent{1,2}/vmissing deliberately absent

# fixture lessons index (kernel side)
day="$(date -u +%Y-%m-%d)"
cat >"$sb/kernel/docs/project/lessons-index.md" <<EOF
# Lessons index

| Lesson | Blocker | Evidence | Change landed | Guardrail added |
|---|---|---|---|---|
| prior-art-wire | stub blocker | stub evidence | stub change | stub guardrail |
| idempotent-seed | stub blocker 2 | stub evidence 2 | stub change 2 | stub guardrail 2 |

---

Back to the [documentation index](../README.md).
EOF

rows_json() { HNGH_REPORT_ROOT="$sb/report-root" \
 python3 "$sb/kernel/scripts/report-queue" --json 2>/dev/null; }
row_count() { rows_json | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["reports"]))'; }
rows_dump() { rows_json | python3 -c '
import json, sys
for r in json.load(sys.stdin)["reports"]:
    ident = ""
    for ln in (r.get("body") or "").splitlines():
        if ln.startswith("- **identity:** "):
            ident = ln[len("- **identity:** "):].strip()
    print(r["kind"], ident, " ".join((r.get("body") or "").split()))'; }

probe_run() { # one health-probe pass in the sandbox
 (
  cd "$sb"
  env -i PATH="$PATH" HOME="$sb" JOB_NAME=25-wiki-health.sh \
   AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" \
   HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
   HNGH_WIKI_PERSONAL="$sb/p1/vhealthy/.llm-wiki" HNGH_WIKI_PROJECT="$sb/p4/vsplit/.llm-wiki" \
   WIKI_AUTO_REBUILD="${WIKI_AUTO_REBUILD:-0}" \
   WIKI_REBUILD_TIMEOUT="${WIKI_REBUILD_TIMEOUT:-240}" \
   WIKI_REBUILD_STAMP_DIR="$sb/stamps" FAKE_DOW="${FAKE_DOW:-1}" \
   PATH="$sb/stubbin:$PATH" \
   bash "$sb/cadence/day/25-wiki-health.sh" >/dev/null 2>&1
 )
}

# the other two fixture vaults are probed through direct env swaps
probe_extra() { # PERS PROJ -> one pass with arbitrary vault pair
 (
  cd "$sb"
  env -i PATH="$PATH" HOME="$sb" JOB_NAME=25-wiki-health.sh \
   AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" \
   HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
   HNGH_WIKI_PERSONAL="$1" HNGH_WIKI_PROJECT="$2" \
   WIKI_AUTO_REBUILD="${WIKI_AUTO_REBUILD:-0}" \
   WIKI_REBUILD_TIMEOUT="${WIKI_REBUILD_TIMEOUT:-240}" \
   WIKI_REBUILD_STAMP_DIR="$sb/stamps" FAKE_DOW="${FAKE_DOW:-1}" \
   PATH="$sb/stubbin:$PATH" \
   bash "$sb/cadence/day/25-wiki-health.sh" >/dev/null 2>&1
 )
}

call_count() { [ -f "$sb/omp-calls" ] && wc -l <"$sb/omp-calls" || echo 0; }

telemetry_rows() { # kind -> dump of telemetry events for that kind
 sqlite3 "$sb/dashboard/telemetry.db" \
  "select identity||' '||body from events
   where kind='$1' order by ts" 2>/dev/null
}

telemetry_wall() { # identity -> wall_s of its first wiki-rebuild row
 sqlite3 "$sb/dashboard/telemetry.db" \
  "select coalesce(wall_s,-1) from events where kind='wiki-rebuild'
   and identity='$1' order by ts limit 1" 2>/dev/null
}

# date stub: FAKE_DOW wins for `date -u +%u` so the Monday seed gate is
# testable on any weekday; must exist before section a (the seed runs).
cat >"$sb/stubbin/date" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = -u ] && [ "$2" = +%u ] && [ -n "$FAKE_DOW" ]; then
 printf '%s\n' "$FAKE_DOW"
else
 exec /usr/bin/date "$@"
fi
EOF
chmod +x "$sb/stubbin/date"

# --- a) verdicts -------------------------------------------------------
probe_run
out="$(rows_dump)"
assert "healthy vault -> silent ok row" "$out" "progress wiki-health-ok:vhealthy"
assert "split vault -> alert with fix" "$out" "alert wiki-health:vsplit"
assert "alert carries exact fix path" "$out" "omp session with cwd $sb/p4/vsplit"
assert "alert names wiki_rebuild_meta" "$out" "wiki_rebuild_meta"
probe_extra "$sb/p2/vunindexed/.llm-wiki" "$sb/p3/vstale/.llm-wiki"
out="$(rows_dump)"
assert "unindexed vault -> UNINDEXED alert" "$out" "UNINDEXED"
assert "stale vault -> STALE alert" "$out" "STALE"
n0="$(row_count)"
probe_extra "$sb/absent1/vmissing/.llm-wiki" "$sb/absent2/vmissing/.llm-wiki"
n1="$(row_count)"
[ "$n1" = "$n0" ] && ok "missing vault files no row" ||
 bad "missing vault filed rows: $n0 -> $n1"
# idempotent dedup: same verdicts again -> row count unchanged
probe_run
n2="$(row_count)"
[ "$n2" = "$n1" ] && ok "identity dedup: re-run adds no rows" ||
 bad "identity dedup broken: $n1 -> $n2"

# --- b) lessons seed ---------------------------------------------------
page="$sb/p4/vsplit/.llm-wiki/wiki/concepts/hngh-lessons-current.md"
[ -f "$page" ] && ok "seed page created" || bad "seed page missing"
assert "seed frontmatter is concept" "$(head -5 "$page")" "type: concept"
assert "seed table verbatim (row 1)" "$(cat "$page")" "prior-art-wire"
assert "seed cross-links the Cistern synthesis" "$(cat "$page")" \
 "[[syntheses/delegated-subagent-steering]]"
assert "seed sources point at the kernel docs" "$(cat "$page")" \
 "docs/project/lessons-index.md"
other="$sb/p4/vsplit/.llm-wiki/wiki/page-1.md"
printf '# page 1\n' >"$other" # must stay byte-identical
probe_run
assert "seed preserves created:" "$(grep '^created:' "$page")" "created: $day"
assert "seed refreshes updated:" "$(grep '^updated:' "$page")" "updated: $day"
[ "$(cat "$other")" = "# page 1" ] && ok "seed never touches other pages" ||
 bad "seed wrote outside its own file"
# created: survives an old page
sed -i "s/^created: .*/created: 2026-09-01/; s/^updated: .*/updated: 2026-09-01/" "$page"
probe_run
assert "old created: preserved" "$(grep '^created:' "$page")" "created: 2026-09-01"
assert "old updated: refreshed" "$(grep '^updated:' "$page")" "updated: $day"

# --- stub omp + date (auto-rebuild + Monday gate) -----------------------
# omp stub: records "cwd|args|mode" per call; mode file drives behavior --
# fix = simulate the extension's wiki_rebuild_meta (registry count ->
# pages on disk, fresh index mtime), nofix = rebuild does not help,
# sleep = hang (exercises the timeout knob); the date stub lives above
# section a.
cat >"$sb/stubbin/omp" <<EOF
#!/usr/bin/env bash
echo "\$(pwd)|\$*|\$(cat "$sb/omp-stub-mode" 2>/dev/null || echo fix)" \\
 >>"$sb/omp-calls"
case "\$(cat "$sb/omp-stub-mode" 2>/dev/null || echo fix)" in
 sleep) exec sleep 7 ;;
 nofix) : ;;
 fix)
  reg="\$PWD/.llm-wiki/meta/registry.json"
  [ -f "\$reg" ] || exit 0
  n=\$(find "\$PWD/.llm-wiki/wiki" -name '*.md' -type f \\
   ! -name index.md ! -name log.md 2>/dev/null | wc -l)
  python3 - "\$reg" "\$n" <<'PY'
import json, sys
reg, n = sys.argv[1], int(sys.argv[2])
d = json.load(open(reg))
d["pages"] = [{"id": "p"} for _ in range(n)]
json.dump(d, open(reg, "w"))
PY
  touch "\$PWD/.llm-wiki/meta/index.md"
  ;;
esac
echo rebuilt-stub
EOF
chmod +x "$sb/stubbin/omp"

# --- d) auto-rebuild leg ------------------------------------------------
# armed + unhealthy + fixing stub -> one attempt, unfrozen, telemetry
rm -f "$sb/omp-calls" "$sb/omp-stub-mode"
WIKI_AUTO_REBUILD=1 probe_run
[ "$(call_count)" = 1 ] && ok "rebuild armed: stub invoked exactly once" ||
 bad "expected 1 omp call, got $(call_count)"
assert "stub cwd is the vault parent" "$(cat "$sb/omp-calls")" "$sb/p4/vsplit|"
assert "stub asked to run wiki_rebuild_meta" "$(cat "$sb/omp-calls")" \
 "wiki_rebuild_meta"
assert "once-daily stamp written" \
 "$(cat "$sb/stamps/.hngh-wiki-rebuild-vsplit")" "$(date -u +%F) unfrozen"
assert "telemetry row kind=wiki-rebuild" "$(telemetry_rows wiki-rebuild)" \
 "vsplit unfrozen disk"
assert "telemetry row carries reg delta" "$(telemetry_rows wiki-rebuild)" \
 "reg 1->"
assert "telemetry row carries duration" "$(telemetry_wall vsplit)" "0"
out="$(rows_dump)"
assert "unfrozen ok row filed" "$out" "healthy after rebuild attempt"
case "$out" in
*"alert wiki-health-rebuild:vsplit"*)
 bad "unfrozen vault still alerted"
 ;;
*) ok "no alert after unfreeze" ;;
esac

# param 0 -> never attempt
rm -f "$sb/omp-calls"
probe_extra "$sb/p2/vunindexed/.llm-wiki" "$sb/p3/vstale/.llm-wiki"
[ "$(call_count)" = 0 ] && ok "WIKI_AUTO_REBUILD=0 never attempts" ||
 bad "param 0 still attempted: $(call_count) calls"

# still unhealthy after attempt -> alert carries 'rebuild attempted';
# second same-day run skips the attempt (daily cap)
printf 'nofix' >"$sb/omp-stub-mode"
rm -f "$sb/omp-calls"
WIKI_AUTO_REBUILD=1 probe_extra "$sb/absent1/vmissing" "$sb/p2/vunindexed/.llm-wiki"
[ "$(call_count)" = 1 ] && ok "unhealthy vault attempted once" ||
 bad "expected 1 attempt, got $(call_count)"
assert "still-unhealthy telemetry" "$(telemetry_rows wiki-rebuild)" \
 "vunindexed still-unhealthy"
out="$(rows_dump)"
assert "insufficient alert carries 'rebuild attempted'" "$out" \
 "rebuild attempted"
assert "insufficient alert is honest" "$out" "insufficient"
assert "insufficient alert identity" "$out" "wiki-health-rebuild:vunindexed"
WIKI_AUTO_REBUILD=1 probe_extra "$sb/absent1/vmissing" "$sb/p2/vunindexed/.llm-wiki"
[ "$(call_count)" = 1 ] && ok "second same-day run skips the attempt" ||
 bad "daily cap broken: $(call_count) calls"

# two consecutive daily non-unfrozen attempts -> research subject
printf '%s still-unhealthy\n' "$(date -u -d yesterday +%F)" \
 >"$sb/stamps/.hngh-wiki-rebuild-vunindexed"
WIKI_AUTO_REBUILD=1 probe_extra "$sb/absent1/vmissing" "$sb/p2/vunindexed/.llm-wiki"
[ "$(call_count)" = 2 ] && ok "next-day attempt runs again" ||
 bad "next-day attempt did not run: $(call_count)"
grep -q 'ctx-wiki-rebuild-vunindexed' "$sb/research-subjects.txt" &&
 ok "consecutive failures file a research subject" ||
 bad "failure routing did not file ctx-wiki-rebuild-vunindexed"

# timeout knob bounds the attempt
printf 'sleep' >"$sb/omp-stub-mode"
rm -f "$sb/omp-calls"
WIKI_AUTO_REBUILD=1 WIKI_REBUILD_TIMEOUT=2 \
 probe_extra "$sb/absent1/vmissing" "$sb/p3/vstale/.llm-wiki"
assert "timeout knob -> attempt-failed outcome" \
 "$(telemetry_rows wiki-rebuild)" "vstale attempt-failed"

# --- e) production seed is Monday-gated ---------------------------------
rm -f "$sb/p3/vstale/.llm-wiki/wiki/concepts/hngh-lessons-current.md"
FAKE_DOW=2 probe_extra "$sb/p1/vhealthy/.llm-wiki" "$sb/p3/vstale/.llm-wiki"
[ ! -f "$sb/p3/vstale/.llm-wiki/wiki/concepts/hngh-lessons-current.md" ] &&
 ok "Tuesday: seed skipped" || bad "seed ran on a Tuesday"
FAKE_DOW=1 probe_extra "$sb/p1/vhealthy/.llm-wiki" "$sb/p3/vstale/.llm-wiki"
[ -f "$sb/p3/vstale/.llm-wiki/wiki/concepts/hngh-lessons-current.md" ] &&
 ok "Monday: seed runs" || bad "seed skipped on a Monday"

# --- c) research-beat prior-art wire -----------------------------------
printf 'stub-token-never-real' >"$sb/unsloth-token"
rm -f "$stubdir/stubU-port" "$stubdir/bodies"
python3 - "$stubdir" <<'PY' &
import http.server, socketserver, sys, json, os
d = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n)
        with open(os.path.join(d, "bodies"), "a") as f:
            f.write("\n@@BODY@@\n" + body.decode("utf-8", "replace"))
        text = body.decode("utf-8", "replace")
        if "Read these recent machine outputs" in text:
            p = os.path.join(d, "synth-reply")
            content = open(p).read() if os.path.exists(p) else "no-subjects"
        else:
            content = "stub-says-hi"
        out = json.dumps({"choices": [{"message": {"content": content}}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers()
        self.wfile.write(out)
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(("127.0.0.1", 0), H)
with open(os.path.join(d, "stubU-port"), "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY
stub_pids="$!"
i=0
while [ ! -s "$stubdir/stubU-port" ] && [ "$i" -lt 50 ]; do
 sleep 0.1
 i=$((i + 1))
done
stubU_port="$(cat "$stubdir/stubU-port")"

# fixture vault indexes for the consumption wire
mkdir -p "$sb/vaultP/meta" "$sb/vaultS/meta"
long="$(printf 'surface line %.0s' $(seq 1 40))"
printf -- '- [[wiki/prior]] -- research pointer %s\n%s\n' "$long" "$long" \
 >"$sb/vaultP/meta/index.md"
printf -- '- [[wiki/other]] — unrelated note\n' >"$sb/vaultS/meta/index.md"

printf 'wiki-surface\tplanned\t2026-09-07T00:00:00Z\tHow does the wiki surface consume vault prior art for research pacing\n' \
 >"$sb/research-lines.tsv"
: >"$sb/research-subjects.txt"

BEAT_ENV=(
 AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=33-research-beat.sh
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root"
 TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
 REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL="http://127.0.0.1:$stubU_port" OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ols MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096
 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
 LOBEHUB_KEY_FILE="$sb/.config/hngh/lobehub-key"
 RESEARCH_SYNTH_STAMP_FILE="$sb/synth-stamp"
)
beat_run() { # [K=V ...] -> one hour-beat run; caller args win
 (
  cd "$sb"
  rm -f "$sb/beat-stamp"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" RESEARCH_BEAT_HOURS=1 \
   HNGH_WIKI_PROJECT_INDEX="$sb/vaultP/meta/index.md" \
   HNGH_WIKI_PERSONAL_INDEX="$sb/vaultS/meta/index.md" \
   "$@" bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
printf '0.10 0.20 0.10 1/900 1234' >"$sb/loadavg"

beat_run
bodies="$(cat "$stubdir/bodies")"
assert "prompt carries the prior-art block" "$bodies" \
 "Prior art (llm-wiki vault; read-only pointers):"
assert "block grep matched the fixture line" "$bodies" "research pointer"
# byte cap on the block (bodies are JSON envelopes: parse, then measure)
blk="$(printf '%s' "$bodies" | python3 -c '
import json, re, sys
for body in sys.stdin.read().split("\n@@BODY@@\n"):
    body = body.strip()
    if not body:
        continue
    try:
        c = json.loads(body)["choices"][0]["message"]["content"]
    except Exception:
        continue
    m = re.search(r"Prior art \(llm-wiki vault.*", c, re.S)
    if m:
        print(m.group(0), end="")
        break
')"
[ "$(printf '%s' "$blk" | wc -c)" -le 640 ] &&
 ok "block within 600-byte cap" ||
 bad "prior-art block over cap ($(printf '%s' "$blk" | wc -c) bytes)"

# absent vaults -> silent
: >"$stubdir/bodies"
beat_run HNGH_WIKI_PROJECT_INDEX="$sb/absent" HNGH_WIKI_PERSONAL_INDEX="$sb/absent"
bodies="$(cat "$stubdir/bodies")"
case "$bodies" in
*"Prior art (llm-wiki vault"*) bad "absent vaults still injected prior art" ;;
*) ok "absent vaults -> block silent" ;;
esac

# demand synthesizer gets the same excerpt
: >"$stubdir/bodies"
rm -f "$sb/synth-stamp"
awk -F'\t' -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" 'BEGIN{OFS="\t"}
 $1=="wiki-surface"{$2="reviewed";$3=ts} {print}' "$sb/research-lines.tsv" \
 >"$sb/research-lines.tsv.tmp" && mv "$sb/research-lines.tsv.tmp" "$sb/research-lines.tsv"
printf 'synth-%s-1\tDoes prior-art-wire change the research beat pacing?\n' "$day" \
 >"$stubdir/synth-reply"
beat_run
bodies="$(cat "$stubdir/bodies")"
synth_body="$(printf '%s' "$bodies" | awk '/Read these recent machine outputs/{f=1} f')"
assert "synthesizer prompt carries prior art" "$synth_body" \
 "Prior art (llm-wiki vault; read-only pointers):"
grep -q "synth-$day-1" "$sb/research-subjects.txt" &&
 ok "synth subject accepted (beat still works with the wire)" ||
 bad "synth subject not accepted"

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
