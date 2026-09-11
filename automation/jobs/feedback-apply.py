#!/usr/bin/env python3
"""feedback-apply — auto-apply [quick] theme/format feedback, inspect
corrections, never guess.

Operator interactivity directive (2026-09-11), apply slice. Governance
boundary: automation/dashboard/ is the gitignored runtime surface; style
edits there are reversible file edits, NOT certificate-bound mutations.
Trust rule: machines apply only what the operator's own feedback asked
for, and only the whitelisted one-line class:

- [feedback:css-theme|data-format][quick] -> property edits on
  dashboard/style.css (font-size/gap/margin/padding +/-2px, explicit
  color values), clamped to +/-16px drift from a recorded baseline.
  Anything not parseable to the whitelist stays an unapplied operator
  item. Max 5 appended rules per beat.
- [feedback:correction] -> auto-inspect only: run the named check if one
  exists (tests/... or scripts/...), file one report row with the
  result, never edit code.
- any other type -> operator-only; no action beyond the alert row.

Durable state: state/feedback-applied.tsv (item id, ts, property, old,
new, sha256 of the edited file). History: dashboard/feedback/APPLIED.md
carries the previous value per line; `--revert-last` restores it (one
level deep by design).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTOMATION_ROOT = os.environ.get("AUTOMATION_ROOT", ROOT)
STYLE = os.path.join(AUTOMATION_ROOT, "dashboard", "style.css")
ITEMS_JSON = os.path.join(AUTOMATION_ROOT, "dashboard",
                          "operator-items.json")
APPLIED_MD = os.path.join(AUTOMATION_ROOT, "dashboard", "feedback",
                          "APPLIED.md")
STATE_TSV = os.path.join(AUTOMATION_ROOT, "state",
                         "feedback-applied.tsv")
REPORT_KERNEL = os.environ.get("HNGH_HOME", os.path.dirname(ROOT))
STATE_MD = os.environ.get("STATE_FILE")

QUICK_RE = re.compile(
    r"\[feedback:([\w-]+)\](\[quick\])?\s*(?:(.*?):\s*)?(.*)")
ITEM_ROW_RE = re.compile(r"\|\s*alert\s+\|\s*(.*)$")
COLOR_RE = re.compile(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b|"
                      r"\b(red|green|blue|orange|purple|yellow|gray|grey|"
                      r"black|white|cyan|magenta|pink)\b")
CHECK_RE = re.compile(r"\b((?:tests|scripts)/[\w.-]+)")
APPEND_CAP = 5

# whitelist: shorthand phrase -> (property, per-apply delta px, axis)
# ponytail: fixed table by design — new property kinds need an operator
# directive, not a smarter parser.
WHITELIST = {
    "base font size": ("font-size", 2),
    "panel gap": ("gap", 2),
    "margins": ("margin", 2),
    "spacing": ("padding", 2),
}
BASELINE_DEFAULTS = {"font-size": 14, "gap": 12, "margin": 8, "padding": 8}
DRIFT_LIMIT = 16


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def rules(css):
    """Top-level (non @-) rules: [(selector, block, start, end)].
    Unbalanced braces -> [] (treated as unparseable upstream)."""
    out, depth, open_pos, prev_end = [], 0, 0, 0
    for m in re.finditer(r"[{}]", css):
        if m.group() == "{":
            if depth == 0:
                open_pos, sel_start = m.start(), prev_end
            depth += 1
        elif depth > 0:
            depth -= 1
            if depth == 0:
                sel = css[sel_start:open_pos].strip()
                if not sel.startswith("@") and "{" not in sel:
                    out.append((sel, open_pos + 1, m.start()))
                prev_end = m.end()
    return out if depth == 0 else []


def sel_matches(selector, element):
    """Any element word (case/punct-insensitive) present in the
    selector as a whole token (element may be 'html, body')."""
    for word in re.findall(r"[\w-]+", element):
        if len(word) < 2:
            continue
        if re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(word),
                     selector, re.I):
            return True
    return False


def note(line):
    os.makedirs(os.path.dirname(APPLIED_MD), exist_ok=True)
    with open(APPLIED_MD, "a", encoding="utf-8") as f:
        f.write(line.rstrip("\n") + "\n")


def record(item_id, prop, old, new, sha):
    os.makedirs(os.path.dirname(STATE_TSV), exist_ok=True)
    with open(STATE_TSV, "a", encoding="utf-8") as f:
        f.write("%s\t%s\t%s\t%s\t%s\t%s\n"
                % (item_id, now(), prop, old, new, sha))


def file_sha(path):
    import hashlib
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def write_atomic(path, text):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".",
                               suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def apply_change(prop, direction, element, item_id, value=None):
    """Apply one whitelisted edit to STYLE. Returns 0 on apply, clamp
    refusal, or recorded skip; 1 only when style.css is unusable."""
    if not os.path.exists(STYLE):
        return _style_unusable(item_id)
    with open(STYLE, encoding="utf-8") as f:
        css = f.read()
    if css.count("{") != css.count("}"):
        return _style_unusable(item_id)
    rs = rules(css)
    if prop == "font-size":
        # 'base font size' is explicit in the ingest shorthand: the edit
        # targets the base font rule, never a per-element rule.
        idx = next((i for i, r in enumerate(rs)
                    if re.search(r"(?<![\w-])(body|html)(?![\w-])",
                                 r[0], re.I)
                    and get_value(css[r[1]:r[2]], "font-size")), None)
        if idx is None:
            return _style_unusable(item_id)
    else:
        idx = next((i for i, r in enumerate(rs)
                    if sel_matches(r[0], element)), None)
    if idx is None:
        tok = re.sub(r"[^\w-]+", "", element)
        if not tok:
            note("%s unparseable request %s: no element, left unapplied"
                 % (now(), item_id))
            return 0
        sel = element.strip() if re.match(r"^[.#]?[A-Za-z][\w-]*$",
                                          element.strip()) else "." + tok
        block = ""
        if APPEND_STATE[0] >= APPEND_CAP:
            note("%s append cap (%d) reached; item %s left unapplied"
                 % (now(), APPEND_CAP, item_id))
            return 0
    else:
        sel, bs, be = rs[idx]
        block = css[bs:be]
    old = get_value(block, prop)
    if prop == "color":
        new = value
    else:
        num = re.match(r"-?[\d.]+", old or "")
        cur = float(num.group()) if num else float(
            baseline_get(prop) if baseline_get(prop) is not None
            else BASELINE_DEFAULTS[prop])
        base = baseline_get(prop)
        if base is None:
            baseline_set(prop, cur)
            base = cur
        delta = WHITELIST.get(prop, ("", 2))[1]
        requested = max(0.0, cur + direction * delta)
        lo, hi = base - DRIFT_LIMIT, base + DRIFT_LIMIT
        if requested < lo or requested > hi:
            note("%s baseline clamp refused for item %s: %.0fpx outside "
                 "baseline %.0f +/-%d" % (now(), item_id, requested,
                                          base, DRIFT_LIMIT))
            crumb("clamp", "%s: %s %s -> %.0f refused"
                  % (item_id, prop, element, requested))
            return 0
        new = "%dpx" % round(requested)
    if appended := (idx is None):
        rule = "%s { %s: %s; }" % (sel, prop, new)
        css = css.rstrip("\n") + "\n" + rule + "\n"
        APPEND_STATE[0] += 1
        old_line = "(new rule)"
    else:
        newblock = set_value(block, prop, new)[1]
        css = css[:bs] + newblock + css[be:]
        old_line = old or "(absent)"
    write_atomic(STYLE, css)
    sha = file_sha(STYLE)
    record(item_id, prop, old_line, new, sha)
    note("| %s | %s | %s | %s | %s | %s | %d | %s |"
         % (now(), item_id, sel, prop, old_line, new, appended, sha))
    crumb("apply", "%s: %s %s %s -> %s" % (item_id, sel, prop, old_line,
                                           new))
    return 0


APPEND_STATE = [0]


def _style_unusable(item_id):
    note("%s correction: style.css missing or unparseable; item %s "
         "not applied" % (now(), item_id))
    report("alert", "feedback-apply: style.css missing or unparseable; "
            "quick item %s left unapplied" % item_id,
            "correction-style-css")
    return 1


def report(kind, text, identity, window="604800"):
    """One row through the real report-queue contract (seamed root)."""
    env = dict(os.environ)
    env.setdefault("HNGH_REPORT_ROOT", REPORT_KERNEL)
    try:
        return subprocess.run(
            [sys.executable,
             os.path.join(REPORT_KERNEL, "scripts", "report-queue"),
             "--add", kind, text, "--identity", identity,
             "--window", window],
            env=env, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as exc:
        print("feedback-apply: report failed: %s" % exc, file=sys.stderr)
        return None


def correction(item_id, element, body):
    """Auto-inspect only: run the named check, file the result row."""
    m = CHECK_RE.search("%s %s" % (element, body))
    if not m:
        report("alert", "correction %s: no named check found (%s)"
               % (item_id, (body or element or "unparseable")[:120]),
               "correction-" + item_id)
        crumb("inspect", "%s: no named check" % item_id)
        return 0
    path = os.path.join(AUTOMATION_ROOT, m.group(1))
    if not os.path.exists(path):
        report("alert", "correction %s: named check %s not found"
               % (item_id, m.group(1)), "correction-" + item_id)
        crumb("inspect", "%s: check missing" % item_id)
        return 0
    runner = [sys.executable, path] if path.endswith(".py") \
        else ["bash", path]
    try:
        r = subprocess.run(runner, capture_output=True, text=True,
                           timeout=120, cwd=AUTOMATION_ROOT)
        rc, tail = r.returncode, (r.stdout + r.stderr).strip()[-400:]
    except (OSError, subprocess.SubprocessError) as exc:
        rc, tail = 1, "failed to run: %s" % exc
    kind = "alert" if rc else "progress"
    report(kind, "correction %s: check %s rc=%d: %s"
           % (item_id, m.group(1), rc, tail), "correction-" + item_id)
    crumb("inspect", "%s: %s rc=%d" % (item_id, m.group(1), rc))
    return 0


def parse_item(text):
    """Ledger row -> (type, quick, element, body) or None."""
    m = ITEM_ROW_RE.search(str(text))
    tail = (m.group(1) if m else str(text)).strip()
    q = QUICK_RE.match(tail)
    if not q:
        return None
    return (q.group(1), q.group(2) is not None,
            (q.group(3) or "").strip(), q.group(4).strip())


def apply_items(rows):
    """rows: [(id, type, element, body)]. Applies whitelisted quick
    items; returns number of applied changes."""
    APPEND_STATE[0] = 0
    n = 0
    for iid, ftype, element, body in rows:
        m = COLOR_RE.search("%s %s" % (element, body))
        direction = 1 if re.search(r"\bincrease\b", body, re.I) else \
            -1 if re.search(r"\bdecrease\b", body, re.I) else 0
        prop = next((p[0] for phrase, p in WHITELIST.items()
                     if phrase in body.lower()), None)
        if m and ftype in ("css-theme", "data-format"):
            ok = apply_change("color", 0, element, iid, value=m.group())
            if ok == 0:
                n += 1
        elif prop and direction:
            if apply_change(prop, direction, element, iid) == 0:
                n += 1
        else:
            crumb("skip", "%s: not whitelisted, left unapplied" % iid)
    return n


def revert_last():
    """Restore the last APPLIED.md apply line's previous value."""
    if not os.path.exists(APPLIED_MD):
        return 0
    lines = open(APPLIED_MD, encoding="utf-8").read().splitlines()
    idx = next((i for i in range(len(lines) - 1, -1, -1)
                if lines[i].startswith("| ")), None)
    if idx is None:
        return 0
    f = [c.strip() for c in lines[idx].strip("|").split("|")]
    _ts, _iid, sel, prop, old, new, appended, _sha = f[:8]
    with open(STYLE, encoding="utf-8") as fh:
        css = fh.read()
    if int(appended):
        rule = "%s { %s: %s; }" % (sel, prop, new)
        css = css.replace("\n" + rule + "\n", "\n", 1)
    else:
        rs = rules(css)
        hit = next((r for r in rs if r[0] == sel), None)
        if not hit:
            print("feedback-apply: revert: rule %r gone" % sel,
                  file=sys.stderr)
            return 1
        _s, bs, be = hit
        block = css[bs:be]
        if old in ("(absent)", ""):
            block = re.sub(r"\s*" + re.escape(prop) + r":\s*[^;}]+;?",
                           "", block, count=1)
        else:
            block = set_value(block, prop, old)[1]
        css = css[:bs] + block + css[be:]
    write_atomic(STYLE, css)
    lines.pop(idx)
    write_atomic(APPLIED_MD, "\n".join(lines) + "\n")
    crumb("revert", "%s %s %s -> %s" % (sel, prop, new, old))
    return 0


def main(argv):
    if argv and argv[0] == "--revert-last":
        return revert_last()
    if not os.path.exists(ITEMS_JSON):
        return 0
    with open(ITEMS_JSON, encoding="utf-8") as f:
        items = json.load(f).get("items", [])
    done = state_ids()
    quick_rows, fixed = [], []
    for it in items:
        parsed = parse_item(it.get("text", ""))
        if not parsed:
            continue
        ftype, quick, element, body = parsed
        if it.get("id") in done:
            continue
        if ftype == "correction":
            fixed.append((it.get("id"), ftype, element, body))
        elif ftype in ("css-theme", "data-format") and quick:
            quick_rows.append((it.get("id"), ftype, element, body))
    for iid, _t, element, body in fixed:
        correction(iid, element, body)
    apply_items(quick_rows)
    return 0


def set_value(block, prop, new):
    """Replace prop's value in a declaration block; font-size falls
    back to the font shorthand's leading size. Returns (old, block')."""
    if prop == "font-size":
        m = re.search(r"(?<![\w-])font-size:\s*([\d.]+px)", block)
        if m:
            return m.group(1), re.sub(
                r"(?<![\w-])font-size:\s*[\d.]+px", "font-size: %s" % new,
                block, count=1)
        m = re.search(r"(?<![\w-])font:\s*([\d.]+)px", block)
        if m:
            return m.group(1) + "px", re.sub(
                r"(?<![\w-])font:\s*[\d.]+px", "font: %s" % new,
                block, count=1)
        return "", block
    m = re.search(r"(?<![\w-])" + re.escape(prop) + r":\s*([^;}]+)", block)
    if not m:
        return "", block
    old = m.group(1).strip()
    first = re.match(r"(-?[\d.]+)(px)?", old)
    if prop in ("color",) or not first:
        return old, re.sub(re.escape(prop) + r":\s*[^;}]+",
                           "%s: %s" % (prop, new), block, count=1)
    rest = old[first.end():]
    return old, re.sub(re.escape(prop) + r":\s*[^;}]+",
                       "%s: %s%s" % (prop, new, rest),
                       block, count=1)


def get_value(block, prop):
    """Current value of prop in a block (font shorthand fallback)."""
    if prop == "font-size":
        m = (re.search(r"(?<![\w-])font-size:\s*([\d.]+px)", block)
             or re.search(r"(?<![\w-])font:\s*([\d.]+px)", block))
        return m.group(1) if m else ""
    m = re.search(r"(?<![\w-])" + re.escape(prop) + r":\s*([^;}]+)", block)
    return m.group(1).strip() if m else ""


def baseline_path():
    return os.path.join(os.path.dirname(STATE_TSV),
                        "feedback-baseline.tsv")


def baseline_get(prop):
    p = baseline_path()
    if os.path.exists(p):
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                f = line.rstrip("\n").split("\t")
                if f and f[0] == prop:
                    return float(f[1])
    return None


def baseline_set(prop, value):
    os.makedirs(os.path.dirname(baseline_path()), exist_ok=True)
    with open(baseline_path(), "a", encoding="utf-8") as f:
        f.write("%s\t%s\n" % (prop, value))


def state_ids():
    if not os.path.exists(STATE_TSV):
        return set()
    return {ln.split("\t", 1)[0]
            for ln in open(STATE_TSV, encoding="utf-8") if ln.strip()}


def crumb(event, detail):
    if STATE_MD:
        os.makedirs(os.path.dirname(STATE_MD), exist_ok=True)
        with open(STATE_MD, "a", encoding="utf-8") as f:
            f.write("%s | feedback-apply | %s | %s\n"
                    % (now(), event, detail.replace("|", "¦")))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
