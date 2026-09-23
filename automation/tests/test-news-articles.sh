#!/usr/bin/env bash
# test-news-articles.sh -- the generated-newspaper lane, hermetic.
#
# Operator directive 2026-09-12: articles generated from the day's top
# digest items through the SAME model_call seam the research beat uses
# (stubbed local unsloth leg answers; stubK-style reply), committed under
# ~/.hngh/newspaper/<date>/articles/ (2026-09-13 userspace-home + paid-cost
# conversion: LOCAL leg only), image budget <= 3 per edition via a stub
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
  "$sb/dashboard" "$sb/digest" "$sb/repo/docs" \
  "$sb/home/archive/digest" "$sb/home/db"
 cp -r "$root/lib/." "$sb/lib/"
 cp "$root/jobs/news-articles.py" "$root/jobs/digest-html.py" "$sb/jobs/"
 printf '%s' "$FAIL_DIGEST" >"$sb/digest/$DATE.md"
 printf '%s' "$FAIL_DIGEST" >"$sb/home/archive/digest/$DATE.md"
 mkdir -p "$sb/repo/automation/digest"
 printf '%s' "$FAIL_DIGEST" >"$sb/repo/automation/digest/$DATE.md"
 printf 'newspaper-articles-cap\t%s\ttest\ttest\n' "${1:-6}" \
  >"$sb/cadence-params.tsv"
 : >"$sb/STATE.md"
 printf 'stub-token-never-real' >"$sb/unsloth-token"
 chmod 600 "$sb/unsloth-token" # mode-600 gate (unsloth-contexts seam)
}
run_gen() { # [NEWS_ARTICLES_FETCH=v] -> stdout (article paths)
 local kv
 (
  export HNGH_AUTOMATION_ROOT="$sb" HOME="$sb"
  export HNGH_REPO_ROOT="$sb/repo"
  export HNGH_NEWSPAPER_DIR="$sb/paper"
  export HNGH_HOME_DIR="$sb/home"
  export TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
  export UNSLOTH_URL="${UNSLOTH_URL:-http://127.0.0.1:$stubU_port}"
  export OLLAMA_URL=http://127.0.0.1:1 OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export HNGH_LOADCTX_PIN=0 # no /load POST: the stub counts one hit per article (2026-09-22 context lane)
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
ck "articles committed under newspaper/<date>/articles" \
 "$sb/paper/$DATE/articles/fight-testland-fixture-war-escalates.md" \
 "$(echo "$out" | grep war | cut -d/ -f1-)"
ck "model seam used the stubbed local leg" "unsloth:stub-model" \
 "$(cat "$sb/tmp-modelused.txt" 2>/dev/null)"
ck "stub leg hit once per article" "3" "$(wc -l <"$stubdir/stubU-hits")"
art="$(cat "$sb/paper/$DATE/articles/fight-testland-fixture-war-escalates.md")"
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
 "$(ls "$sb/paper/$DATE/articles"/*.md 2>/dev/null | wc -l)"

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
 "$(grep -l '"image": "media/' "$sb/paper/$DATE/articles/"*.md | wc -l)"

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
dh.ARTICLES = os.path.join(sb, "paper")
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
export HNGH_NEWSPAPER_DIR="$sb/paper"
export HNGH_HOME_DIR="$sb/home"
mkdir -p "$sb/home/archive/digest" "$sb/home/db"
cp "$sb/repo/automation/digest/$DATE.md" "$sb/home/archive/digest/"
python3 - "$root" "$sb" "$DATE" <<'PY' || fails=$((fails + 1))
import importlib.machinery, importlib.util, os, sys
loader = importlib.machinery.SourceFileLoader(
    "dp", os.path.join(sys.argv[1], "jobs", "digest-public.py"))
spec = importlib.util.spec_from_loader("dp", loader)
dp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dp)
text = dp.render_page(sys.argv[3], os.path.join(sys.argv[2], "repo"))
ok = "Extended article: fight-testland-fixture-war-escalates " \
     "(local edition only)" in text
print(("ok: " if ok else "FAIL: ") + "public edition links the article")
raise SystemExit(0 if ok else 1)
PY

# --- 8. no-echo guard: host-path tokens never ride the model prompt or
# the model REPLY (prompt-assembly audit 2026-09-16: digest/ledger/
# source text is host data; scrub at the build_prompt seam. Model-hygiene
# audit 2026-09-16: lib/model.sh sends a single user message with no
# system prompt on any leg, and the input-side scrub cannot stop a model
# from echoing a path it saw, inferred, or hallucinated -- so model_reply
# runs the same seam over the reply, and the prompt carries a no-paths
# house law. Fail-closed redaction both directions; pinned by the
# captured stub request bodies).
setup 6
PATHY_DIGEST="## 0400 $DATE
_sources: gdelt | model: procedural ranking_
CRITICAL: PATHLEAK TESTLAND: ~ vault breach noted in /tmp/vr-test-42 (https://127.0.0.1:1/leak)
"
printf '%s' "$PATHY_DIGEST" >"$sb/digest/$DATE.md"
printf '%s' "$PATHY_DIGEST" >"$sb/home/archive/digest/$DATE.md"
printf '%s' "$PATHY_DIGEST" >"$sb/repo/automation/digest/$DATE.md"
HNGH_AUTOMATION_ROOT="$sb" HNGH_HOME_DIR="$sb/home" \
 python3 - "$sb" <<'PY' || fails=$((fails + 1))
import importlib.machinery, importlib.util, os, sys
sb = sys.argv[1]
loader = importlib.machinery.SourceFileLoader(
    "na", os.path.join(sb, "jobs", "news-articles.py"))
spec = importlib.util.spec_from_loader("na", loader)
na = importlib.util.module_from_spec(spec)
spec.loader.exec_module(na)
bad = 0
def ck(desc, ok):
    global bad
    print(("ok: " if ok else "FAIL: ") + desc); bad += 0 if ok else 1
if hasattr(na, "scrub_paths"):
    sample = ("filed from ~/Projects/etc/hngh, notes at "
              "~/.hngh/newspaper/x.md, dump at /tmp/vr-test-42")
    scrubbed = na.scrub_paths(sample)
    ck("scrub_paths removes /home/... tokens", "/home/" not in scrubbed)
    ck("scrub_paths removes ~/.hngh tokens", "~/.hngh" not in scrubbed)
    ck("scrub_paths removes /tmp/... tokens", "/tmp/vr-test" not in scrubbed)
    ck("scrub_paths keeps ordinary prose", "notes at" in scrubbed)
    # regex-gap extension (2026-09-16 audit follow-up): credential
    # redact() emits tilde forms, so a pre-redacted finding line rides
    # build_prompt with ~/ at line start; bare /home //tmp (no trailing
    # segment) must also die; URLs keep their paths (hostnames are not
    # the operator's filesystem).
    pre_redacted = ("credential-health findings:\n"
                    "evidence-missing: kimi\n"
                    "~/.gnupg/private-keys-v1.d\n"
                    "ledger line ok")
    scrubbed2 = na.scrub_paths(pre_redacted)
    ck("tilde token redacted at line start (redact interplay)",
       "~/.gnupg" not in scrubbed2)
    bare = "cd /home alone or wrote /tmp then left"
    scrubbed3 = na.scrub_paths(bare)
    ck("bare /home token redacted", "/home" not in scrubbed3)
    ck("bare /tmp token redacted", "/tmp" not in scrubbed3)
    url_text = ("fetched https://example.com/x~/secret and "
                "https://example.com/tmpdir/page and "
                "https://example.com/~user/paper today")
    ck("URLs keep their paths untouched",
       na.scrub_paths(url_text) == url_text)
    ck("marker never sprayed into URLs",
       "[redacted path]" not in na.scrub_paths(url_text))
else:
    ck("scrub_paths guard exists", False)
prompt2 = na.build_prompt(
    {"title": "Fixture breach escalate", "tag": "CRITICAL",
     "place": "", "url": "https://127.0.0.1:1/leak"},
    None,
    "findings:\nevidence-missing: kimi\n~/.gnupg/private-keys-v1.d\n")
ck("build_prompt scrubs tilde ledger lines", "~/.gnupg" not in prompt2)
ck("build_prompt keeps the article URL", "https://127.0.0.1:1/leak"
   in prompt2)
item = {"title": "PATHLEAK TESTLAND: ~ vault breach",
        "tag": "CRITICAL", "place": "", "url": "https://127.0.0.1:1/leak"}
prompt = na.build_prompt(item, "extract cites /tmp/vr-test-42 dumps",
                         "spend: models 4; notes ~/h.txt")
ck("build_prompt scrubs titles", "~" not in prompt)
ck("build_prompt scrubs source text", "/tmp/vr-test-42" not in prompt)
ck("build_prompt scrubs ledger lines", "~/h.txt" not in prompt)
ck("build_prompt carries the redaction marker", "redacted path" in prompt)
ck("clean prose passes through", "Fixture breach escalate"
   in na.build_prompt({"title": "Fixture breach escalate",
                       "tag": "CRITICAL", "place": "", "url": ""},
                      None, ""))
# output-side no-echo guard (model-hygiene audit 2026-09-16): the input
# scrub cannot stop a model from echoing a path it saw, inferred, or
# hallucinated, so model_reply must run the SAME PATH_TOKEN_RE seam over
# the reply before it becomes an article body. Stub the model seam with
# a pathy draft; the reply must come back redacted, prose kept.
os.environ["NEWS_ARTICLES_MODEL_CMD"] = (
    "printf 'audit notes at ~/h.txt and /tmp/vr-test-42;"
    " tilde ~/.hngh/newspaper/x.md. kept prose.'")
reply = na.model_reply("prompt", "local")
ck("model_reply scrubs echoed /home/... tokens", "~" not in reply)
ck("model_reply scrubs echoed /tmp/... tokens", "/tmp/vr-test" not in reply)
ck("model_reply scrubs echoed ~/.hngh tokens", "~/.hngh" not in reply)
ck("model_reply carries the identity-seam markers",
   reply.count("[redacted path]") == 3)
ck("model_reply keeps ordinary prose", "kept prose" in reply)
os.environ.pop("NEWS_ARTICLES_MODEL_CMD", None)
raise SystemExit(1 if bad else 0)
PY
out="$(run_gen "MODEL_PIN=local" | wc -l)"
ck "pathy edition still files its article" "1" "$out"
ck "model never receives host paths (captured stub bodies)" "0" \
 "$(grep -c -e '~' -e '/tmp/vr-test' -e '~/.hngh' \
  "$stubdir/stubU-bodies" 2>/dev/null || true)"
ck "model request carries the redaction marker" "1" \
 "$(grep -c 'redacted path' "$stubdir/stubU-bodies" 2>/dev/null || true)"

echo "test-news-articles: $fails failure(s)"
[ "$fails" -eq 0 ]
