#!/usr/bin/env python3
"""manga-draft -- P0 gag-manga publisher slice: one GDELT item -> draft panel.

Takes one ranked GDELT item (the gdelt-news.py lane shape: "BAND: headline
(url)" or the raw lane-item dict) and emits a draft panel plan: image
prompt (manga-panel style row), dialogue, narrative block, SFX, and the
GDELT source citation. Optionally renders the panel SVG skeleton
(config/manga-panel.svg) with placeholder-filled text, and optionally
generates the panel image via the existing imagegen local leg.

The draft plan IS the P0 deliverable (design: docs/records/
2026-09-12-gag-manga-pipeline.md). Dialogue is procedural placeholder
comedy -- clearly labeled as dramatization, never attributed to real
people as fact.

usage: manga-draft.py --item "NOTABLE: headline (url)" [--render out.svg]
       [--image] [--out out.json]
"""
import argparse
import json
import os
import re
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STYLES_TSV = os.path.join(ROOT, "config", "imagegen-styles.tsv")
PANEL_SVG = os.path.join(ROOT, "config", "manga-panel.svg")
DRAMA_LABEL = "[DRAMATIZATION - procedural gag, not a real quote]"

SFX_BANK = ["KRUNK", "FWOOM", "BLORT", "KRAK", "WHOOSH", "GLORP"]

# Comedy banks (2026-09-12 publication review): pools keyed by CAMEO
# class so the strip gets recurring characters (a gag strip needs a cast),
# with scene/dialogue/SFX drawn on different seed divisors so the same
# cameo class still varies. Register: dry, deadpan, evidence-adjacent
# humor -- the Saga voice (docs/dispatch "## The Saga") is the model.
# QUIP_BUDGET is the deterministic cap the publication review checks.
QUIP_BUDGET = 96
CAMEOS = ["bureaucrat", "engineer", "nightwatch"]
SCENES = {
    "bureaucrat": [
        "a bureaucrat stamping forms while the building tilts",
        "two diplomats in oversized business suits arguing over a tiny table",
        "a giant rubber stamp labeled with a treaty crashing onto a desk",
    ],
    "engineer": [
        "an engineer tightening one bolt as the whole gantry groans",
        "a tank and a paper airplane facing off across a cracked road",
        "a banker juggling floating coins while the ground rumbles",
    ],
    "nightwatch": [
        "the night watch pointing a flashlight at an empty corridor",
        "a weather reporter being blown sideways while still pointing",
        "a watchman reading incident reports by candlelight as lights flicker",
    ],
}
REACTIONS = {
    "bureaucrat": [
        "The form for this does not exist yet.",
        "Nobody reads the footnotes until the explosion.",
        "Filed under: acts of god, subsection: this.",
    ],
    "engineer": [
        "I told you the paperwork was load-bearing!",
        "It worked in the diagram. Once.",
        "This is fine. This is FINE.",
    ],
    "nightwatch": [
        "We prepared for everything except this exact thing.",
        "The log says this happened at 3 AM. It is 3 AM.",
        "Nothing in the corridor. That is the problem.",
    ],
}


def parse_item(text):
    """gdelt-news lane line -> dict: {"band", "headline", "url"}.
    Accepts the rendered "BAND: headline (url)" shape; returns None on
    garbage (fail-closed caller decides)."""
    m = re.match(r"^[A-Z]+:\s*(.+?)\s*\((https?://[^)]+)\)\s*$", text.strip())
    if not m:
        return None
    return {"band": text.split(":", 1)[0], "headline": m.group(1), "url": m.group(2)}


def _pick(bank, seed):
    return bank[seed % len(bank)]


def _fill(template, subject):
    return template.replace("{SUBJECT}", subject)


def image_prompt(styles_tsv, subject):
    """manga-panel style row -> resolved image prompt (template splice).
    Returns (style_id, prompt) or (None, None) when the row is missing."""
    try:
        with open(styles_tsv, encoding="utf-8") as fh:
            for line in fh:
                cols = line.rstrip("\n").split("\t")
                if cols and cols[0] == "manga-panel" and len(cols) >= 6:
                    return cols[0], _fill(cols[4], subject)
    except OSError:
        pass
    return None, None


def _wrap(text, width=38):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = ("%s %s" % (cur, w)).strip()
    if cur:
        lines.append(cur)
    return lines


def plan_for(item, styles_tsv=STYLES_TSV):
    """One GDELT item -> draft panel plan dict (the P0 deliverable).
    Deterministic on the headline so the same item drafts the same panel."""
    seed = sum(item["headline"].encode("utf-8"))
    subject = item["headline"].lower()[:120]
    style_id, prompt = image_prompt(styles_tsv, subject)
    cameo = _pick(CAMEOS, seed // 5)
    sfx = _pick(SFX_BANK, seed)
    scene = _pick(SCENES[cameo], seed // 7)
    reaction = _pick(REACTIONS[cameo], seed // 3)
    return {
        "band": item["band"],
        "headline": item["headline"],
        "url": item["url"],
        "style_id": style_id,
        "image_prompt": prompt,
        "cameo": cameo,
        "scene": scene,
        "caption": "MEANWHILE, IN WORLD NEWS...",
        "dialogue": reaction,
        "sfx": sfx,
        "narrative": "Grounded event: %s (severity %s). Source cited below."
                     % (item["headline"], item["band"]),
        "attribution": "%s -- GDELT 2.0 export, %s" % (DRAMA_LABEL, item["url"]),
    }


def render_svg(plan, panel_svg=PANEL_SVG, image_href=None):
    """Fill the panel skeleton placeholders; text is XML-escaped. Returns
    the SVG text or None when the skeleton is missing (fail-closed)."""
    try:
        with open(panel_svg, encoding="utf-8") as fh:
            svg = fh.read()
    except OSError:
        return None

    def tsvg(text):
        return escape(text)

    def block(text, x, y0, dy):
        return "".join(
            '<tspan x="%d" y="%d">%s</tspan>'
            % (x, y0 + i * dy, tsvg(l)) for i, l in enumerate(_wrap(text))
        )

    parts = {
        "{{CAPTION}}": block(plan["caption"], 50, 68, 28),
        "{{DIALOGUE}}": block(plan["dialogue"], 548, 202, 24),
        "{{SFX}}": tsvg(plan["sfx"]),
        "{{NARRATIVE}}": block(plan["narrative"], 28, 700, 22),
        "{{ATTRIB}}": tsvg(plan["attribution"]),
        "{{IMAGE}}": ('<image x="18" y="18" width="988" height="632" '
                      'href="%s" preserveAspectRatio="xMidYMid"/>' % image_href)
                      if image_href else "",
    }
    for key, val in parts.items():
        svg = svg.replace(key, val)
    return svg


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--item", required=True,
                    help='gdelt-news lane line: "BAND: headline (url)"')
    ap.add_argument("--out", help="write the JSON plan here (default: stdout)")
    ap.add_argument("--render", metavar="SVG_OUT",
                    help="render the panel skeleton with plan text to SVG_OUT")
    ap.add_argument("--image", action="store_true",
                    help="also generate the panel image via the imagegen local leg")
    args = ap.parse_args(argv[1:])

    item = parse_item(args.item)
    if not item:
        print("manga-draft: item does not match 'BAND: headline (url)'",
              file=sys.stderr)
        return 2
    plan = plan_for(item)
    payload = json.dumps(plan, indent=2, ensure_ascii=True) + "\n"
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(payload)
    else:
        sys.stdout.write(payload)

    if args.render:
        svg = render_svg(plan)
        if svg is None:
            print("manga-draft: panel skeleton missing -- fail-closed",
                  file=sys.stderr)
            return 1
        with open(args.render, "w", encoding="utf-8") as fh:
            fh.write(svg)
        print("manga-draft: rendered %s" % args.render, file=sys.stderr)

    if args.image and plan["image_prompt"]:
        os.system(  # ponytail: one bounded shell-out; subprocess if this grows
            "%s --style manga-panel --subject %s"
            % (os.path.join(ROOT, "jobs", "imagegen-submit.sh"),
               json.dumps(plan["scene"]))
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
