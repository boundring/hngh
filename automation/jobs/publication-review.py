#!/usr/bin/env python3
"""publication-review -- standing two-pass review of published artifacts.

Every UTC day the latest manga draft (+ its rendered SVG when present)
and the latest docs/dispatch/<date>.md get the supportive/adversarial
review, as structured deterministic checklists derived from
docs/research/2026-09-12-publication-review-01.md. P0 stays
deterministic: no model call (a cheap-leg commentary may attach later
outside this script). Findings are written to
automation/digest/PUBLICATION-REVIEW-<date>.md (supportive +
adversarial sections), red findings become report-queue rows, and
persistent same-cause failures escalate via the blocker ledger: the
shell caller maps printed `FAIL <artifact> <cause>` lines onto scope
publication:<artifact> (same-cause attempts park; success clears).

Fail-closed: every expected path exits 0 -- red is an alert, never a
dropped signal. Only a usage error exits 2.

usage: jobs/publication-review.py [--repo DIR] [--report-root DIR]
              [--date YYYY-MM-DD]
prints: one `PASS <check>` / `FAIL <artifact> <cause> <detail>` line
        per adversarial check; stdout is the machine contract.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DRAMA_LABEL = "[DRAMATIZATION - procedural gag, not a real quote]"
QUIP_BUDGET = 96  # mirror of jobs/manga-draft.py QUIP_BUDGET


def latest(pattern):
    """Newest path matching glob (mtime), or None."""
    paths = sorted(glob.glob(pattern), key=os.path.getmtime)
    return paths[-1] if paths else None


def _checks():
    return {"supportive": [], "adversarial": []}


def check_manga(draft_path):
    """Structured checklist for one manga draft. Returns
    (passes, fails, art_ok) where fails are (artifact, cause, detail)."""
    art = os.path.splitext(draft_path)[0] + ".svg"  # rendered panel
    png = os.path.splitext(draft_path)[0] + ".png"
    c = _checks()
    try:
        draft = json.load(open(draft_path, encoding="utf-8"))
    except (OSError, ValueError) as exc:
        c["adversarial"].append((draft_path, "draft-unreadable", str(exc)))
        return c, False

    def sup(check, ok, detail):
        c["supportive"].append((check, bool(ok), detail))

    def adv(cause, ok, detail, artifact=draft_path):
        if ok:
            c["adversarial"].append(("pass-" + cause, True, detail))
        else:
            c["adversarial"].append((artifact, cause, detail))
        return ok

    attrib = draft.get("attribution", "")
    sup("attribution-footer", attrib.startswith(DRAMA_LABEL)
        and draft.get("url", "") in attrib, attrib[:80])
    sup("grounded-strip", "Grounded event:" in draft.get("narrative", "")
        and "Source cited" in draft.get("narrative", ""),
        draft.get("narrative", "")[:80])
    sup("caption-present", bool(draft.get("caption")), draft.get("caption", ""))
    sup("sfx-present", bool(draft.get("sfx")), draft.get("sfx", ""))
    sup("quip-budget", len(draft.get("dialogue", "")) <= QUIP_BUDGET,
        "dialogue %d/%d chars" % (len(draft.get("dialogue", "")), QUIP_BUDGET))

    adv("panel-art-missing", os.path.isfile(art)
        and "<image" in open(art, encoding="utf-8").read()
        or os.path.isfile(png),
        "no rendered panel art (ComfyUI leg 8188 down)")
    adv("cameo-missing", bool(draft.get("cameo")),
        "no recurring character in draft")
    adv("quip-budget-overage", len(draft.get("dialogue", "")) <= QUIP_BUDGET,
        "dialogue %d chars > budget %d" % (len(draft.get("dialogue", "")),
                                           QUIP_BUDGET))
    art_ok = os.path.isfile(art) and "<image" in open(
        art, encoding="utf-8").read() or os.path.isfile(png)
    if os.path.isfile(art):
        svg = open(art, encoding="utf-8").read()
        m = re.search(r'<rect x="14" y="14" width="996" height="(\d+)"',
                      svg)
        adv("art-zone-ratio",
            m is not None and int(m.group(1)) >= 0.7 * 792,
            "art zone height %s (want >= 554 of 792)"
            % (m.group(1) if m else "?"))
        t = re.search(r'<ellipse cx="(\d+)" cy="(\d+)" rx="(\d+)"', svg)
        adv("bubble-third-point",
            t is not None and int(t.group(1)) > 512 and int(t.group(2)) < 400,
            "bubble anchor %s,%s (want upper-right third point)"
            % (t.group(1), t.group(2)) if t else "no bubble in panel")
    return c, art_ok


QUIET_RE = re.compile(r"^- none \? quiet window\s*$")
ITEM_RE = re.compile(r"^- (CRITICAL|NOTABLE|CONTEXT):")


def check_dispatch(md_path):
    """Structured checklist for one dispatch edition. Returns
    (passes, fails); fails are (artifact, cause, detail)."""
    c = _checks()
    try:
        text = open(md_path, encoding="utf-8").read()
    except OSError as exc:
        c["adversarial"].append((md_path, "dispatch-unreadable", str(exc)))
        return c

    def sup(check, ok, detail):
        c["supportive"].append((check, bool(ok), detail))

    def adv(cause, ok, detail, artifact=md_path):
        if ok:
            c["adversarial"].append(("pass-" + cause, True, detail))
        else:
            c["adversarial"].append((artifact, cause, detail))

    sup("masthead", "The Machine Hall - Daily Dispatch" in text, "masthead")
    quiet = items = 0
    for line in text.splitlines():
        if QUIET_RE.match(line):
            quiet += 1
        elif ITEM_RE.match(line):
            items += 1
    sup("deck-a-variety", items > 0, "%d Deck A items" % items)
    sup("quiet-window-honesty", quiet > 0 or items > 0,
        "%d quiet windows, %d items" % (quiet, items))
    # quiet honesty is adversarial when a quiet window still lists items:
    honest = True
    section_items = 0
    seen_quiet = False
    for line in text.splitlines():
        if line.startswith("### "):
            section_items = 0
            seen_quiet = False
        elif QUIET_RE.match(line):
            seen_quiet = True
        elif ITEM_RE.match(line):
            section_items += 1
        if seen_quiet and section_items:
            honest = False
    adv("quiet-window-dishonest", honest,
        "quiet window carries items" if not honest else "quiet windows clean")
    adv("deck-a-quip-layer-missing",
        bool(re.search(r"^_quip:", text, re.M)) or items == 0,
        "Deck A has %d items, 0 quips (summary/quip layer pending the "
        "sibling digest renderer overhaul)" % items)
    return c


def findings_md(day, manga_c, dispatch_c, manga_src, dispatch_src):
    out = ["# publication review %s" % day, "",
           "_manga: %s | dispatch: %s_" % (manga_src, dispatch_src), "",
           "## Supportive pass", ""]
    for check, ok, detail in manga_c["supportive"] + dispatch_c["supportive"]:
        out.append("- [%s] %s -- %s" % ("ok" if ok else "MISS", check, detail))
    out += ["", "## Adversarial pass", ""]
    for item in manga_c["adversarial"] + dispatch_c["adversarial"]:
        if len(item) == 3 and isinstance(item[0], str) and not item[0].startswith("pass-"):
            out.append("- FAIL %s: %s -- %s" % item)
        else:
            out.append("- ok %s -- %s" % (item[0][5:], item[2]))
    return "\n".join(out) + "\n"


def report(kind, text, report_root=None):
    report_root = report_root or ROOT
    env = dict(os.environ, HNGH_REPORT_ROOT=report_root or ROOT)
    subprocess.run(
        [sys.executable, os.path.join(ROOT, "scripts", "report-queue"),
         "--add", kind, text, "--identity", "publication-review",
         "--window", "86400"],
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        check=False)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=ROOT)
    ap.add_argument("--report-root", default="")
    ap.add_argument("--date", default="")
    args = ap.parse_args(argv)
    day = args.date or __import__("datetime").date.today().isoformat()
    manga = latest(os.path.join(args.repo, "docs/media/manga/*-draft.json"))
    dispatch = latest(os.path.join(args.repo, "docs/dispatch/2???-??-??.md"))
    if not manga or not dispatch:
        report("alert", "publication-review: no manga draft or no dispatch "
               "edition found (manga=%s dispatch=%s)" % (manga, dispatch))
        return 0
    mc, _art_ok = check_manga(manga)
    dc = check_dispatch(dispatch)
    os.makedirs(os.path.join(args.repo, "automation/digest"), exist_ok=True)
    out = os.path.join(args.repo, "automation/digest",
                       "PUBLICATION-REVIEW-%s.md" % day)
    open(out, "w", encoding="utf-8").write(
        findings_md(day, mc, dc, manga, dispatch))
    fails = [i for i in mc["adversarial"] + dc["adversarial"]
             if isinstance(i[0], str) and not i[0].startswith("pass-")]
    if fails:
        report("alert", "publication-review %s: %d red check(s): %s"
               % (day, len(fails), "; ".join("%s %s" % (os.path.basename(f[0]), f[1]) for f in fails)))
        for artifact, cause, _ in fails:
            print("FAIL %s %s" % (artifact, cause))
    else:
        report("progress", "publication-review %s: all checks green" % day)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
