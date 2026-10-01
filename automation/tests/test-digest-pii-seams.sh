#!/usr/bin/env bash
# test-digest-pii-seams.sh — hngh-292 digest-writer seam pins, hermetic
# (HNGH_HOME_DIR sandbox, no repo mutation, no network):
# 1. digest-local: renders a PII-laced digest with home paths
#    tilde-rendered (never the raw /home/<user> form), and REFUSES
#    media rels that escape docs/media (rc!=0, no edition staged) --
#    an escaping rel that resolves to a real file must not be copied.
# 2. digest-public: the public page carries no raw home path, no
#    file:// URL, and dash-form blocker ids are path-truncated.
# 3. All three render-layer _load_scrub loaders (jobs/digest-html.py,
#    jobs/digest-public.py, scripts/html-digest.py) fail CLOSED on a
#    corrupt scrub module: RuntimeError, never the identity lambda.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(dirname "$root")"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
user="$(id -un)"
homeabs="/home/$user"
export HNGH_ROUTER_PATHY_STEMS="$user"

fails=0
check() { # check <desc> <expected> <actual>
 if [ "$2" = "$3" ]; then printf 'ok %s\n' "$1"; else
  printf 'FAIL %s: expected [%s] got [%s]\n' "$1" "$2" "$3"
  fails=$((fails + 1))
 fi
}

date=2026-10-01
export HNGH_HOME_DIR="$sb/home"
export HNGH_DIGESTS_DIR="$sb/digests"
mkdir -p "$HNGH_HOME_DIR"
digests="$sb/digests"
mkdir -p "$digests"

cat >"$digests/$date.md" <<EOF
## 1200 2026-10-01
- CRITICAL: patrol round leaked /hngh-docs/media/circular.txt and the
  path /home/$user/Projects/etc/hngh/state.tgz into the round text.
_FILE: file://$homeabs/secret.txt | src: wire_

## 1300 2026-10-01
- NOTABLE: research beat filed with dash id
  fail-2026-10-01-Where-exactly-in-home-$user-Projects.
EOF

# --- 1. digest-local: tilde-rendered paths on the local edition ------
python3 "$root/jobs/digest-local.py" "$date" 2>"$sb/local.err"
rc=$?
[ "$rc" -eq 0 ] || cat "$sb/local.err" >&2
check "digest-local happy rc" "0" "$rc"
out="$HNGH_HOME_DIR/dispatch/$date/index.html"
[ -f "$out" ] || out="$HNGH_HOME_DIR/home/dispatch/$date/index.html"
check "digest-local edition staged" "1" "$([ -f "$out" ] && echo 1)"
check "digest-local no raw home path" "0" \
 "$(grep -c -F "$homeabs" "$out" 2>/dev/null || true)"
check "digest-local home path redacted" "1" \
 "$([ "$(grep -cE '\[redacted path\]|~/' "$out" 2>/dev/null)" -ge 1 ] && echo 1 || echo 0)"

# --- 1b. digest-local refuses an escaping media rel ------------------
date2=2026-10-02
cat >"$digests/$date2.md" <<EOF
## 1200 2026-10-02
- CRITICAL: staged media /hngh-docs/media/../../CHANGELOG.md escaped.
EOF
python3 "$root/jobs/digest-local.py" "$date2" 2>"$sb/escape.err"
rc=$?
check "digest-local media escape refused (rc!=0)" "yes" \
 "$([ "$rc" -ne 0 ] && echo yes)"
check "digest-local escape staged nothing" "0" \
 "$(find "$HNGH_HOME_DIR/dispatch/$date2" -name CHANGELOG.md 2>/dev/null | wc -l)"
check "digest-local refusal named" "1" \
 "$(grep -c -i "refus" "$sb/escape.err" 2>/dev/null)"

# --- 2. digest-public: scrubbed public page -------------------------
pubroot="$sb/pubroot"
mkdir -p "$pubroot/automation/state"
printf 'fail-2026-10-01-Where-exactly-in-home-%s-Projects\tresearch\tpath-normalization\t2026-10-01T12:00:00Z\t3\tparked\n' \
 "$user" >"$pubroot/automation/state/beat-blockers.tsv"
printf '2026-10-01T12:30:00Z | /home/%s leak class | open\n' "$user" \
 >"$pubroot/automation/state/ocgo-agent-lessons.md"
HNGH_DIGESTS_DIR="$digests" HNGH_PUB_ROOT="$pubroot" \
 python3 "$root/jobs/digest-public.py" "$date" >"$sb/pub.path" 2>"$sb/pub.err"
check "digest-public rc" "0" "$?"
pub="$(cat "$sb/pub.path")"
check "digest-public page written" "1" "$([ -f "$pub" ] && echo 1)"
if [ -f "$pub" ]; then
 check "digest-public no raw home path" "0" \
  "$(grep -c -F "$homeabs" "$pub")"
 check "digest-public no file:// URL" "0" "$(grep -c "file://" "$pub")"
 check "digest-public no dash-mangled home id" "0" \
  "$(grep -c -F "in-home-$user" "$pub")"
 check "digest-public saga rendered" "1" "$(grep -c "## The Saga" "$pub")"
else
 fails=$((fails + 3))
fi

# --- 3. _load_scrub fail-closed on a corrupt scrub module -----------
fake="$sb/fake"
mkdir -p "$fake/lib" "$fake/jobs"
printf 'raise ValueError("corrupt scrub")\n' >"$fake/lib/scrub.py"
cp "$repo/automation/jobs/digest-ledger.py" "$fake/jobs/"

loader_probe='
import ast, importlib, importlib.machinery, importlib.util, os, sys
def grab(path, fname):
    tree = ast.parse(open(path).read())
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == fname:
            code = compile(ast.Module(body=[node], type_ignores=[]),
                           path, "exec")
            g = {"__name__": "probe", "os": os, "importlib": importlib,
                 os.environ["KEY"]: os.environ["VAL"]}
            exec(code, g)
            return g[fname]
    raise AssertionError("no %s in %s" % (fname, path))
name, path = sys.argv[1], sys.argv[2]
fn = grab(path, "_load_scrub")
try:
    fn()
except Exception as exc:
    print("refused: %s" % exc)
    sys.exit(0)
sys.exit("FAIL: loader returned without refusing")
'
for probe in "digest-html:$root/jobs/digest-html.py:ROOT=$fake" \
 "digest-public:$root/jobs/digest-public.py:HERE=$fake" \
 "html-digest:$root/scripts/html-digest.py:AUTOMATION=$fake"; do
 label="${probe%%:*}"
 rest="${probe#*:}"
 src="${rest%%:*}"
 seam="${rest#*:}"
 key="${seam%%=*}"
 val="${seam#*=}"
 got="$(KEY="$key" VAL="$val" python3 -c "$loader_probe" probe "$src" 2>&1)"
 case "$got" in refused*) ;; *)
  fails=$((fails + 1))
  printf 'FAIL loader %s: expected refusal, got [%s]\n' "$label" "$got"
  ;;
 esac
done
[ "$fails" -eq 0 ] || {
 echo "FAIL: $fails check(s)"
 exit 1
}
echo "digest PII seams: all pins hold"
