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

Multi-pass pipeline (2026-09-12 operator verdict: the one-shot panel was
"horrifying"; the cure is procedural passes, not one-shot prompting):
  --script     pass 1: JSON beats (setup -> reaction -> gag) with visual
               notes (cast in frame, camera, eye order)
  --wireframe  pass 2: SVG layout contract from the script -- gutters,
               bubble/box placement, stick-figure poses (pose library),
               focal-action marks
  --components pass 3: per-region component prompts (environment plate,
               actor pieces) emitted as bounded imagegen requests via the
               managed ComfyUI leg (COMPONENT_BUDGET gens per panel)
  --assemble   pass 4: composite components under the existing bubble/SFX/
               caption layers, post-process (screentone overlay, ink
               unification via magick), render final PNG
Stages land in docs/media/manga/<name>/ as script.json, wireframe.svg,
components/, panel.svg, panel.png.
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

# SFX bank (2026-09-12 operator critique: "one KRAK and nothing else" is the
# failure mode): onomatopoeia keyed to CAMEO class, 3-4 variants each, picked
# on a different seed divisor so the same cameo still varies its sound.
SFX_BANK = {
    "bureaucrat": ["KRAK", "WHUMP", "TAK-TAK-TAK", "STAMP-STAMP"],
    "engineer": ["KRAK", "FWOOOSH", "CLANG", "BZZT"],
    "nightwatch": ["DING", "TOKU-TOKU", "FWOOOSH", "BZZT"],
}
# Margin notes: the second small text element a sparse panel needs
# (hand-written register, kept dry).
MARGIN_NOTES = [
    "note: it was, in fact, not fine.",
    "corridor B, 03:07. again.",
    "initials: [illegible]",
    "the bolt held. the diagram lied.",
    "stamped twice by mistake. no retractions.",
    "witnesses: one cat, unimpressed.",
]

# Comedy banks (2026-09-12 publication review): pools keyed by CAMEO
# class so the strip gets recurring characters (a gag strip needs a cast),
# with scene/dialogue/SFX drawn on different seed divisors so the same
# cameo class still varies. Register: dry, deadpan, evidence-adjacent
# humor -- the Saga voice (docs/dispatch "## The Saga") is the model.
# QUIP_BUDGET is the deterministic cap the publication review checks.
QUIP_BUDGET = 96
CAMEOS = ["bureaucrat", "engineer", "nightwatch"]

# Component budget: max generations per panel per run (operator directive:
# component pieces in SMALLER image requests, 3 gens/panel for the P0
# slice). Style row size bounds are 512-768 px.
COMPONENT_BUDGET = 3

# The style core -- hngh's own ink style, evolved in ONE place. Every
# component prompt inherits this string verbatim. Descriptor language
# only, never artist names (test-enforced; the study references live in
# docs/design/manga-style-research.md as reading notes, not prompt data).
STYLE_CORE = ("monochrome ink illustration, bold confident ink linework, "
              "dense cross-hatching on shadow and towering dark structures, "
              "screentone shading, vast negative space, high contrast "
              "black and white, muted desaturated accents, moss and bone "
              "motifs, cathedral-scale brutalist machine architecture, "
              "clean white ground, no text in image")

# Pose library: simple stick-figure poses keyed to beat type. Each pose
# is a tiny SVG fragment generator (head + spine + limbs), drawn by
# wireframe_svg in the actor's panel slot. 6 poses cover the beat grammar.
POSE_LIBRARY = {
    "standing-deadpan": {},   # vertical spine, arms at sides
    "reacting": {},           # spine lean-back, arms up
    "small-in-frame": {},     # distant figure, arms down
    "pointing": {},           # one arm extended
    "crouched": {},           # bent spine over a desk/console
    "walking-away": {},       # spine slight forward, mid-step
}

# Character sheets: the consistency anchor (same seed + same descriptor =
# same character across panels). File committed; appearance descriptors
# are cast TEXT, seeds are per-cameo pins (imagegen-styles.tsv seed rule).
CAST_JSON = os.path.join(ROOT, "config", "manga-cast.json")

# NARRATION register (operator steer 2026-09-12): the dry narration mode
# of serious gekiga autobiography -- flat declarative narration of the
# machine's small dramas, played absolutely straight. Humor comes from
# CARE: knowing the subject deeply enough to play it straight. These
# caption-voice lines sit above the gag (setup beat), deadpan, factual.
NARRATIONS = [
    "Another shift began. The building did not care.",
    "It was an ordinary day in the hall. That was the problem.",
    "The paperwork arrived on schedule. Everything else did not.",
    "The corridor had been quiet for three days. Too quiet, on review.",
    "The craft of filing was, as ever, underrated.",
]
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


def load_cast(path=CAST_JSON):
    """Character sheets: cameo -> {appearance, seed}. Fail-closed: a
    missing sheet leaves the cameo unstyled (wireframe still draws)."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def script_for(plan):
    """Pass 1 -- the SCRIPT layer: panel beats (setup -> reaction -> gag)
    with per-beat visual notes (who's in frame, camera angle, what the
    eye hits in order) and a stick pose from the library. Deterministic
    on the plan seed; the cameo's character sheet feeds the visual notes.
    The narration register (serious-manga deadpan) rides the setup beat."""
    seed = plan["seed"]
    cameo = plan["cameo"]
    cast = load_cast().get(cameo, {})
    narration = _pick(NARRATIONS, seed // 17)
    return {
        "narration": narration,
        "beats": [
            {"kind": "setup", "cast": [cameo], "pose": "standing-deadpan",
             "camera": "wide, figure small against the machinery",
             "eye": "narration caption first, then the tilted structure",
             "visual": plan["scene"] + ". " + narration},
            {"kind": "reaction", "cast": [cameo], "pose": "reacting",
             "camera": "medium, face in frame, star-highlight eyes",
             "eye": "the face, then the focal action behind it",
             "visual": "close on %s reacting; %s" % (cameo, plan["sfx"])},
            {"kind": "gag", "cast": [cameo], "pose": "pointing",
             "camera": "medium-wide, diagonal depth to the focal action",
             "eye": "the dialogue bubble, then the aftermath",
             "visual": plan["dialogue"]},
        ],
        "cast_sheet": {"cameo": cameo, "appearance":
                       cast.get("appearance", cameo), "seed":
                       cast.get("seed", seed)},
    }


def _stick(x, y, h, pose, seed):
    """One stick figure: head circle + spine + limbs, hand-drawn jitter
    from the seed. (x, y) is the ground point, h the total height."""
    r = h * 0.14
    hip = y - h * 0.45
    neck = y - h * 0.72
    lean = {"reacting": -h * 0.08, "crouched": h * 0.22,
            "walking-away": h * 0.05}.get(pose, 0)
    j = ((seed % 7) - 3)  # deterministic limb jitter
    if pose == "reacting":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (neck - r, neck + 4, neck - h * 0.3, neck - h * 0.2,
                   neck + r, neck + 4, neck + h * 0.3, neck - h * 0.2))
    elif pose == "pointing":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (neck - r, neck + 4, neck - h * 0.28, neck + h * 0.12,
                   neck + r, neck + 4, neck + h * 0.34, neck - h * 0.06))
    elif pose == "crouched":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (neck - r, neck + 4, neck - h * 0.3, neck + h * 0.18))
    else:
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (neck - r, neck + 4, neck - h * 0.3, hip + 8,
                   neck + r, neck + 4, neck + h * 0.3, hip + 8))
    return ('<g transform="translate(%.1f %.1f)">'
            '<circle cx="%.1f" cy="%.1f" r="%.1f"/>'
            '<line x1="0" y1="%.1f" x2="%.1f" y2="%.1f"/>%s'
            '<line x1="0" y1="%.1f" x2="%.1f" y2="%d"/>'
            '<line x1="0" y1="%.1f" x2="%.1f" y2="%d"/></g>'
            % (x, y, lean * 0.4, neck - r, r, neck, lean, hip,
               arms, hip, -h * 0.16 + j, y, hip, h * 0.16 + j, y))


def wireframe_svg(plan, script, width=1024, height=820):
    """Pass 2 -- the procedural wireframe: panel frame + gutter, per-beat
    actor slots (pose-library stick figures), speech bubble + caption box
    placement, focal-action arrow. The layout contract for later passes:
    every later layer lands inside these coordinates. data-beat /
    data-pose / data-focal attributes make the contract inspectable."""
    seed = plan["seed"]
    art = {"x": 18, "y": 18, "w": width - 36, "h": 632}
    beats = script["beats"]
    slots = []  # horizontal thirds: one beat per slot, reading order L->R
    for i, b in enumerate(beats):
        slots.append((art["x"] + i * art["w"] // len(beats),
                      art["w"] // len(beats)))
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" '
             'height="%d" viewBox="0 0 %d %d">' % (width, height,
                                                   width, height),
             '<rect width="%d" height="%d" fill="#f7f2e7"/>' % (width,
                                                                height),
             '<rect x="%d" y="%d" width="%d" height="%d" fill="#ffffff" '
             'stroke="#141414" stroke-width="6"/>'
             % (art["x"], art["y"], art["w"], art["h"])]
    # gutter separators between beat slots
    for i in range(1, len(beats)):
        gx = art["x"] + i * art["w"] // len(beats)
        parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" '
                     'stroke="#141414" stroke-width="4" '
                     'stroke-dasharray="10 6"/>'
                     % (gx, art["y"] + 8, gx, art["y"] + art["h"] - 8))
    for i, (b, (x0, w)) in enumerate(zip(beats, slots)):
        cx = x0 + w // 2
        gy = art["y"] + art["h"] - 24
        h = art["h"] * (0.62 if b["pose"] != "small-in-frame" else 0.3)
        parts.append('<g data-beat="%d" data-kind="%s" data-pose="%s">'
                     % (i, b["kind"], b["pose"]))
        parts.append(_stick(cx + (seed % 21) - 10, gy, h, b["pose"],
                            seed + i))
        parts.append('</g>')
    # focal-action arrow: beat 2 (the gag) aims at the beat-1 actor
    fx, fy = slots[-1][0] + slots[-1][1] // 2, art["y"] + art["h"] - 120
    parts.append('<path data-focal="%s" d="M%d %d L%d %d" '
                 'stroke="#141414" stroke-width="3" fill="none" '
                 'marker-end="url(#focalhead)"/>'
                 % (beats[-1]["kind"], fx - 90, fy + 60, fx, fy))
    # caption box (upper-left) + speech bubble (upper-right third point)
    parts += ['<rect x="%d" y="%d" width="300" height="72" fill="#ffffff" '
              'stroke="#141414" stroke-width="3"/>'
              % (art["x"] + 14, art["y"] + 14),
              '<ellipse cx="%d" cy="%d" rx="200" ry="80" fill="#ffffff" '
              'stroke="#141414" stroke-width="3"/>'
              % (art["x"] + art["w"] - 230, art["y"] + 160)]
    parts += ['<rect x="14" y="%d" width="%d" height="112" fill="#ffffff" '
              'stroke="#141414" stroke-width="3"/>'
              % (height - 152, width - 28),
              '<text x="14" y="%d" font-size="11" fill="#141414">%s</text>'
              % (height - 16, escape(plan["attribution"])),
              '<defs><marker id="focalhead" markerWidth="8" markerHeight="8" '
              'refX="6" refY="3" orient="auto"><path d="M0 0 L7 3 L0 6 Z" '
              'fill="#141414"/></marker></defs>', "</svg>"]
    return "\n".join(parts)


def component_prompts(plan, script, cast=None):
    """Pass 3 -- per-region component prompts, each bounded 512-768 px
    and capped at COMPONENT_BUDGET. Regions: (a) one environment plate
    (the scene backdrop in the hall's ink style), (b) actor pieces per
    distinct in-frame cameo (character-sheet consistency: same seed +
    same descriptor = same character across panels). Every prompt
    inherits STYLE_CORE verbatim. Budget is enforced here, not hoped
    for: the list is truncated to the cap."""
    cast = cast if cast is not None else load_cast()
    seed = plan["seed"]
    sheet = script.get("cast_sheet", {})
    actor_desc = sheet.get("appearance", script["beats"][0]["cast"][0])
    actor_seed = sheet.get("seed", seed)
    prompts = [
        {"region": "environment", "size": "768x512", "seed": seed,
         "prompt": "%s environment plate, empty of figures, %s"
                   % (plan["scene"], STYLE_CORE)},
        {"region": "actor:%s" % script["beats"][0]["cast"][0],
         "size": "512x768", "seed": actor_seed,
         "prompt": "single character, full figure, standing on a plain "
                   "white ground, %s, %s" % (actor_desc, STYLE_CORE)},
    ]
    return prompts[:COMPONENT_BUDGET]


def assemble_svg(plan, script, wireframe, components=None):
    """Pass 4 -- composite the components into the wireframe (SVG
    layering: art plate under, actors mid, text layers over) and keep
    the existing post-process chain (screentone overlay + feTurbulence
    ink unification ride the skeleton; magick tone normalization runs
    on the rasterized PNG). components maps region -> image path; a
    missing piece leaves the wireframe layer visible (never empty)."""
    env_href = (components or {}).get("environment")
    actor_hrefs = {k: v for k, v in (components or {}).items()
                   if k.startswith("actor:")}
    img = ('<image x="18" y="18" width="988" height="632" href="%s" '
           'preserveAspectRatio="xMidYMid slice"/>' % env_href
           if env_href else "")
    actors = ""
    for beat_i, beat in enumerate(script["beats"]):
        key = "actor:%s" % beat["cast"][0]
        if beat_i == 0 or key not in actor_hrefs:
            continue
        x0 = 18 + beat_i * 996 // len(script["beats"])
        actors += ('<image x="%d" y="%d" width="%d" height="%d" '
                   'href="%s" preserveAspectRatio="xMidYMax meet"/>'
                   % (x0 + 20, 18, 312, 632, actor_hrefs[key]))
    # reuse the skeleton's text/frame layers: render_svg fills every
    # placeholder; we ride the {{IMAGE}} slot as a sentinel image tag,
    # then swap that tag for the component layers (env under, actors
    # over) so the hand-drawn scene stays as the no-component fallback.
    sentinel = ('<image x="18" y="18" width="988" height="632" '
                'href="__COMPONENT_LAYERS__" '
                'preserveAspectRatio="xMidYMid"/>')
    base = render_svg(plan, image_href="__COMPONENT_LAYERS__")
    if base is None:
        return None
    if sentinel not in base:
        return None
    return base.replace(sentinel, '<g clip-path="url(#artz)">%s%s</g>'
                        % (img, actors))


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
    sfx = _pick(SFX_BANK[cameo], seed // 11)
    margin = _pick(MARGIN_NOTES, seed // 13)
    scene = _pick(SCENES[cameo], seed // 7)
    reaction = _pick(REACTIONS[cameo], seed // 3)
    narration = _pick(NARRATIONS, seed // 17)
    return {
        "band": item["band"],
        "headline": item["headline"],
        "url": item["url"],
        "style_id": style_id,
        "image_prompt": prompt,
        "seed": seed,
        "cameo": cameo,
        "scene": scene,
        "caption": "MEANWHILE, IN WORLD NEWS...",
        "dialogue": reaction,
        "sfx": sfx,
        "narration": narration,
        "margin": margin,
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

    seed = plan.get("seed", 0)
    # Hand-drawn jitter: frame tilt -0.5..0.5 deg; SFX drifts around the
    # lower-left third point with rotation and scale variance (deterministic).
    tilt = ((seed % 9) - 4) * 0.125
    sx = 90 + (seed % 5) * 14
    sy = 545 + ((seed // 5) % 4) * 12
    srot = -16 + (seed % 9)
    ssize = 46 + ((seed // 3) % 5) * 5
    sfx_attrs = ('x="%d" y="%d" font-size="%d" transform="rotate(%d %d %d)"'
                 % (sx, sy, ssize, srot, sx, sy))

    def block(text, x, y0, dy):
        return "".join(
            '<tspan x="%d" y="%d">%s</tspan>'
            % (x, y0 + i * dy, tsvg(l)) for i, l in enumerate(_wrap(text))
        )

    parts = {
        "{{CAPTION}}": block(plan["caption"], 50, 68, 28),
        "{{DIALOGUE}}": block(plan["dialogue"], 548, 202, 24),
        "{{SFX}}": tsvg(plan["sfx"]),
        "{{SFX_ATTRS}}": sfx_attrs,
        "{{TILT}}": "%.3f" % tilt,
        "{{MARGIN}}": tsvg(plan["margin"]),
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
    ap.add_argument("--script", metavar="OUT",
                    help="pass 1: write the JSON script (beats + visual notes)")
    ap.add_argument("--wireframe", metavar="OUT",
                    help="pass 2: write the SVG wireframe (layout contract)")
    ap.add_argument("--components", metavar="DIR",
                    help="pass 3: emit bounded component imagegen requests "
                         "into DIR (max %d gens/panel)" % COMPONENT_BUDGET)
    ap.add_argument("--assemble", metavar="SVG_OUT",
                    help="pass 4: composite components into the final panel SVG")
    ap.add_argument("--panel-dir", metavar="DIR",
                    help="run all passes into DIR as script.json, "
                         "wireframe.svg, components/, panel.svg, panel.png")
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

    script = script_for(plan)
    wf = wireframe_svg(plan, script)
    comp_dir = args.components
    panel = args.panel_dir
    if panel:
        os.makedirs(os.path.join(panel, "components"), exist_ok=True)
        comp_dir = os.path.join(panel, "components")
        args.script = os.path.join(panel, "script.json")
        args.wireframe = os.path.join(panel, "wireframe.svg")
        args.assemble = os.path.join(panel, "panel.svg")
        png_out = os.path.join(panel, "panel.png")
    if args.script:
        with open(args.script, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(script, indent=2, ensure_ascii=True) + "\n")
        print("manga-draft: script -> %s" % args.script, file=sys.stderr)
    if args.wireframe:
        with open(args.wireframe, "w", encoding="utf-8") as fh:
            fh.write(wf + "\n")
        print("manga-draft: wireframe -> %s" % args.wireframe, file=sys.stderr)
    comps = {}
    if comp_dir:
        os.makedirs(comp_dir, exist_ok=True)
        prompt_path = os.path.join(comp_dir, "prompts.json")
        prompts = component_prompts(plan, script)
        with open(prompt_path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(prompts, indent=2, ensure_ascii=True) + "\n")
        print("manga-draft: %d component prompts -> %s"
              % (len(prompts), prompt_path), file=sys.stderr)
        if args.image:
            for p in prompts:
                out_png = os.path.join(
                    comp_dir, "%s.png" % p["region"].replace(":", "-"))
                before = set(os.listdir(comp_dir))
                rc = os.system(  # ponytail: bounded shell-out per region
                    "%s --style manga-panel --subject %s --out-dir %s "
                    "--timeout 180"
                    % (os.path.join(ROOT, "jobs", "imagegen-submit.sh"),
                       json.dumps(p["prompt"]), json.dumps(comp_dir))
                    # imagegen names files <style>-<ts>.png; keep the
                    # region name as the contract for assembly.
                )
                for fn in sorted(set(os.listdir(comp_dir)) - before):
                    if fn.endswith(".png"):
                        os.replace(os.path.join(comp_dir, fn), out_png)
                # imagegen-submit exits 0 on a leg SKIP too (VRAM/load
                # gate); only a file on disk counts as a render.
                if rc == 0 and os.path.isfile(out_png):
                    comps[p["region"]] = out_png
            if not comps:
                print("manga-draft: component renders skipped (leg down) "
                      "-- placeholder plates stay", file=sys.stderr)
    if args.assemble:
        final = assemble_svg(plan, script, wf, comps)
        if final is None:
            print("manga-draft: assembly skeleton missing -- fail-closed",
                  file=sys.stderr)
            return 1
        with open(args.assemble, "w", encoding="utf-8") as fh:
            fh.write(final)
        print("manga-draft: assembled %s" % args.assemble, file=sys.stderr)
        if panel:
            os.system("rsvg-convert -o %s %s 2>/dev/null || true"
                      % (png_out, args.assemble))  # ponytail: best-effort raster
            # publish the legacy pair the standing review + dispatch
            # read (docs/media/manga/<name>-draft.json/.svg/.png):
            # stages are the work, the pair is the publication.
            stage_png = png_out if os.path.isfile(png_out) else None
            pair = os.path.join(os.path.dirname(panel.rstrip("/")),
                                os.path.basename(panel.rstrip("/"))
                                + "-draft")
            with open(pair + ".json", "w", encoding="utf-8") as fh:
                fh.write(json.dumps(plan, indent=2, ensure_ascii=True) + "\n")
            with open(pair + ".svg", "w", encoding="utf-8") as fh:
                fh.write(final)
            if stage_png:
                import shutil
                shutil.copyfile(png_out, pair + ".png")
            print("manga-draft: published pair %s.{json,svg%s}"
                  % (pair, ",.png" if stage_png else ""), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
