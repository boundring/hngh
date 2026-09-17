"""hngh scrub — THE single-source path-token redaction definition.

Every scrub/redact in the tree (python jobs, shell seams, and the
kernel ledger sink's mirrored mapping) derives from this module; the
pre-2026-09-16 per-site copies (jobs/news-articles.py,
jobs/digest-ledger.py, lib/model.sh inline jq, lib/redact.sh sed) are
retired. Consolidation contract (llc-gate-scrub-site-divergence):

- ONE marker convention: scrub_paths fails closed to the fixed marker
  "[redacted path]". The kernel ledger sink keeps its readable tilde
  rendering (~ = /home/<user>, ~tmp = /tmp) via redact_home(); both
  die on absolute paths, and the mapping is mirrored here so the two
  marker conventions are explicitly one family, two renderings.
- ONE token family: absolute machine-local paths (/home/<user>,
  /Users/<user>, /root, /tmp, scheme-relative //host/...), tilde
  paths (~/...), and credential-bearing URL userinfo (user:pass@host)
  die; source URLs are wire data and survive verbatim EXCEPT their
  userinfo; bare /home, /tmp, /root (no trailing segment) die too;
  the mid-token guard keeps URL path components
  (https://x.io/home/u/f) and word fragments (/rooted) intact.

Import as a module from python jobs, or source lib/scrub.sh from
shell. Dependency direction stays inward: nothing here imports repo
state, and kernel code never imports this module (it mirrors the
family in scripts/report-queue as the git-tracked sink-side guard).
"""
import re

MARKER = "[redacted path]"

# Hostpath alternation, shared by scrub_paths and redact_home. The
# mid-token guard (?<![A-Za-z0-9.~/-]) keeps URL path components
# (https://x.io/home/u/f) and word fragments (/rooted) from matching.
# Non-capturing groups only: the union must stay single-named.
_HOSTPATH = (
    r"(?<![A-Za-z0-9.~/-])"
    r"(?P<home>/home(?:/(?P<homeuser>[^/\s]+))?(?P<homerest>/\S*)?"
    r"(?![\w-]))"
)

_USERS = (
    r"(?<![A-Za-z0-9.~/-])"
    r"(?P<users>/Users(?:/[^/\s]+)?(?P<usersrest>/\S*)?(?![\w-]))"
)

_ROOTP = (
    r"(?<![A-Za-z0-9.~/-])"
    r"(?P<rootp>/root(?P<rootrest>/\S*)?(?![\w-]))"
)

_TMPP = (
    r"(?<![A-Za-z0-9.~/-])"
    r"(?P<tmpp>/tmp(?P<tmprest>/\S*)?(?![\w-]))"
)

_SRH = (
    r"(?<![A-Za-z0-9.~/-])"
    r"(?P<srh>//(?P<srhhost>[^/\s]+)(?P<srhhome>/home(?:/[^/\s]+)?)"
    r"(?P<srhrest>/\S*)?)"
)

_TILDEP = r"(?<![\w.~/-])(?P<tilde>~/\S*)"

_HOSTPATH_ALL = "|".join([_HOSTPATH, _USERS, _ROOTP, _TMPP, _SRH])

# URL-shaped tokens: scheme:// or www. + non-space run. Matched FIRST
# (union leftmost alternative); userinfo inside a URL dies, the rest of
# the URL survives (wire data, not the operator's filesystem; the named
# group decides, never token content).
_URL = (
    r"(?P<url>\b(?:[a-z][a-z0-9+.-]*://|www\.)\S*)"
)
_USERINFO = r"(?P<userinfo>(?<=//)(?P<uinfo>[^/@\s]+)@)"


def _redact_urlinfo(url):
    """Credential-bearing userinfo inside a preserved URL dies to
    [redacted]@; plain URLs pass unchanged."""
    return re.sub(r"(?<=//)[^/@\s]+@", "[redacted]@", url)

PATH_TOKEN_RE = re.compile(
    "|".join([_URL, _USERINFO, _HOSTPATH_ALL, _TILDEP]))


def _host_repl(m):
    """Marker or tilde rendering for one hostpath match."""
    if m.group("home") is not None and m.group("homeuser") is not None:
        return "~" + (m.group("homerest") or "")
    if m.group("users") is not None:
        return "~" + (m.group("usersrest") or "")
    if m.group("rootp") is not None:
        return "~" + (m.group("rootrest") or "")
    if m.group("tmpp") is not None:
        return "~tmp" + (m.group("tmprest") or "")
    if m.group("srh") is not None:
        return "~" + (m.group("srhrest") or "")
    return MARKER


def _path_repl(tilde):
    def repl(m):
        if m.group("url") is not None:
            return _redact_urlinfo(m.group("url"))
        if m.group("userinfo") is not None:
            return "[redacted]@"
        if m.group("tilde") is not None:
            if tilde:
                return m.group(0)  # already the readable convention
            return MARKER
        if tilde:
            return _host_repl(m)
        return MARKER
    return repl


def scrub_paths(text):
    """Fail-closed redaction: one token family, one marker.

    Returns text with every machine-local path token replaced by
    MARKER; URL-shaped tokens preserved verbatim except credential
    userinfo. None/empty -> ""."""
    return PATH_TOKEN_RE.sub(_path_repl(False), str(text or ""))


def redact_home(text):
    """The kernel-ledger tilde rendering of the same token family.

    /home/<user>/rest -> ~/rest, /Users/<user>/rest -> ~/rest,
    /root/rest -> ~/rest, //host/home/<user>/rest -> ~/rest,
    /tmp/rest -> ~tmp/rest, bare families -> ~ / ~tmp; credential
    userinfo -> [redacted]@. Mirrors scripts/report-queue so the
    sink-side mapping and this module stay one family."""
    return PATH_TOKEN_RE.sub(_path_repl(True), str(text or ""))


def _leak(m):
    if m.group("url") is not None:
        return bool(re.search(r"(?<=//)[^/@\s]+@", m.group("url")))
    return m.group("url") is None and m.group("userinfo") is None


def scrub_grep(text, tilde_ok=True):
    """MATCH lines for scanning: lines whose tokens need attention.

    A line is reported when it carries a host-path token (or bare
    tilde path). Kernel tilde markers (~tmp/..., ~/...) are the
    readable convention, not leakage, and pass; credential userinfo
    is reported; plain source URLs are not."""
    out = []
    for line in str(text or "").splitlines():
        hits = [m for m in PATH_TOKEN_RE.finditer(line) if _leak(m)]
        if hits:
            out.append(line)
    return out
