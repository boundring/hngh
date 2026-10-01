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
import importlib.machinery
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
FILE_URL_RE = re.compile(r"file://\S+")


def _stage_media(page, out_dir, repo):
    """Copy every referenced repo media file into the edition dir and
    rewrite its src to the relative path (self-contained over plain
    HTTP). A rel that escapes docs/media (absolute or ..) is refused
    outright -- staging never copies from outside the media tree
    (hngh-292); per-file copies of in-tree media fail open."""
    media_root = os.path.realpath(os.path.join(repo, "docs", "media"))

    def stage(m):
        rel = m.group(1)
        src = os.path.realpath(os.path.join(repo, "docs", "media", rel))
        if src != media_root and not src.startswith(media_root + os.sep):
            raise ValueError("digest-local: media escape refused: %s"
                             % rel)
        if os.path.isfile(src):
            dst = os.path.join(out_dir, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            try:
                shutil.copy2(src, dst)
            except OSError:
                pass
        return rel
    return MEDIA_RE.sub(stage, page)


def _load_redact_home():
    """lib/scrub.py's redact_home (the single-source home-path
    tilde-renderer), fail-closed (hngh-292): the local edition is an
    egress surface, so a missing or broken scrub module raises here
    and rendering refuses rather than ship raw /home paths."""
    path = os.path.join(ROOT, "lib", "scrub.py")
    loader = importlib.machinery.SourceFileLoader("hngh_scrub_local",
                                                  path)
    spec = importlib.util.spec_from_loader("hngh_scrub_local", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod.redact_home


_redact_home = _load_redact_home()


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
    try:
        page = _stage_media(digest_html.render_page(digest, digests, db),
                            out_dir, os.path.dirname(ROOT))
        page = _redact_home(FILE_URL_RE.sub("[redacted file url]", page))
    except ValueError as exc:
        print("digest-local: %s" % exc, file=sys.stderr)
        return 1
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(page)
    _rebuild_index(home)
    print("digest-local: %s" % out, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
