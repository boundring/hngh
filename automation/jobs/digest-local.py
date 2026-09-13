#!/usr/bin/env python3
"""digest-local -- one daily digest rendered into the hngh home dispatch
dir, for local serving (2026-09-13 operator directive).

usage: digest-local.py <date>   # -> ($HNGH_HOME_DIR or ~/.hngh)/
                               #    dispatch/<date>/index.html
Serve: python3 -m http.server -d ~/.hngh/dispatch

The page is jobs/digest-html.py's render of automation/digest/<date>.md,
written into the home tree with every referenced media file copied
alongside (newspaper directive 2026-09-13: story illustrations embed
inline) and an edition index at dispatch/index.html linking editions
newest first. The public GitHub README deliberately does NOT embed the
paper. Seams (hermetic tests): HNGH_HOME_DIR, HNGH_DIGESTS_DIR,
HNGH_TELEMETRY_DB.
"""
import os
import importlib.util
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location(
    "digest_html", os.path.join(ROOT, "jobs", "digest-html.py"))
digest_html = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(digest_html)

MEDIA_RE = re.compile(r'/hngh-docs/media/([^"\']+)')


def _stage_media(page, out_dir, repo):
    """Copy every referenced repo media file into the edition dir and
    rewrite its src to the relative path (self-contained over plain
    HTTP). Per-file copies fail open; the page renders either way."""
    def stage(m):
        rel = m.group(1)
        src = os.path.join(repo, "docs", "media", rel)
        if os.path.isfile(src):
            dst = os.path.join(out_dir, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            try:
                shutil.copy2(src, dst)
            except OSError:
                pass
        return rel
    return MEDIA_RE.sub(stage, page)


def _rebuild_index(home):
    """dispatch/index.html: one link per edition, newest mtime first."""
    root = os.path.join(home, "dispatch")
    try:
        rows = [(os.path.getmtime(os.path.join(root, n, "index.html")), n)
                for n in sorted(os.listdir(root))
                if os.path.isfile(os.path.join(root, n, "index.html"))]
    except OSError:
        rows = []
    links = "".join('<li><a href="%s/index.html">The Daily Dispatch '
                    '-- %s</a></li>' % (digest_html.esc(n), digest_html.esc(n))
                    for _, n in sorted(rows, reverse=True))
    with open(os.path.join(root, "index.html"), "w", encoding="utf-8") as fh:
        fh.write('<!doctype html>\n<html><head><meta charset="utf-8">'
                 '<title>The Machine Hall Daily Dispatch -- editions</title>'
                 '</head><body><h1>The Machine Hall Daily Dispatch</h1>'
                 '<p>Local editions, newest first.</p><ul>%s</ul>'
                 '</body></html>' % links)


def main(argv):
    if len(argv) != 1:
        print("usage: digest-local.py <date>", file=sys.stderr)
        return 2
    date = argv[0]
    home = os.environ.get("HNGH_HOME_DIR") or \
        os.path.join(os.path.expanduser("~"), ".hngh")
    digests = os.environ.get("HNGH_DIGESTS_DIR") or digest_html.DIGESTS
    db = os.environ.get("HNGH_TELEMETRY_DB") or digest_html.TELEMETRY
    digest = os.path.join(digests, date + ".md")
    if not os.path.isfile(digest):
        print("digest-local: no digest for %s (%s) -- fail-closed"
              % (date, digest), file=sys.stderr)
        return 1
    out_dir = os.path.join(home, "dispatch", date)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "index.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(_stage_media(
            digest_html.render_page(digest, digests, db), out_dir,
            os.path.dirname(ROOT)))
    _rebuild_index(home)
    print("digest-local: %s" % out, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
