#!/usr/bin/env bash
# test-news-articles.sh -- the generated-newspaper lane, hermetic.
#
# Operator directive 2026-09-12: articles generated from the day's top
# digest items through the SAME model_call seam the research beat uses
# (stubbed local unsloth leg answers; stubK-style reply), committed under
# docs/articles/<date>/, image budget <= 3 per edition via a stub
# imagegen, fail-closed when the chain is down, and the print front page
# renders >= 3 columns with the article body inline.
# Hermetic: source URLs use https://127.0.0.1:1 (the port guard refuses
# without a request); no real endpoints, no real keys, sandbox repo.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
DATE=2026-09-12
FAIL_DIGEST="## 0400 $DATE
_sources: gdelt | model: procedural ranking_
CRITICAL: FIGHT TESTLAND: Fixture war escalates in region (https://127.0.0.1:1/war)
NOTABLE: Fixture aid convoy arrives (https://127.0.0.1:1/aid)
CONTEXT: Fixture talks resume quietly (https://127.0.0.1:1/talks)
"
setup() { # -> sandbox: lib, jobs, digest, fixture digest
 rm -rf "$sb" && mkdir -p "$sb/lib" "$sb/jobs" "$sb/state" "$sb/archive" \
  "$sb/dashboard" "$sb/digest" "$sb/repo/docs"
 cp -r "$root/lib/." "$sb/lib/"
 cp "$root/jobs/news-articles.py" "$root/jobs/digest-html.py" "$sb/jobs/"
 printf '%s' "$FAIL_DIGEST" >"$sb/digest/$DATE.md"
 mkdir -p "$sb/repo/automation/digest"
 printf '%s' "$FAIL_DIGEST" >"$sb/repo/automation/digest/$DATE.md"
 printf 'newspaper-articles-cap\t%s\ttest\ttest\n' "${1:-6}" \
  >"$sb/cadence-params.tsv"
 : >"$sb/STATE.md"
 printf 'stub-token-never-real' >"$sb/unsloth-token"
}
run_gen() { # [NEWS_ARTICLES_FETCH=v] -> stdout (article paths)
 local kv
 (
  export HNGH_AUTOMATION_ROOT="$sb" HOME="$sb"
  export HNGH_REPO_ROOT="$sb/repo"
  export TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
  export UNSLOTH_URL="${UNSLOTH_URL:-http://127.0.0.1:$stubU_port}"
  export OLLAMA_URL=http://127.0.0.1:1 OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export DECK_URL="" MODEL_MAX_TOKENS=1024
  export NEWS_ARTICLES_MODEL_CMD='. "'"$sb"'/lib/model.sh"; model_call 1024'
  unset KIMI_AI_KEY KIMI_MODEL KIMI_URL DECK_MODEL MODEL_PIN
  for kv in "$@"; do export "$kv"; done
  python3 "$root/jobs/news-articles.py" "$DATE"
 )
}
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

fails=0
. "$root/tests/stub-lib.sh"
export STUB_CONTENT="Wire dispatch: the fixture story developed overnight. Casualties unverified per source. The machines kept printing."
stub_start stubU # the local unsloth leg answers (research-beat seam)
stubU_port="$(cat "$stubdir/stubU-port")"
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT

# --- 1. generation from fixture items through the real model_call seam.
setup 6
out="$(run_gen "MODEL_PIN=local" | sort)"
ck "cap 6, 3 items: three articles committed" "3" "$(echo "$out" | wc -l)"
ck "articles committed under docs/articles/<date>" \
 "$sb/repo/docs/articles/$DATE/fight-testland-fixture-war-escalates.md" \
 "$(echo "$out" | grep war | cut -d/ -f1-)"
ck "model seam used the stubbed local leg" "unsloth:stub-model" \
 "$(cat "$sb/tmp-modelused.txt" 2>/dev/null)"
ck "stub leg hit once per article" "3" "$(wc -l <"$stubdir/stubU-hits")"
art="$(cat "$sb/repo/docs/articles/$DATE/fight-testland-fixture-war-escalates.md")"
ck "metadata join comment present" "1" \
 "$(printf '%s' "$art" | grep -c 'digest_headline' || true)"
ck "join key is the exact split-headline" "1" \
 "$(printf '%s' "$art" | grep -cF \
  '"digest_headline": "FIGHT TESTLAND: Fixture war escalates in region (https://127.0.0.1:1/war)"' || true)"
ck "article body is the stub reply" "1" \
 "$(printf '%s' "$art" | grep -c 'machines kept printing' || true)"
ck "attribution footer present" "1" \
 "$(printf '%s' "$art" | grep -c 'hngh wire desk' || true)"
ck "dead source URL -> wire provenance" "1" \
 "$(printf '%s' "$art" | grep -c 'wire data alone' || true)"

# --- 2. cap row: cap=1 with 3 ranked items -> exactly one article.
setup 1
out="$(run_gen "MODEL_PIN=local" | wc -l)"
ck "cap=1 enforced against ranked items" "1" "$out"

# --- 3. chain down: fail-closed, zero articles, still exit 0.
setup 6
out="$(run_gen "MODEL_PIN=local" "UNSLOTH_URL=http://127.0.0.1:1" | wc -l)"
ck "model chain down: no article files (never fabricate)" "0" "$out"

# --- 4. fetch seam off -> wire provenance without any request.
setup 6
run_gen "MODEL_PIN=local" "NEWS_ARTICLES_FETCH=0" >/dev/null
ck "fetch off: all three wire articles land" "3" \
 "$(ls "$sb/repo/docs/articles/$DATE"/*.md 2>/dev/null | wc -l)"

# --- 5. image budget: 3 articles -> exactly 3 imagegen calls.
setup 6
mkdir -p "$sb/imgout"
imgstub="$sb/stub-imagegen.sh"
cat >"$imgstub" <<'EOF'
#!/usr/bin/env bash
out="$6/img-$(($(wc -l <"$IMGSTUB_CALLS") + 1)).png"
echo "$out" >>"$IMGSTUB_CALLS"
echo "imagegen: wrote $out (stub)"
EOF
chmod +x "$imgstub"
out="$(IMGSTUB_CALLS="$sb/imgcalls" IMGSTUB_DIR="$sb/imgout" \
 run_gen "MODEL_PIN=local" "NEWS_ARTICLES_IMAGEGEN_CMD=$imgstub" | wc -l)"
ck "image budget: exactly 3 stub imagegen calls for 3 articles" "3" \
 "$(wc -l <"$sb/imgcalls")"
ck "every illustrated article references its image" "3" \
 "$(grep -l '"image": "docs/' "$sb/repo/docs/articles/$DATE/"*.md | wc -l)"

# --- 6/7. the print front page + public md edition (python inline).
python3 - "$root" "$sb" "$DATE" <<'PY' || fails=$((fails + 1))
import importlib.machinery, importlib.util, os, sys
root, sb, day = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location(
    "dh", os.path.join(sb, "jobs", "digest-html.py"))
dh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dh)
dh.DIGESTS = os.path.join(sb, "digest")
dh.TELEMETRY = os.path.join(sb, "no.db")
dh.ARTICLES = os.path.join(sb, "repo", "docs", "articles")
dh.MEDIA = os.path.join(sb, "repo", "docs", "media")
page = dh.render_page(os.path.join(sb, "digest", day + ".md"),
                      dh.DIGESTS, dh.TELEMETRY)
bad = 0
def ck(desc, ok):
    global bad
    print(("ok: " if ok else "FAIL: ") + desc); bad += 0 if ok else 1
ck("style carries column-count:3 front page",
   "column-count:3" in dh.STYLE)
ck("2-col break >=1280/800, 1-col below",
   "@media(max-width:1279px){.cols{column-count:2}}" in dh.STYLE
   and "@media(max-width:799px){.cols{column-count:1}}" in dh.STYLE)
ck("folio furniture (date/edition/page)",
   "edition no." in page and "page 1" in page)
ck("article body renders in the edition", "machines kept printing" in page)
ck("extended story carries the dateline convention",
   'class="dateline"' in page)
ck("attribution footer renders", "hngh wire desk" in page)
raise SystemExit(1 if bad else 0)
PY
python3 - "$root" "$sb" "$DATE" <<'PY' || fails=$((fails + 1))
import importlib.machinery, importlib.util, os, sys
loader = importlib.machinery.SourceFileLoader(
    "dp", os.path.join(sys.argv[1], "jobs", "digest-public.py"))
spec = importlib.util.spec_from_loader("dp", loader)
dp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dp)
text = dp.render_page(sys.argv[3], os.path.join(sys.argv[2], "repo"))
ok = "Extended article: docs/articles/" in text
print(("ok: " if ok else "FAIL: ") + "public edition links the article")
raise SystemExit(0 if ok else 1)
PY

echo "test-news-articles: $fails failure(s)"
[ "$fails" -eq 0 ]
