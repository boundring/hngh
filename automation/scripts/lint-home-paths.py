#!/usr/bin/env python3
"""lint-home-paths - the real local home path must never enter tracked
content (operator directive, 2026-09-23).

Violation pattern: /home/ + the running account's home basename
(derived at runtime, never hardcoded), not followed by [A-Za-z0-9._-].
Fake-login fixtures (/home/aubergine, /home/testuser, /home/bri) and
URL wire data (https://x.io/home/u/f) are deliberately legal - the
scrubber's test vocabulary.

Modes: default = worktree content of every tracked file (git ls-files);
--staged = index bytes of the staged change set (what the commit would
land); REV = the full tree of REV in one git-archive pass (pre-push).
Zip payloads (bytes starting with PK) additionally scan every member
name and body; a PK payload that will not open as a zip is itself a
violation (fail closed)."""

import argparse
import io
import os
import pathlib
import re
import subprocess
import sys
import tarfile
import zipfile

HOME_NAME = pathlib.Path.home().name
# ponytail: guards the running account's home basename only (widen to
# pwd.getpwall() if multi-account leaks appear)
PAT = re.compile(rb"/home/" + re.escape(HOME_NAME.encode()) + rb"(?![A-Za-z0-9._-])")


def scan_payload(name, data):
    """Violation lines for one file's bytes; a zip payload also scans
    every member name and body."""
    out = []
    for n, line in enumerate(data.split(b"\n"), 1):
        if PAT.search(line):
            text = line.decode("utf-8", "replace").strip()[:160]
            out.append("%s: line %d: %s" % (name, n, text))
    if data[:2] == b"PK":
        try:
            zf = zipfile.ZipFile(io.BytesIO(data))
            members = [(m, zf.read(m)) for m in zf.namelist()]
        except Exception:
            out.append("%s: unparseable PK payload" % name)
            return out
        for member, body in members:
            if (PAT.search(member.encode("utf-8", "surrogateescape"))
                    or PAT.search(body)):
                out.append("%s:%s: zip-member hit" % (name, member))
    return out


def lint(payloads):
    """Scan (name, bytes) payloads; print findings and return the exit
    code. Findings and summary go to stderr, clean to stdout - the
    lint-identifiers.sh convention."""
    problems = 0
    for name, data in payloads:
        for line in scan_payload(name, data):
            print(line, file=sys.stderr)
            problems += 1
    if not problems:
        print("lint-home-paths: clean")
        return 0
    print("lint-home-paths: %d location(s) leak the real home path"
          % problems, file=sys.stderr)
    return 1


def _git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True)


def _root():
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit("lint-home-paths: not a git work tree")
    return pathlib.Path(r.stdout.strip())


def worktree_payloads(root):
    for name in _git(root, "ls-files").stdout.decode(
            "utf-8", "surrogateescape").splitlines():
        path = root / name
        try:
            # a symlink's blob is its target string, not the target's bytes
            data = (os.fsencode(os.readlink(path)) if path.is_symlink()
                    else path.read_bytes())
        except OSError:
            continue  # deleted or unreadable worktree copy
        yield name, data


def staged_payloads(root):
    out = _git(root, "diff", "--cached", "--name-only", "-z").stdout
    # ponytail: one git process per staged file; batch through
    # `git cat-file --batch` if commits ever stage hundreds of files
    for name in out.decode("utf-8", "surrogateescape").split("\0"):
        if not name:
            continue
        blob = _git(root, "show", ":" + name)  # index bytes = what commits
        if blob.returncode == 0:
            yield name, blob.stdout


def rev_payloads(root, rev):
    proc = subprocess.Popen(["git", "-C", str(root), "archive", rev],
                            stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=proc.stdout, mode="r|") as tf:
            for member in tf:
                if member.isfile():
                    yield member.name, tf.extractfile(member).read()
                elif member.issym():
                    yield member.name, os.fsencode(member.linkname)
    except (tarfile.TarError, EOFError):
        sys.exit("lint-home-paths: cannot read tree of %s" % rev)
    finally:
        proc.stdout.close()
    if proc.wait() != 0:
        sys.exit("lint-home-paths: git archive %s failed" % rev)


def main(argv):
    ap = argparse.ArgumentParser(
        description="fail closed if tracked content carries the real "
                    "local home path")
    ap.add_argument("--staged", action="store_true",
                    help="scan index bytes of the staged change set")
    ap.add_argument("rev", nargs="?",
                    help="scan the full tree of REV in one git-archive pass")
    args = ap.parse_args(argv)
    if args.rev and args.staged:
        ap.error("--staged and REV are mutually exclusive")
    root = _root()
    if args.rev:
        payloads = rev_payloads(root, args.rev)
    elif args.staged:
        payloads = staged_payloads(root)
    else:
        payloads = worktree_payloads(root)
    return lint(payloads)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
