# sources.sh — fetch each configured source to snapshots/YYYY-MM-DD/<name>-<HHMM>.json,
# compare sha256 with the previous snapshot, emit ONE summary JSON object:
#   {"date": "...", "sources": [{"name","size","hash","changed"}...], "new": ["name", ...]}
# Fail-closed: curl --max-time 30 per source; failed = not new (breadcrumbed); never exits nonzero.
# RSS/Atom sources (hnrss, phoronix, arxiv, ghblog, ...) are detected by root
# element after download and normalized in place by fetch_rss so every
# consumer (build_prompt, news-importance, news-screen) sees the same item
# shape the terminalfeed JSON endpoints already emit.
. "$AUTOMATION_ROOT/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

SNAPSHOT_DIR="$AUTOMATION_ROOT/snapshots"

expand_url() { # url -> url (substitute __TODAY__ / __WEEKAGO__)
 local url="$1" today weekago
 today="$(date +%F)"
 weekago="$(date -d '7 days ago' +%F 2>/dev/null || date -v-7d +%F 2>/dev/null || echo "$today")"
 url="${url//__TODAY__/$today}"
 url="${url//__WEEKAGO__/$weekago}"
 printf '%s' "$url"
}

# fetch_rss NAME SNAPSHOT — normalize an RSS 2.0 / Atom snapshot in place into
# the pipeline item shape: {"source","fetched","data":[{"title","url","date","text"}]}
# (same "data" array convention as the terminalfeed endpoints). python3
# stdlib only (xml.etree + re + html); no new dependencies. Bounded: at most
# 60 items, 1000 chars of text each (MAX_SOURCE_CHARS applies downstream).
# ponytail: caps are fixed, not configurable — raise them here if a feed
# ever justifies it. On any parse failure the raw XML is left in place
# (fail-closed: the snapshot is the record; downstream sees evidence, raw).
fetch_rss() {
 local name="$1" out="$2" tmp
 tmp="${out}.rss.$$"
 if python3 - "$name" "$out" "$tmp" <<'PY'; then
import html, json, re, sys, datetime
import xml.etree.ElementTree as ET

name, src, dst = sys.argv[1:4]
root = ET.parse(src).getroot()

def local(tag):
    return tag.rsplit('}', 1)[-1]

items = []
for el in root.iter():
    if local(el.tag) not in ('item', 'entry'):
        continue
    def child(*names):
        for want in names:
            for c in el:
                if local(c.tag) == want and (c.text or '').strip():
                    return c.text.strip()
        return ''
    title = child('title')[:300]
    date = child('pubDate', 'published', 'updated', 'date')[:60]
    text = child('description', 'summary', 'content')
    url = ''
    for c in el:
        if local(c.tag) == 'link':
            url = (c.get('href') or c.text or '').strip()
            if c.get('rel') in (None, 'alternate'):
                break
    text = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', html.unescape(text))).strip()[:1000]
    if title or url:
        items.append({'title': title, 'url': url, 'date': date, 'text': text})
    if len(items) >= 60:
        break

fetched = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(dst, 'w') as fh:
    json.dump({'source': name, 'fetched': fetched, 'data': items}, fh, ensure_ascii=True)
PY
  mv "$tmp" "$out"
 else
  rm -f "$tmp"
  return 1
 fi
}

# fetch_kev_trim SNAPSHOT — the CISA KEV catalog is a ~1.7MB database that
# changes weekly at most; left raw it would write 40MB/day of hourly
# snapshots into git. Trim in place to: catalog metadata + only
# vulnerabilities added in the last 7 days (the news signal), capped at 60.
# The full catalog stays public at the stable source URL — the snapshot is
# an honest bounded record (catalogVersion pins what was seen), not a mirror.
fetch_kev_trim() { # snapshot
 local out="$1" tmp="${1}.kev.$$"
 if python3 - "$out" "$tmp" <<'PY'; then
import json, sys, datetime

src, dst = sys.argv[1:3]
cat = json.load(open(src))
weekago = (datetime.datetime.now(datetime.timezone.utc) -
           datetime.timedelta(days=7)).strftime('%Y-%m-%d')
recent = [v for v in cat.get('vulnerabilities', [])
          if str(v.get('dateAdded', '')) >= weekago][:60]
out = {k: cat[k] for k in ('title', 'catalogVersion', 'dateReleased', 'count')
       if k in cat}
out['recent'] = recent
with open(dst, 'w') as fh:
    json.dump(out, fh, ensure_ascii=True)
PY
  mv "$tmp" "$out"
 else
  rm -f "$tmp"
  return 1
 fi
}

fetch_sources() {
 local day dir out name url code hash prev changed body="[]" new_names=""
 day="$(date +%F)"
 dir="$SNAPSHOT_DIR/$day"
 mkdir -p "$dir"
 while IFS= read -r line; do
  [ -z "$line" ] && continue
  name="${line%%:*}"
  url="$(expand_url "${line#*:}")"
  out="$dir/$name-$(date +%H%M).json"
  code="$(curl -s --max-time 30 -A "$USER_AGENT" -o "$out" -w '%{http_code}' "$url" 2>/dev/null)" ||
   code="000"
  if [ "$code" = "200" ] && [ -s "$out" ]; then
   # RSS/Atom detection by root-element sniff (content-type varies across
   # feeds and is less deterministic). JSON feeds never match and keep
   # the raw-JSON path (terminalfeed endpoints unmodified; KEV trimmed
   # by fetch_kev_trim below).
   if head -c 256 "$out" | LC_ALL=C grep -q -i -E '<\?xml|<rss[ >]|<feed[ >]'; then
    fetch_rss "$name" "$out" ||
     breadcrumb sources "$name" "rss normalize failed; raw XML snapshot kept"
   elif [ "$(stat -c%s "$out")" -gt 200000 ] &&
    grep -q '"vulnerabilities"' "$out" 2>/dev/null; then
    fetch_kev_trim "$out" ||
     breadcrumb sources "$name" "kev trim failed; raw catalog kept"
   fi
   hash="$(sha256sum "$out" | cut -d' ' -f1)"
   prev="$(newest_snapshot "$dir" "$name" "$(basename "$out")")"
   changed="false"
   if [ -z "$prev" ]; then
    changed="true"
    new_names="${new_names:+$new_names }$name" # first-ever snapshot
   elif [ "$(sha256sum "$prev" | cut -d' ' -f1)" != "$hash" ]; then
    changed="true"
    new_names="${new_names:+$new_names }$name"
   fi
   body="$(printf '%s' "$body" | jq -c --arg n "$name" --argjson s "$(stat -c%s "$out" 2>/dev/null || echo 0)" --arg h "$hash" --argjson c "$changed" '. + [{"name":$n,"size":$s,"hash":$h,"changed":$c}]')"
  else
   rm -f "$out"
   breadcrumb sources "$name" "fetch FAILED http=$code"
   body="$(printf '%s' "$body" | jq -c --arg n "$name" --arg code "$code" '. + [{"name":$n,"size":0,"hash":"","changed":false,"http":$code}]')"
  fi
 done <<EOF
$(printf '%s\n' "$SOURCES")
EOF
 new_arr="[]"
 for n in $new_names; do new_arr="$(printf '%s' "$new_arr" | jq -c --arg n "$n" '. + [$n]')"; done
 printf '%s\n' "$(jq -n --arg d "$day" --argjson s "$body" --argjson n "$new_arr" '{date:$d,sources:$s,new:$n}')"
}
