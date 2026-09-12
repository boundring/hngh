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
import math
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
# 2026-09-12 collection study (docs/research/2026-09-12-manga-collection-
# study.md): masters run 0.55-0.96 white ground on story pages and the
# sparse-ink economy (ink 0.08-0.20, white 0.66-0.71) out-says dense ink,
# so white ground + negative space now LEAD the descriptor order (they
# were buried mid-string and the output under-used them).
STYLE_CORE = ("monochrome ink illustration, clean white ground, "
              "vast negative space, at least half the frame left empty, "
              "bold confident ink linework, high contrast black and "
              "white, screentone shading, dense cross-hatching on "
              "shadow and towering dark structures, muted desaturated "
              "accents, moss and bone motifs, cathedral-scale "
              "brutalist machine architecture, no text in image")

# Tone sequencing (2026-09-12 collection study, bank deltas 3+4): the
# wit is the tonal CONTRAST -- grim setup pages run the dense mid-gray
# register (0.4-0.6 tone coverage in the measured grim sample), while
# the reaction/gag pages go flat white; the adjacent tone delta IS the
# timing. Per-beat targets ride the script, the wireframe (data-tone),
# and the component prompts.
TONE_GRIM = ("page-wide mid-gray screentone texture, dense gray wash, "
             "low white ground")
TONE_FLAT = "flat white, clean white ground, vast negative space"

# Density band (2026-09-12 collection study, bank delta 1): masters run
# 4.6 panels/page average (up to 8-11 on calm pages); the old 1-3
# default under-ran. Story beats expand to 3-5 panels per page; splash
# beats stay 1 panel (density is a RHYTHM choice, vary it).
DENSITY_MIN, DENSITY_MAX = 3, 5

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

# Recognition register (operator critique 2, item 4): the REACTION beat's
# line -- the moment the beat lands and the character knows it. Distinct
# pool from the punch REACTIONS so the three beats read as an arc
# (flat -> recognition -> punch), not three draws from one pool.
RECOGNITIONS = {
    "bureaucrat": [
        "Wait. That stamp is not ours.",
        "There it is. Paragraph nine.",
        "The drawer is empty. The form is gone.",
    ],
    "engineer": [
        "The gantry just moved on its own.",
        "That is not the bolt I tightened.",
        "The diagram was right. That is worse.",
    ],
    "nightwatch": [
        "Something moved at the end of the hall.",
        "The candle just went out. Both of them.",
        "The log is writing itself. Look.",
    ],
}

# Strip geometry (operator critique 2, items 3/5; density band updated
# 2026-09-12 per the collection study): the wireframe models a 1-5
# panel grid. 3 beats -> horizontal strip (setup | reaction | gag),
# 2 beats -> vertical stack, 1 beat -> single panel, 4 -> 2x2 grid,
# 5 -> 3-over-2 grid. GUTTER px between frames; panels are (x, y, w, h)
# in the same 1024x820 canvas.
GUTTER = 14


def panel_grid(n):
    """The beat-count-keyed layout contract: orientation + panel rects
    for an n-beat strip, sharing the 1024x820 canvas and the 668px
    narrative band below."""
    W, H, ART_H = 1024, 820, 650
    if n <= 1:
        return {"orientation": "single", "panels": [(14, 14, 996, ART_H)]}
    if n == 2:
        ph = (ART_H - GUTTER) // 2
        return {"orientation": "vertical", "panels":
                [(14, 14, 996, ph), (14, 14 + ph + GUTTER, 996, ph)]}
    if n == 4:
        pw = (996 - GUTTER) // 2
        ph = (ART_H - GUTTER) // 2
        return {"orientation": "grid-2x2", "panels":
                [(14, 14, pw, ph), (14 + pw + GUTTER, 14, pw, ph),
                 (14, 14 + ph + GUTTER, pw, ph),
                 (14 + pw + GUTTER, 14 + ph + GUTTER, pw, ph)]}
    if n >= 5:
        pw3 = (996 - 2 * GUTTER) // 3
        pw2 = (996 - GUTTER) // 2
        ph = (ART_H - GUTTER) // 2
        return {"orientation": "grid-3-2", "panels":
                [(14 + i * (pw3 + GUTTER), 14, pw3, ph) for i in range(3)]
                + [(14 + j * (pw2 + GUTTER), 14 + ph + GUTTER, pw2, ph)
                   for j in range(2)]}
    pw = (996 - 2 * GUTTER) // 3
    return {"orientation": "horizontal", "panels":
            [(14 + i * (pw + GUTTER), 14, pw, ART_H) for i in range(3)]}


def beat_panels(script):
    """The density rule (2026-09-12 collection study, bank delta 1):
    expand script beats to panels for the 3-5 band. Each beat defaults
    to 1 panel; a content-heavy beat (its visual note implies two
    beats' worth of action, marked "panels": 2 by the script pass)
    splits across 2; a splash beat (splash flag) always stays 1. A
    lone beat is a splash by definition. Capped at the band's top."""
    beats = script["beats"]
    if len(beats) < 2:
        return [(0, 0)]
    panels = []
    for bi, b in enumerate(beats):
        for sub in range(1 if b.get("splash") else b.get("panels", 1)):
            panels.append((bi, sub))
    return panels[:DENSITY_MAX]


def sfx_anchor(panel, focal, seed):
    """SFX position: orbital offset around the beat's focal-action
    point, quadrant-cycled by seed (45+90*deg) with golden-jitter and a
    seed-varied radius, clamped inside the panel. The focal point
    differs per beat, so the SFX lands where the action is; the quadrant
    cycle guarantees the seed spread covers distinct quadrants."""
    px, py, pw, ph = panel
    ang = 45 + (seed % 4) * 90 + ((seed * 13) % 30) - 15
    rad = (0.22 + (seed % 3) * 0.08) * min(pw, ph)
    x = focal[0] + rad * math.cos(math.radians(ang))
    y = focal[1] + rad * math.sin(math.radians(ang))
    x = max(px + 20, min(px + pw - 20, x))
    y = max(py + 40, min(py + ph - 20, y))
    return round(x, 1), round(y, 1)


WF_DEFS = """<defs>
  <pattern id="screentone" width="8" height="8" patternUnits="userSpaceOnUse">
    <circle cx="4" cy="4" r="1.3" fill="#141414"/></pattern>
  <pattern id="screentone-dark" width="6" height="6" patternUnits="userSpaceOnUse">
    <circle cx="3" cy="3" r="2.1" fill="#141414"/></pattern>
  <pattern id="hatch" width="7" height="7" patternUnits="userSpaceOnUse"
    patternTransform="rotate(45)">
    <line x1="0" y1="0" x2="0" y2="7" stroke="#141414" stroke-width="1.1"/>
  </pattern>
  <filter id="ink" x="-4%" y="-4%" width="108%" height="108%">
    <feTurbulence type="fractalNoise" baseFrequency="0.11" numOctaves="2"
      seed="7" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="2.6"/>
  </filter>
  <marker id="focalhead" markerWidth="8" markerHeight="8" refX="6" refY="3"
    orient="auto"><path d="M0 0 L7 3 L0 6 Z" fill="#141414"/></marker>
</defs>"""


def _tail(bx, by, tx, ty):
    """Two-segment quadratic bezier tail from the bubble edge to the
    actor anchor (operator critique 2, item 1): no bare polygons, and
    the ink-wash filter gives it the same hand-drawn wobble."""
    mx = (bx + tx) / 2.0 + 0.18 * (ty - by)
    my = (by + ty) / 2.0
    return ('<path class="tail" d="M%d %d Q%.1f %.1f %.1f %.1f '
            'Q%.1f %.1f %d %d" fill="none" stroke="#141414" '
            'stroke-width="4" filter="url(#ink)"/>'
            % (bx, by, mx, my, mx, my, mx, my, tx, ty))


def _panel_scene(px, py, pw, ph, seed, i):
    """Deepened hand-drawn placeholder scene per panel (operator
    critique 2, item 6): screentone sky, towers with a SECOND screentone
    density, ground line, ground shadow under the actor slot, varied
    power-line curves, ONE accent (moss patch XOR mini-seal). All
    geometry is panel-relative so any grid cell composes."""
    gy = py + ph - 36
    parts = ['<rect x="%d" y="%d" width="%d" height="%d" fill="#ffffff"/>'
             % (px, py, pw, ph),
             '<rect x="%d" y="%d" width="%d" height="%d" '
             'fill="url(#screentone)" opacity="0.45"/>'
             % (px, py, pw, ph * 0.42)]
    for tx, tw, th in ((px + 12, pw * 0.16, ph * 0.5),
                       (px + pw * 0.7, pw * 0.2, ph * 0.36)):
        parts += [
            '<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" '
            'fill="#141414"/>' % (tx, gy - th, tw, th),
            '<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" '
            'fill="url(#hatch)" opacity="0.3"/>' % (tx, gy - th, tw, th),
            '<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" '
            'fill="url(#screentone-dark)" opacity="0.45"/>'
            % (tx, gy - th, tw, th)]
    for k in range(2):
        dy = py + ph * (0.3 + k * 0.09) + (seed % 7)
        parts.append('<path d="M%.0f %.0f Q %.0f %.0f %.0f %.0f" '
                     'fill="none" stroke="#141414" stroke-width="1.4" '
                     'opacity="0.6"/>' % (px, dy, px + pw / 2.0,
                                          dy + 12 + (seed + k) % 9,
                                          px + pw, dy - 4))
    parts += ['<path d="M%.0f %.0f L%.0f %.0f" stroke="#141414" '
              'stroke-width="2.4"/>' % (px, gy, px + pw, gy),
              '<ellipse cx="%.0f" cy="%.0f" rx="%.0f" ry="5" '
              'fill="#141414" opacity="0.3"/>'
              % (px + pw / 2.0, gy, pw * 0.16)]
    if (seed + i) % 2 == 0:
        parts.append('<circle cx="%.0f" cy="%.0f" r="9" '
                     'fill="url(#screentone-dark)"/>'
                     % (px + pw * 0.14, gy + 8))
    else:
        parts.append('<rect x="%.0f" y="%.0f" width="26" height="12" '
                     'fill="none" stroke="#a3282d" stroke-width="2" '
                     'opacity="0.8"/>' % (px + pw * 0.1, py + ph * 0.5))
    return "".join(parts)


def _panel_text_layer(plan, b, rect, seed, i, beat_index=None):
    """Per-panel text layer: actor slot (pose library), focal-action
    mark, setup caption OR ellipse bubble with a curved bezier tail to
    the actor's head, the beat's register line, and -- on the reaction
    beat -- the SFX anchored at the beat's focal point (seed-varied
    quadrant, critique 2 item 2)."""
    px, py, pw, ph = rect
    gy = py + ph - 40
    h = ph * (0.5 if b["pose"] != "small-in-frame" else 0.26)
    ax = px + pw / 2.0 + (seed % 21) - 10
    head = (ax, gy - h * 0.85)  # matches the wireframe's stick head
    focal = (px + pw * (0.35 + ((seed + i) % 5) * 0.08),
             py + ph * 0.42)
    parts = ['<g data-beat="%d" data-kind="%s" data-pose="%s">'
             % (i if beat_index is None else beat_index,
                b["kind"], b["pose"]),
             '<path data-focal="%s" d="M%.0f %.0f L%.0f %.0f" '
             'stroke="#141414" stroke-width="3" fill="none" '
             'marker-end="url(#focalhead)"/>'
             % (b["kind"], focal[0] - 44, focal[1] + 30,
                focal[0], focal[1])]
    if b["kind"] == "setup":
        bx, bw = px + 8, pw - 16
        parts.append('<rect x="%d" y="%d" width="%d" height="56" '
                     'rx="3" fill="#ffffff" stroke="#141414" '
                     'stroke-width="3"/>' % (bx, py + 10, bw))
        parts.append('<text font-family="Iosevka, monospace" '
                     'font-size="14" fill="#141414">%s</text>'
                     % "".join('<tspan x="%d" y="%d">%s</tspan>'
                               % (bx + 10, py + 32 + n * 18, escape(l))
                               for n, l in enumerate(_wrap(b["line"],
                                                           34))))
    else:
        bcx, bcy = px + pw * 0.6, py + ph * 0.14
        rx, ry = pw * 0.36, ph * 0.075
        parts.append('<ellipse cx="%.0f" cy="%.0f" rx="%.0f" ry="%.0f" '
                     'fill="#ffffff" stroke="#141414" stroke-width="3"/>'
                     % (bcx, bcy, rx, ry))
        parts.append(_tail(bcx - rx * 0.3, bcy + ry, head[0], head[1]))
        parts.append('<text text-anchor="middle" font-size="14" '
                     'fill="#141414">%s</text>'
                     % "".join('<tspan x="%.0f" y="%.0f">%s</tspan>'
                               % (bcx, bcy - 8 + n * 18, escape(l))
                               for n, l in enumerate(_wrap(b["line"],
                                                           24))))
        if b["kind"] == "reaction":
            sx, sy = sfx_anchor(rect, focal, seed + i)
            # keep the word on-panel: clamp for ~5 letters + rotation
            sx = max(px + 60, min(px + pw - 110, sx))
            sy = max(py + 70, min(py + ph - 40, sy))
            srot = -16 + (seed % 9)
            parts.append('<text data-sfx="%s" x="%.1f" y="%.1f" '
                         'font-family="Averia Gruesa Libre, cursive" '
                         'font-size="30" font-weight="bold" '
                         'fill="#141414" stroke="#ffffff" '
                         'stroke-width="6" paint-order="stroke" '
                         'transform="rotate(%d %.1f %.1f)">%s</text>'
                         % (plan["sfx"], sx, sy, srot, sx, sy,
                            escape(plan["sfx"])))
    parts.append('</g>')
    return "".join(parts)


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
    Dialogue comes from PER-BEAT-TYPE registers (operator critique 2,
    item 4): setup = flat narration, reaction = recognition, gag = the
    punch -- three distinct lines from three distinct pools, an arc."""
    seed = plan["seed"]
    cameo = plan["cameo"]
    cast = load_cast().get(cameo, {})
    narration = _pick(NARRATIONS, seed // 17)
    recognition = _pick(RECOGNITIONS[cameo], seed // 23)
    return {
        "narration": narration,
        "beats": [
            {"kind": "setup", "cast": [cameo], "pose": "standing-deadpan",
             "register": "narration", "line": narration,
             # grim/deadpan setup: mid-tone texture target; the visual
             # note carries two eye-hits (caption, then the structure),
             # so the density rule splits it across 2 panels.
             "splash": False, "panels": 2, "tone": TONE_GRIM,
             "camera": "wide, figure small against the machinery",
             "eye": "narration caption first, then the tilted structure",
             "visual": plan["scene"] + ". " + narration},
            {"kind": "reaction", "cast": [cameo], "pose": "reacting",
             "register": "recognition", "line": recognition,
             "splash": False, "panels": 1, "tone": TONE_FLAT,
             "camera": "medium, face in frame, star-highlight eyes",
             "eye": "the face, then the focal action behind it",
             "visual": "close on %s reacting; %s" % (cameo, plan["sfx"])},
            {"kind": "gag", "cast": [cameo], "pose": "pointing",
             "register": "punch", "line": plan["dialogue"],
             "splash": False, "panels": 1, "tone": TONE_FLAT,
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
    r = h * 0.07
    hip = y - h * 0.45
    neck = y - h * 0.72
    lean = {"reacting": -h * 0.08, "crouched": h * 0.22,
            "walking-away": h * 0.05}.get(pose, 0)
    j = ((seed % 7) - 3)  # deterministic limb jitter
    if pose == "reacting":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (x - r, neck + 4, x - h * 0.3, neck - h * 0.2,
                   x + r, neck + 4, x + h * 0.3, neck - h * 0.2))
    elif pose == "pointing":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (x - r, neck + 4, x - h * 0.26, hip + 8,
                   x + r, neck + 4, x + h * 0.34, neck - h * 0.06))
    elif pose == "crouched":
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (x - r, neck + 4, x - h * 0.3, neck + h * 0.18))
    else:
        arms = ('<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (x - r, neck + 4, x - h * 0.3, hip + 8,
                   x + r, neck + 4, x + h * 0.3, hip + 8))
    # absolute coords throughout: translate() + absolute y double-offset
    # the figure off-canvas (found on first strip rasterization)
    return ('<g stroke="#141414" stroke-width="4">'
            '<circle cx="%.1f" cy="%.1f" r="%.1f"/>'
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>%s'
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%d"/>'
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%d"/></g>'
            % (x + lean * 0.4, neck - r, r, x, neck, x + lean, hip,
               arms, x, hip, x - h * 0.16 + j, y, x, hip,
               x + h * 0.16 + j, y))


def wireframe_svg(plan, script, width=1024, height=820):
    """Pass 2 -- the procedural wireframe IS the beat visualization
    (operator critique 2, items 3/5): one panel per beat in a
    beat-count-keyed grid (3 = horizontal strip, 2 = vertical stack,
    1 = single panel), gutters between frames. Per panel: pose-library
    stick figure, caption (setup) or ellipse bubble (reaction/gag) with
    a curved bezier tail to the actor, focal-action mark, and the SFX
    anchored where the reaction beat's action is. A shared narrative
    band + attribution footer close the strip. data-panel / data-beat /
    data-panelimg / data-sfx attributes make the contract inspectable
    and give assemble_svg its injection points."""
    seed = plan["seed"]
    beats = script["beats"]
    expansion = beat_panels(script)
    grid = panel_grid(len(expansion))
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" '
             'height="%d" viewBox="0 0 %d %d">' % (width, height,
                                                   width, height),
             WF_DEFS,
             '<rect width="%d" height="%d" fill="#f7f2e7"/>' % (width,
                                                                height)]
    for i, (bi, sub) in enumerate(expansion):
        b = beats[bi]
        rect = grid["panels"][i]
        # wide establishing shot first when a beat splits across panels
        pose = ("small-in-frame"
                if sub and b["pose"] != "small-in-frame" else b["pose"])
        parts.append('<g data-panel="%d" data-orientation="%s" '
                     'data-tone="%s">'
                     % (i, grid["orientation"], b["tone"]))
        gy = rect[1] + rect[3] - 40
        h = rect[3] * (0.5 if pose != "small-in-frame" else 0.26)
        ax = rect[0] + rect[2] / 2.0 + (seed % 21) - 10
        parts.append('<g data-panelimg="%d">%s%s</g>'
                     % (i, _panel_scene(rect[0], rect[1], rect[2],
                                        rect[3], seed, i),
                        _stick(ax, gy, h, pose, seed + i)))
        if not sub:  # the beat's text layer rides its first panel
            parts.append(_panel_text_layer(plan, b, rect, seed, i,
                                           beat_index=bi))
        # frame drawn over the scene so art never crosses the border
        parts.append('<rect x="%d" y="%d" width="%d" height="%d" '
                     'fill="none" stroke="#141414" stroke-width="5"/>'
                     % rect)
        parts.append('</g>')
    # shared narrative band + attribution footer (once per strip)
    narr = "".join('<tspan x="28" y="%d">%s</tspan>'
                   % (700 + n * 22, escape(l))
                   for n, l in enumerate(_wrap(plan["narrative"], 110)))
    parts += ['<rect x="14" y="672" width="%d" height="110" fill="#ffffff" '
              'stroke="#141414" stroke-width="4"/>' % (width - 28),
              '<text font-family="Iosevka, monospace" font-size="17" '
              'fill="#141414">%s</text>'
              % narr,
              '<text x="14" y="%d" font-family="Iosevka, monospace" '
              'font-size="12" fill="#141414">%s</text>'
              % (height - 14, escape(plan["attribution"])),
              "</svg>"]
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
    # per-panel tone targets inherited into the prompts (2026-09-12
    # collection study): the grim setup panel carries the mid-gray
    # texture register, the gag panel the flat-white ground.
    tones = {b["kind"]: b.get("tone", TONE_FLAT)
             for b in script["beats"]}
    prompts = [
        {"region": "environment", "size": "768x512", "seed": seed,
         "prompt": "%s environment plate, empty of figures, %s, %s"
                   % (plan["scene"],
                      tones.get("setup", TONE_GRIM), STYLE_CORE)},
        {"region": "actor:%s" % script["beats"][0]["cast"][0],
         "size": "512x768", "seed": actor_seed,
         "prompt": "single character, full figure, standing on a plain "
                   "white ground, %s, %s, %s"
                   % (actor_desc, tones.get("gag", TONE_FLAT), STYLE_CORE)},
    ]
    return prompts[:COMPONENT_BUDGET]


def assemble_svg(plan, script, wireframe, components=None):
    """Pass 4 -- composite components into the STRIP wireframe (operator
    critique 2, item 5): each panel's placeholder art group
    (data-panelimg) swaps for the real pieces -- environment plate
    under, actor piece over -- while the text layers (bubbles, tails,
    captions, SFX) always stay on top. components maps region -> image
    path; a missing piece keeps that panel's hand-drawn placeholder
    (never empty)."""
    comps = components or {}
    if 'data-panelimg="0"' not in (wireframe or ""):
        wireframe = wireframe_svg(plan, script)
    rects = panel_grid(len(script["beats"]))["panels"]
    out = wireframe
    for i, beat in enumerate(script["beats"]):
        px, py, pw, ph = rects[i]
        layers = ""
        if comps.get("environment"):
            layers += ('<image x="%d" y="%d" width="%d" height="%d" '
                       'href="%s" preserveAspectRatio="xMidYMid slice"/>'
                       % (px, py, pw, ph, comps["environment"]))
        key = "actor:%s" % beat["cast"][0]
        if comps.get(key):
            layers += ('<image x="%d" y="%d" width="%d" height="%d" '
                       'href="%s" preserveAspectRatio="xMidYMax meet"/>'
                       % (px + pw * 0.3, py + ph * 0.35, pw * 0.4,
                          ph * 0.55, comps[key]))
        if layers:
            out = re.sub(r'<g data-panelimg="%d">.*?</g>' % i,
                         '<g data-panelimg="%d">%s</g>' % (i, layers),
                         out, count=1, flags=re.S)
    return out


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
