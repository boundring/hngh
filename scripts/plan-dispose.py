#!/usr/bin/env python3
"""plan-dispose — terminal disposition for a routed plan candidate.

CLI:
  plan-dispose.py <plan-id-or-path> --action park|kill|supersede \
      --cause <cause-class> --reason "<text>"

Resolves the plan inside $HNGH_HOME/docs/project/plans (accepts the
`routed-<date>-<identity>.plan.md` filename, a bare plan id with or
without the .plan.md suffix, or a full path; realpath containment is
validated). Rewrites ONLY the plan header comment: status becomes
parked|killed|superseded (all other header fields preserved) and
cause=<cause-class>, disposed=<UTC-timestamp>, reason=<text> are
appended inside the same comment. Atomic write (tempfile + os.replace).

Refusals (exit 2, reason on stderr): unknown action, cause class not
in the known set, plan already terminal (executed|rejected|parked|
killed|superseded), file not found / outside the plans dir.
Exit 0 on success.
"""
import os
import re
import sys
import tempfile
from datetime import datetime, timezone

KERNEL = os.environ.get(
    "HNGH_HOME", os.path.expanduser("~/Projects/etc/hngh"))
PLANS = os.path.join(KERNEL, "docs", "project", "plans")
ACTIONS = {"park": "parked", "kill": "killed", "supersede": "superseded"}
CAUSES = {"bad-execution", "missing-knowledge", "missing-design",
          "missing-authority", "obsolete", "unknown"}
TERMINAL_STATUS = ("executed", "rejected", "parked", "killed", "superseded")
HEADER_RE = re.compile(r"<!--\s*plan:\s*(.*?)-->", re.DOTALL)


def refuse(msg):
    print("plan-dispose: refuse: %s" % msg, file=sys.stderr)
    return 2


def resolve_plan(target):
    """Realpath of the plan file inside PLANS, else None (with the
    containment check run before existence so escapes are always
    refused, never probed)."""
    if os.sep in target or (os.altsep and os.altsep in target):
        path = target
    else:
        path = os.path.join(PLANS, target)
        if not target.endswith(".plan.md"):
            path += ".plan.md"
    root = os.path.realpath(PLANS)
    real = os.path.realpath(path)
    if real == root or os.path.commonpath([real, root]) != root:
        return None
    return real


def dispose(target, action, cause, reason):
    path = resolve_plan(target)
    if path is None or not os.path.isfile(path):
        return refuse("no plan file found for %r inside %s" % (target, PLANS))
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return refuse("unreadable: %s" % exc)
    m = HEADER_RE.search(text)
    if not m:
        return refuse("no plan header comment in %s" % path)
    header = m.group(1)
    sm = re.search(r"(?<![\w-])status=(\w+)", header)
    if not sm:
        return refuse("no status field in the plan header of %s" % path)
    if sm.group(1) in TERMINAL_STATUS:
        return refuse("plan %s is already terminal (status=%s)"
                      % (path, sm.group(1)))
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    new_header = re.sub(r"(?<![\w-])status=\w+", "status=" + ACTIONS[action],
                        header, count=1)
    reason = reason.replace("-->", "")  # never break out of the comment
    new_header += " cause=%s disposed=%s reason=%s" % (cause, stamp, reason)
    new_text = text[:m.start()] + "<!-- plan: " + new_header + " -->" \
        + text[m.end():]
    tmp = tempfile.NamedTemporaryFile("w", delete=False,
                                      dir=os.path.dirname(path),
                                      suffix=".tmp", encoding="utf-8")
    tmp.write(new_text)
    tmp.close()
    os.replace(tmp.name, path)
    print("plan-dispose: %s -> status=%s cause=%s" % (path, ACTIONS[action],
                                                      cause))
    return 0


def main(argv):
    target = action = cause = reason = None
    i = 0
    while i < len(argv):
        if argv[i] == "--action" and i + 1 < len(argv):
            action = argv[i + 1]
            i += 2
        elif argv[i] == "--cause" and i + 1 < len(argv):
            cause = argv[i + 1]
            i += 2
        elif argv[i] == "--reason" and i + 1 < len(argv):
            reason = argv[i + 1]
            i += 2
        elif target is None:
            target = argv[i]
            i += 1
        else:
            return refuse("unexpected argument %r" % argv[i])
    if not target:
        return refuse("usage: plan-dispose.py <plan-id-or-path> --action "
                      "park|kill|supersede --cause <cause-class> "
                      '--reason "<text>"')
    if action not in ACTIONS:
        return refuse("unknown action %r (want park|kill|supersede)" % action)
    if cause not in CAUSES:
        return refuse("unknown cause class %r (want one of %s)"
                      % (cause, ", ".join(sorted(CAUSES))))
    if not reason:
        return refuse("a non-empty --reason is required")
    return dispose(target, action, cause, reason)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
