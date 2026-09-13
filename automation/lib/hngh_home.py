"""hngh-home — userspace path resolution for the hngh home (~/.hngh).

Layout contract (2026-09-13 operator directive): all userspace data —
newspaper copies, manga outputs, knowledge-base/wiki content, local
databases, archives, dispatch editions — lives under ~/.hngh/, never
inside the dev repo. One row per catalogued artifact is appended to
~/.hngh/catalog.tsv (timestamp, kind, path, note).

HNGH_HOME_DIR overrides the root for hermetic tests. This module is
userspace only: kernel src/ knows nothing of it, and kernel/gate/
certificate state never moves under the hngh home.
"""
import datetime
import os

DEFAULT_HOME = ".hngh"


def home():
    """Root of the hngh userspace home."""
    return os.environ.get("HNGH_HOME_DIR") or \
        os.path.join(os.path.expanduser("~"), DEFAULT_HOME)


def _sub(*parts):
    path = os.path.join(home(), *parts)
    os.makedirs(path, exist_ok=True)
    return path


def newspaper_dir(date=None):
    """Newspaper article copies: newspaper/<date>/<slug>.md."""
    return _sub("newspaper", date) if date else _sub("newspaper")


def manga_dir():
    """Manga strip working outputs (jobs/manga-draft.py)."""
    return _sub("manga")


def wiki_dir():
    """Knowledge-base content home (llm-wiki vaults stay at their
    extension-canonical paths; hngh-generated wiki content lands here)."""
    return _sub("wiki")


def db_dir(name=None):
    """Local databases (telemetry.db, ...)."""
    return _sub("db") if name is None else _sub("db", name)


def dispatch_dir():
    """Rendered dispatch editions (HTML per-date dirs + <date>.md)."""
    return _sub("dispatch")


def imagegen_dir():
    """Image-generation workbench outputs (jobs/imagegen-submit.sh)."""
    return _sub("imagegen")


def archive_dir(*parts):
    """Append-mostly archives (digest history under archive/digest/)."""
    return _sub("archive", *parts) if parts else _sub("archive")


def digest_dir():
    """Daily digest store: archive/digest/<name>-<date>.md."""
    return archive_dir("digest")


def _catalog_rows():
    path = os.path.join(home(), "catalog.tsv")
    try:
        with open(path, encoding="utf-8") as fh:
            return path, fh.read().splitlines()
    except OSError:
        return path, []


def catalog(kind, path, note=""):
    """Append one row to the append-only catalog.tsv. Idempotent on
    (kind, path): a repeated catalog call for the same artifact is a
    no-op. TSV-safe: tabs, newlines, and backslashes are
    backslash-escaped.

    ponytail: pre-append scan, sequential writers only — a true
    concurrent race needs flock (add it if catalog() ever runs in
    parallel jobs)."""
    def esc(field):
        return field.replace("\\", "\\\\").replace("\t", "\\t") \
                    .replace("\n", "\\n")
    file, rows = _catalog_rows()
    ek, ep = esc(kind), esc(path)
    for row in rows:
        cells = row.split("\t")
        if len(cells) >= 3 and cells[1] == ek and cells[2] == ep:
            return ""
    stamp = datetime.datetime.now(datetime.timezone.utc) \
        .strftime("%Y-%m-%dT%H:%M:%SZ")
    row = "%s\t%s\t%s\t%s\n" % (stamp, ek, ep, esc(note))
    with open(file, "a", encoding="utf-8") as fh:
        fh.write(row)
    return row
