#!/usr/bin/env python3
"""research-feed — build dashboard/research.json, the alternation-cycle
spine for the dashboard's Research tab.

Read-only over the hngh repo (HNGH_REPO, default /home/bricker/Projects/etc/hngh)
and the llm-wiki sources dir:

  · alternation: master-plan DesignPlan facet — grow beats (hngh commits)
    alternate with research/design beats (doc work). last_grow is the newest
    commit's committer date (git log -1 --format=%cI); last_research is the
    newest mtime under docs/research/ or docs/design/; `due` names the beat
    the pair calls for next (the beat NOT done most recently; the two within
    BALANCED_WINDOW_S count as balanced).
  · research_lanes: backlog.md '## ' rungs whose heading matches
    research|design|survey|spec, each with its (wrapped) first Problem line.
  · design_docs: name + first 'Status:' line for every docs/design/*.md.
  · open_questions: bullets under '## Open questions' in docs/design/*.md,
    newest docs first, max 20.
  · lessons: llm-wiki source count + 3 newest filenames.

Fail-closed per source: a source that cannot be read yields an
{"error": "..."} object in its slot instead of a row list; the rest of the
feed still lands. Output is written atomically (tmp + os.replace). Display
layer only — never governance input.
"""
import os
import json
import re
import subprocess
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "dashboard", "research.json")
HNGH_REPO = os.environ.get("HNGH_REPO", "/home/bricker/Projects/etc/hngh")
WIKI_SOURCES = os.path.join(
    os.path.expanduser("~"), ".llm-wiki", "wiki", "sources")

LANE_RE = re.compile(r"(?i)research|design|survey|spec")
MAX_QUESTIONS = 20
GIT_TIMEOUT = 10


def balanced_window_s():
    """Balance window seconds: env HNGH_BALANCED_WINDOW_S, then the
    cadence-params.tsv inventory row, else the 6h default (unchanged)."""
    v = os.environ.get("HNGH_BALANCED_WINDOW_S")
    if not v:
        try:
            with open(os.path.join(ROOT, "cadence-params.tsv"),
                      encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) > 1 and parts[0] == "balanced-window-s":
                        v = parts[1]
                        break
        except OSError:
            pass
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 6 * 3600


BALANCED_WINDOW_S = balanced_window_s()


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fail(err):
    return {"error": str(err)}


# ---------------------------------------------------------------- alternation

def last_grow():
    """Newest hngh commit timestamp (ISO-8601, committer date)."""
    try:
        out = subprocess.run(
            ["git", "log", "-1", "--format=%cI"], cwd=HNGH_REPO,
            capture_output=True, text=True, timeout=GIT_TIMEOUT, check=True
        ).stdout.strip()
        return out or None, None
    except Exception as e:
        return None, "%s: %s" % (type(e).__name__, e)


def last_research():
    """Newest mtime under docs/research/ or docs/design/ (UTC ISO)."""
    base = os.path.join(HNGH_REPO, "docs")
    newest = None
    try:
        for sub in ("research", "design"):
            d = os.path.join(base, sub)
            for dirpath, _dirs, files in os.walk(d):
                for f in files:
                    m = os.path.getmtime(os.path.join(dirpath, f))
                    if newest is None or m > newest:
                        newest = m
    except Exception as e:
        return None, "%s: %s" % (type(e).__name__, e)
    if newest is None:
        return None, "no files under docs/research/ or docs/design/"
    return iso(datetime.fromtimestamp(newest, timezone.utc)), None


def alternation():
    grow, grow_err = last_grow()
    research, research_err = last_research()
    due = None
    if grow and research:
        try:
            g = datetime.fromisoformat(grow).timestamp()
            r = datetime.fromisoformat(research).timestamp()
            # the beat NOT done most recently is the one due next
            if abs(g - r) < BALANCED_WINDOW_S:
                due = "balanced"
            elif r > g:
                due = "grow"
            else:
                due = "research"
        except ValueError as e:
            grow_err = grow_err or "timestamp parse: %s" % e
    return {
        "last_grow": grow,
        "last_research": research,
        "due": due,
        "balance_window_s": BALANCED_WINDOW_S,
        "errors": [e for e in (grow_err, research_err) if e],
    }


# ------------------------------------------------------------------ backlog

def problem_line(lines, start):
    """First 'Problem:' bullet at `start`, joined across wrapped lines."""
    parts = [re.sub(r"^\s*-\s*\*\*Problem:\*\*\s*", "", lines[start])]
    i = start + 1
    while i < len(lines):
        s = lines[i].strip()
        if not s or s.startswith("- ") or s.startswith("#"):
            break
        parts.append(s)
        i += 1
    return re.sub(r"\s+", " ", " ".join(parts)).strip()


def research_lanes():
    path = os.path.join(HNGH_REPO, "docs", "project", "backlog.md")
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except Exception as e:
        return fail("%s: %s" % (type(e).__name__, e))
    lanes, heading_at = [], None
    for i, line in enumerate(lines):
        if line.startswith("## "):
            # dashboard-proposed lanes are consumed regardless of name:
            # they must surface (with their note button) even when the
            # operator's lane name doesn't say research/design/survey/spec.
            heading_at = i if (LANE_RE.search(line[3:])
                               or "proposed via dashboard" in line) else None
            if heading_at is not None:
                lanes.append({"name": line[3:].strip(), "problem": None})
        elif heading_at is not None and lanes and lanes[-1]["problem"] is None:
            if re.match(r"^\s*-\s*\*\*Problem:\*\*", line):
                lanes[-1]["problem"] = problem_line(lines, i)
    return lanes


# --------------------------------------------------------------- design docs

def design_docs():
    d = os.path.join(HNGH_REPO, "docs", "design")
    try:
        names = sorted(f for f in os.listdir(d) if f.endswith(".md"))
    except Exception as e:
        return fail("%s: %s" % (type(e).__name__, e))
    out = []
    for name in names:
        status = None
        try:
            with open(os.path.join(d, name), encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("Status:"):
                        status = line.strip()
                        break
        except Exception as e:
            status = "(unreadable: %s)" % type(e).__name__
        out.append({"name": name[:-3], "status_line": status})
    return out


def open_questions():
    """Bullets under '## Open questions', newest docs first, max 20 total."""
    d = os.path.join(HNGH_REPO, "docs", "design")
    try:
        names = [f for f in os.listdir(d) if f.endswith(".md")]
        names.sort(key=lambda f: os.path.getmtime(os.path.join(d, f)),
                   reverse=True)
    except Exception as e:
        return fail("%s: %s" % (type(e).__name__, e))
    out = []
    for name in names:
        try:
            with open(os.path.join(d, name), encoding="utf-8") as fh:
                lines = fh.read().splitlines()
        except Exception:
            continue
        in_sec, cur = False, None

        def flush():
            if cur is not None and cur["text"]:
                out.append({"doc": name[:-3], "question": cur["text"]})
        for line in lines:
            if line.startswith("## "):
                flush()
                cur = None
                in_sec = line.strip().lower() == "## open questions"
            elif in_sec and re.match(r"^\s*-\s+", line):
                flush()
                cur = {"text": re.sub(r"^\s*-\s+", "", line).strip()}
            elif in_sec and cur is not None and line.strip():
                cur["text"] = (cur["text"] + " " + line.strip()).strip()
        flush()
        if len(out) >= MAX_QUESTIONS:
            break
    return out[:MAX_QUESTIONS]


# ------------------------------------------------------------------ lessons

def lessons():
    try:
        entries = os.listdir(WIKI_SOURCES)
    except Exception as e:
        return fail("%s: %s" % (type(e).__name__, e))
    try:
        newest = sorted(entries, key=lambda f: os.path.getmtime(
            os.path.join(WIKI_SOURCES, f)), reverse=True)
    except OSError as e:
        newest = entries
    return {"count": len(entries), "recent": newest[:3]}


def research_lines():
    """Research-line lifecycle rows from research-lines.tsv (id, state,
    updated, line). Missing file -> empty list (the beat seeds it)."""
    path = os.path.join(ROOT, "research-lines.tsv")
    out = []
    try:
        with open(path, encoding="utf-8") as fh:
            for raw in fh:
                parts = raw.rstrip("\n").split("\t")
                if len(parts) == 4:
                    out.append({"id": parts[0], "state": parts[1],
                                "updated": parts[2], "line": parts[3]})
    except OSError:
        return []
    return out


def main():
    feed = {
        "generated": iso(datetime.now(timezone.utc)),
        "alternation": alternation(),
        "research_lanes": research_lanes(),
        "design_docs": design_docs(),
        "open_questions": open_questions(),
        "lessons": lessons(),
        "lines": research_lines(),
    }
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(feed, fh, indent=1)
    os.replace(tmp, OUT)
    print("research-feed: lanes=%s docs=%s questions=%s lessons=%s due=%s" % (
        len(feed["research_lanes"]) if isinstance(feed["research_lanes"], list) else "ERR",
        len(feed["design_docs"]) if isinstance(feed["design_docs"], list) else "ERR",
        len(feed["open_questions"]) if isinstance(feed["open_questions"], list) else "ERR",
        feed["lessons"].get("count", "ERR"),
        feed["alternation"]["due"]))
    print("research-feed: lines=%s" % (
        len(feed["lines"]) if isinstance(feed["lines"], list) else "ERR",))

if __name__ == "__main__":
    main()
