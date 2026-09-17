import re

# Exact replication of scripts/report-queue:121-163 boundary family
_REDACT_HOME = "/" + "home"
_R = "/"
_GUARD = r"(^|[^A-Za-z0-9.~/-])"
_TOK_END = r"(?![\w-])"


def _tilde_rest(name):
    return lambda m: m.group(1) + "~" + (m.group(name) or "")


REDACT_RES = (
    (re.compile(_GUARD + _REDACT_HOME + r"(?:/[^/\s]+)?(?P<homerest>/\S*)?" + _TOK_END),
     _tilde_rest("homerest")),
    (re.compile(_GUARD + _R + r"Users(?:/[^/\s]+)?(?P<usersrest>/\S*)?" + _TOK_END),
     _tilde_rest("usersrest")),
    (re.compile(_GUARD + _R + r"root(?=[/\s]|\Z)(?P<rootrest>/\S*)?"),
     _tilde_rest("rootrest")),
    (re.compile(r"(^|[^A-Za-z0-9.~:/-])//[^/\s]+" + _REDACT_HOME
                + r"(?:/[^/\s]+)?(?P<srhrest>/\S*)?" + _TOK_END),
     _tilde_rest("srhrest")),
    (re.compile(_GUARD + _R + r"tmp(?=[/\s]|\Z)(?P<tmprest>/\S*)?"),
     lambda m: m.group(1) + "~tmp" + (m.group("tmprest") or "")),
)


def redact_boundary(text):
    for rx, repl in REDACT_RES:
        text = rx.sub(repl, text)
    text = re.sub(r"(?<=//)[^/@\s]+@", "[redacted]@", text)
    return text


probes = [
    "/home/bricker/x",                       # canonical
    "cwd=/home/bricker",                     # end-of-token path
    "/home",                                 # bare
    "xhome/bricker",                         # mid-token word, must stay
    "ssh://user:pass@host/home/bricker/y",   # URL userinfo + path
    "//nas/home/bricker/z",                  # scheme-relative mount
    "/tmp/a /root/b /Users/c/d",             # multi-family
    "/homeX/bricker",                        # word fragment, must stay
    "see/home/bricker",                      # mid-token guard, must stay
    "HOME=/home/bricker",                    # env-var style
    "/opt/home/bricker",                     # mid-path 'home' after slash
    "macOS /Users/jane/Docs",                # Users family
    "/var/home/jo",                          # ostree-style /var/home
    "scp /home/bricker/.ssh/id_ed25519",     # credential-bearing path
]
for p in probes:
    print(repr(p), "->", repr(redact_boundary(p)))
