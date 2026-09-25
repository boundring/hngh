#!/usr/bin/env python3
"""newspaper-edition -- one overnight newspaper edition, paid-cost-free.

Operator directive 2026-09-13: the newspaper pipeline converts to
procedural code + token-limited LOCAL-model sessions, run inside the
operator's sleeping hours. This driver is mounted on the hour tier
(cadence/hour/41-newspaper-edition.sh); it gates itself on:

  - the sleep window (cadence-params row newspaper-sleep-window,
    default 01:30-06:30 LOCAL time; env HNGH_NEWSPAPER_WINDOW overrides)
  - one edition per UTC date: ~/.hngh/newspaper/<date>/edition.json is
    the idempotence marker; a later hour tick retries when absent
  - the day's digest must exist (fail-closed, like every cadence lane)

Edition layout (userspace-home policy 2026-09-13: never in the repo):

  ~/.hngh/newspaper/<date>/digest.md      copy of automation/digest md
  ~/.hngh/newspaper/<date>/<slug>.md      local-model article drafts
  ~/.hngh/newspaper/<date>/media/         story illustrations (local GPU)
  ~/.hngh/newspaper/<date>/index.html     rendered self-contained page
  ~/.hngh/newspaper/<date>/edition.json   metadata + model-call telemetry

Fail-closed: no digest, no articles made, or an unusable window -> exit 0
with a breadcrumb, no marker written, the next hour tick retries.
Seams (hermetic tests): HNGH_NEWSPAPER_DIR, HNGH_HOME_DIR,
HNGH_AUTOMATION_ROOT, HNGH_DIGESTS_DIR, HNGH_NEWSPAPER_WINDOW,
HNGH_NEWSPAPER_NOW (minute-of-day clock seam, tests only), STATE_FILE.

usage: jobs/newspaper-edition.py <YYYY-MM-DD>
"""
import importlib.util
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone

ROOT = os.environ.get("HNGH_AUTOMATION_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)
sys.path.insert(0, os.path.join(ROOT, "lib"))
import crumbs  # the single STATE.md crumb writer (lib/crumbs.py)
PAPER = (os.environ.get("HNGH_NEWSPAPER_DIR")
         or os.path.join(
             os.environ.get("HNGH_HOME_DIR")
             or os.path.join(os.path.expanduser("~"), ".hngh"),
             "newspaper"))
_hh_path = os.path.join(ROOT, "lib", "hngh_home.py")
_HH = None
if os.path.isfile(_hh_path):
    _spec = importlib.util.spec_from_file_location("hngh_home", _hh_path)
    _HH = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_HH)
DIGESTS_DIR = os.environ.get("HNGH_DIGESTS_DIR") or \
    (_HH.digest_dir() if _HH else os.path.join(ROOT, "digest"))
DEFAULT_WINDOW = "01:30-06:30"
WINDOW_RE = re.compile(r"^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$")


def get_param(key, default):
    """cadence-params.tsv row -> value; fail-open to default."""
    try:
        with open(os.path.join(ROOT, "cadence-params.tsv"),
                  encoding="utf-8") as f:
            for line in f:
                p = line.rstrip("\n").split("\t")
                if p and p[0] == key and len(p) > 1 and p[1]:
                    return p[1]
    except OSError:
        pass
    return default


def parse_window(text):
    """'01:30-06:30' -> (start_min, end_min); None when malformed
    (fail-closed: a bad window config builds nothing)."""
    m = WINDOW_RE.match(str(text).strip())
    if not m:
        return None
    h1, m1, h2, m2 = (int(g) for g in m.groups())
    for h, mi in ((h1, m1), (h2, m2)):
        if h > 23 or mi > 59:
            return None
    return h1 * 60 + m1, h2 * 60 + m2


def in_window(now_min, window):
    """Minute-of-day inside the window? Overnight wrap supported
    (start > end means the window crosses midnight)."""
    start, end = window
    if start <= end:
        return start <= now_min < end
    return now_min >= start or now_min < end


def should_build(date, paper_dir, window_text, now_min=None):
    """The overnight gate. Returns (build?, reason) with one of:
    bad-window | outside-window | already-built | no-digest | build."""
    window = parse_window(window_text)
    if window is None:
        return False, "bad-window"
    if now_min is None:
        now_min = datetime.now().hour * 60 + datetime.now().minute
    if not in_window(now_min, window):
        return False, "outside-window"
    if os.path.isfile(os.path.join(paper_dir, date, "edition.json")):
        return False, "already-built"
    if not os.path.isfile(os.path.join(DIGESTS_DIR, date + ".md")):
        return False, "no-digest"
    return True, "build"


def breadcrumb(event, detail):
    # the single STATE.md seam (lib/crumbs.py): 4-field stamped line
    try:
        crumbs.crumb("newspaper-edition", event, crumbs.scrub(detail))
    except OSError:
        pass


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(ROOT, rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build(date):
    """Generate the articles (local legs only), assemble the edition
    dir, write metadata + telemetry. Returns the edition dir path."""
    na = _load("news_articles", "jobs/news-articles.py")
    dh = na.digest_html()
    out_dir = os.path.join(PAPER, date)
    os.makedirs(out_dir, exist_ok=True)
    made = na.generate(date, os.path.join(DIGESTS_DIR, date + ".md"))
    if not made:
        return None  # chain down: fail-closed, next tick retries
    digest_dst = os.path.join(out_dir, "digest.md")
    shutil.copy2(os.path.join(DIGESTS_DIR, date + ".md"), digest_dst)
    try:  # page render is best-effort; the md edition is the archive
        page = dh.render_page(digest_dst, DIGESTS_DIR)
        dl = _load("digest_local", "jobs/digest-local.py")
        page = dl._stage_media(page, out_dir, REPO)
        with open(os.path.join(out_dir, "index.html"), "w",
                  encoding="utf-8") as fh:
            fh.write(page)
    except Exception as exc:  # noqa: BLE001 - fail-closed edition
        breadcrumb("render-failed", str(exc)[:160])
    window = os.environ.get("HNGH_NEWSPAPER_WINDOW") or \
        get_param("newspaper-sleep-window", DEFAULT_WINDOW)
    u = dict(na.LAST_USAGE)
    meta = {"date": date, "built_at": datetime.now(
                timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "window": window, "status": "full",
            "articles": [os.path.splitext(os.path.basename(p))[0]
                         for p in made],
            "model_sessions": u["calls"],
            "tokens_in": u["tokens_in"], "tokens_out": u["tokens_out"],
            "paid_calls": u["paid"]}
    with open(os.path.join(out_dir, "edition.json"), "w",
              encoding="utf-8") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
        fh.write("\n")
    try:  # one line per edition for the operator's cost view
        os.makedirs(os.path.join(ROOT, "logs"), exist_ok=True)
        with open(os.path.join(ROOT, "logs",
                               "newspaper-edition.log"), "a") as fh:
            fh.write("%s sessions=%d tokens_in=%d tokens_out=%d "
                     "paid_calls=%d articles=%d window=%s\n"
                     % (date, u["calls"], u["tokens_in"], u["tokens_out"],
                        u["paid"], len(made), window))
    except OSError:
        pass
    return out_dir


def main(argv):
    if len(argv) != 2 or not re.match(r"^\d{4}-\d{2}-\d{2}$", argv[1]):
        print("usage: newspaper-edition.py <YYYY-MM-DD>", file=sys.stderr)
        return 2
    date = argv[1]
    window = os.environ.get("HNGH_NEWSPAPER_WINDOW") or \
        get_param("newspaper-sleep-window", DEFAULT_WINDOW)
    now_min = None
    if os.environ.get("HNGH_NEWSPAPER_NOW", "").isdigit():
        now_min = int(os.environ["HNGH_NEWSPAPER_NOW"])
    ok, reason = should_build(date, PAPER, window, now_min=now_min)
    if not ok:
        if reason not in ("outside-window", "already-built"):
            breadcrumb(reason, "edition gate for %s window=%s"
                       % (date, window))
        return 0
    out_dir = build(date)
    if out_dir:
        print("newspaper-edition: %s" % out_dir, file=sys.stderr)
        breadcrumb("edition", "%s built (see edition.json)" % date)
    else:
        breadcrumb("no-articles", "%s: local chain down or no items; "
                   "retry next hour tick" % date)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
