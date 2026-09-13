#!/usr/bin/env python3
"""manga-collage -- P0 decoration pipeline: collage derivatives from the
operator's own collection (docs/records/2026-09-12-manga-collection-
policy.md, clause c).

The "edited enough" pipeline: archive members are extracted to a TEMP
dir (the same read-only + temp-extract + delete pattern as the
collection study), selected pieces are TRANSFORMED -- cropped,
rescaled, recolored to the display register palette (ink black / tone
gray / white ground), and recomposed under an SVG overlay (screentone
dots, border, vignette) -- and the transformed result is emitted as a
decoration asset. What is committed is the derivative, never the
source: provenance cites "collection study", never a filename.

usage: manga-collage.py [--manifest FILE] [--out DIR] [--seed N]
       -> writes <out>/collage-<slug>.png + collage-<slug>.json
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import zipfile

MANIFEST = os.path.expanduser(
    "~/Projects/etc/hngh/automation/state/manga-manifest.json")
OUT_DIR = os.path.expanduser(
    "~/Projects/etc/hngh/docs/media/collage")

# Display-register palette (docs/design/display-register-spec.md s4):
# near-black ink, mid-gray tone, near-white ground. Recolor pushes the
# page histogram onto these three bands.
INK, TONE, WHITE = "#111111", "#8a8a8a", "#f4f4f2"
CANVAS_W, CANVAS_H = 1024, 820   # same frame as the strip geometry


def select_archives(manifest, n=3):
    """Deterministic piece selection by MANIFEST metadata only:
    style-reference titles first, then any title with zip/cbz archives
    (stdlib-extractable). Returns [(title, archive_path)]."""
    titles = manifest.get("titles", [])
    refs = [t for t in titles if t.get("style_reference")]
    rest = [t for t in titles if not t.get("style_reference")]
    picks = []
    for t in sorted(refs, key=lambda t: t["title"]) + \
            sorted(rest, key=lambda t: t["title"]):
        found = None
        for sample in t.get("page_count_sample", []):
            name = sample["archive"]
            if name.lower().endswith((".zip", ".cbz")):
                for dirpath, _, files in os.walk(
                        os.path.join(manifest["root"], t["title"])):
                    if name in files:
                        found = os.path.join(dirpath, name)
                        break
            if found:
                break
        if len(picks) >= n:
            break
        if found:
            picks.append((t["title"], found))
    return picks


def image_members(archive):
    """Page-image member names inside a zip/cbz (no extraction)."""
    with zipfile.ZipFile(archive) as zf:
        return [m for m in zf.namelist() if m.lower().endswith(
            (".png", ".jpg", ".jpeg"))]


def crop_rects(w, h):
    """Deterministic crop geometry over one page: three character
    crops (upper-center, mid-left, mid-right bands -- where figures
    sit in the register's composition) + one environment (the full
    frame, downscaled). Returns [(x, y, cw, ch, kind)]."""
    cw, ch = w // 2, h // 2
    return [
        (w // 4, 0, cw, h // 3, "character"),
        (0, h // 3, cw, ch, "character"),
        (w - cw, h // 3, cw, ch, "character"),
        (0, 0, w, h, "environment"),
    ]


def overlay_svg(w, h, seed):
    """SVG overlay recomposition: screentone dot pattern, corner
    vignette, 2px frame. No text (register law). seed varies dot
    scale deterministically."""
    dot = 3 + seed % 3
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'
        '<defs><pattern id="tone" width="%d" height="%d" '
        'patternUnits="userSpaceOnUse">'
        '<circle cx="%d" cy="%d" r="%d" fill="%s" fill-opacity="0.35"/>'
        "</pattern></defs>"
        '<rect width="%d" height="%d" fill="url(#tone)"/>'
        '<rect x="3" y="3" width="%d" height="%d" fill="none" '
        'stroke="%s" stroke-width="6"/>'
        '<rect width="%d" height="%d" fill="none" stroke="%s" '
        'stroke-width="14" stroke-opacity="0.25"/></svg>'
    ) % (w, h, dot * 4, dot * 4, dot * 2, dot * 2, dot, INK,
         w, h, w - 6, h - 6, TONE, w, h, INK)


def transform(src, dst, rect, seed, target_w=480):
    """The transformation (policy clause c): crop -> rescale ->
    recolor to the register palette (3-band posterize after a level
    push) -> paint pass (destroys any original text/SFX legibility)
    -> mirror odd pieces (recomposition) -> composite the SVG
    overlay. Never verbatim: the output cannot byte-equal the source
    and carries no readable original text."""
    x, y, cw, ch, _ = rect
    tw = target_w
    th = max(1, round(ch * tw / cw))
    tmp = dst + ".svg.png"
    with open(dst + ".overlay.svg", "w") as fh:
        fh.write(overlay_svg(tw, th, seed))
    subprocess.run(["rsvg-convert", "-w", str(tw), "-h", str(th),
                    "-o", tmp, dst + ".overlay.svg"],
                   check=True, timeout=60)
    subprocess.run(["magick", src, "-crop", "%dx%d+%d+%d" % (cw, ch, x, y),
                    "-resize", "%dx%d!" % (tw, th), "-colorspace", "Gray",
                    # blur/paint scale with piece size: a 1024-wide
                    # background needs a heavier pass than a 300px crop
                    # to keep original text unreadable
                    "-blur", "0x%.2f" % (0.6 * tw / 300.0),
                    "-paint", "%d" % max(3, round(3 * tw / 300.0)),
                    * (["-flop"] if seed % 2 else []),
                    "-level", "5%,95%", "-posterize", "3",
                    tmp, "-compose", "over", "-composite",
                    "png:%s" % dst], check=True, timeout=120)
    os.unlink(tmp)
    os.unlink(dst + ".overlay.svg")
    return tw, th


def homage_frame_svg(w, h):
    """Light overlay recomposition for homage output: a thin ink frame
    only (no screentone, no text -- register law)."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'
        '<rect x="2" y="2" width="%d" height="%d" fill="none" '
        'stroke="%s" stroke-width="4"/></svg>'
    ) % (w, h, w - 4, h - 4, INK)


def transform_homage(src, dst, rect, seed, target_w=320):
    """The HOMAGE transformation (policy clauses c/g): crop -> scale ->
    tone-match recolor to the register palette (grayscale + level; no
    blur/paint pass -- light touch) -> opacity blend over the register
    ground -> thin frame overlay. Recolor + overlay + recomposition by
    construction: never a raw crop, but the source lineart stays
    legible (that is the homage)."""
    x, y, cw, ch, _ = rect
    tw = target_w
    th = max(1, round(ch * tw / cw))
    tmp = dst + ".frame.svg.png"
    with open(dst + ".frame.svg", "w") as fh:
        fh.write(homage_frame_svg(tw, th))
    subprocess.run(["rsvg-convert", "-w", str(tw), "-h", str(th),
                    "-o", tmp, dst + ".frame.svg"],
                   check=True, timeout=60)
    subprocess.run(["magick", src,
                    "-crop", "%dx%d+%d+%d" % (cw, ch, x, y),
                    "-resize", "%dx%d!" % (tw, th),
                    "-colorspace", "Gray",
                    "-level", "10%,90%",
                    * (["-flop"] if seed % 2 else []),
                    "-fill", WHITE, "-tint", "22",
                    "(", tmp, ")",
                    "-compose", "over", "-composite", "png:%s" % dst,
                    ], check=True, timeout=120)
    os.unlink(tmp)
    os.unlink(dst + ".frame.svg")
    return tw, th


def extract(archive, member, tmpdir):
    """Temp-extract ONE member (the collection-study pattern); returns
    the temp path. Caller deletes the whole temp dir."""
    with zipfile.ZipFile(archive) as zf:
        return zf.extract(member, tmpdir)


def build_collage(pieces, out):
    """Compose transformed pieces on the canvas: the environment as
    the full background, character crops in a guttered bottom band.
    pieces: [(path, x, y, w, h)]."""
    bg = pieces[0]
    cmd = ["magick", "-size", "%dx%d" % (CANVAS_W, CANVAS_H),
           "xc:%s" % WHITE, bg[0], "-resize", "%dx%d!" % (CANVAS_W, CANVAS_H),
           "-geometry", "+0+0", "-compose", "over", "-composite"]
    for path, x, y, w, h in pieces[1:]:
        cmd += [path, "-geometry", "+%d+%d" % (x, y), "-composite"]
    cmd += ["png:%s" % out]
    subprocess.run(cmd, check=True, timeout=300)


def provenance_json(slug, seed, n_pieces, kind="collage"):
    """Public-facing provenance: cites the study and the policy, never
    a source filename or path (policy clauses c/d)."""
    return {
        "kind": kind,
        "slug": slug,
        "seed": seed,
        "pieces": n_pieces,
        "treatment": ("crop + rescale + 3-band register recolor + "
                      "screentone/border/vignette SVG overlay"
                      if kind == "collage" else
                      "crop + scale + grayscale tone-match recolor + "
                      "opacity blend over register ground + frame "
                      "overlay (homage, policy clauses c/g)"),
        "provenance": "collection study, 2026-09-12 "
                      "(docs/research/2026-09-12-manga-collection-study.md)",
        "policy": "docs/records/2026-09-12-manga-collection-policy.md",
        "source_note": "operator's own collection; read-only temp "
                       "extract, deleted after transformation; no "
                       "filenames retained",
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=MANIFEST)
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--seed", type=int, default=20260912)
    ap.add_argument("--slug", default="sample")
    ap.add_argument("--homogeneous", action="store_true",
                    help="homage mode: light-touch character tiles "
                         "(policy clauses c/g) instead of a heavy "
                         "collage")
    args = ap.parse_args(argv)
    with open(args.manifest) as fh:
        manifest = json.load(fh)
    archives = select_archives(manifest)
    if not archives:
        print("manga-collage: no stdlib-extractable archive in manifest",
              file=sys.stderr)
        return 1
    archive = archives[0][1]
    members = image_members(archive)
    # deterministic page picks: skip covers/credits; page 0 yields the
    # environment + 3 character crops, page 1 adds a 4th character
    picks = members[10:12] if len(members) >= 12 else members[:2]
    os.makedirs(args.out, exist_ok=True)
    stem = os.path.join(args.out, "collage-%s" % args.slug)
    if args.homogeneous:
        stem = os.path.join(args.out, "homage-%s" % args.slug)
    with tempfile.TemporaryDirectory(prefix="manga-collage.") as tmp:
        if args.homogeneous:
            made = []
            for member in picks:
                src = extract(archive, member, tmp)
                ident = subprocess.run(
                    ["magick", "identify", "-format", "%w %h", src],
                    capture_output=True, text=True, check=True, timeout=60)
                w, h = (int(v) for v in ident.stdout.split())
                for rect in [r for r in crop_rects(w, h)
                             if r[4] == "character"]:
                    outp = "%s-%d.png" % (stem, len(made))
                    tw, th = transform_homage(
                        src, outp, rect, args.seed + len(made))
                    made.append((outp, tw, th, rect[4]))
        else:
            made = []   # (path, w, h, kind) in creation order
            for i, member in enumerate(picks):
                src = extract(archive, member, tmp)
                ident = subprocess.run(
                    ["magick", "identify", "-format", "%w %h", src],
                    capture_output=True, text=True, check=True, timeout=60)
                w, h = (int(v) for v in ident.stdout.split())
                rects = crop_rects(w, h) if i == 0 else [crop_rects(w, h)[0]]
                for rect in rects:
                    outp = "%s-%d.png" % (stem, len(made))
                    tw, th = transform(
                        src, outp, rect, args.seed + len(made),
                        1024 if rect[4] == "environment" else 300)
                    made.append((outp, tw, th, rect[4]))
            env = next(p for p in made if p[3] == "environment")
            chars = [p for p in made if p[3] == "character"][:4]
            pieces = [(env[0], 0, 0, CANVAS_W, CANVAS_H)]
            for j, (path, tw, th, _) in enumerate(chars):
                pieces.append((path, 26 + j * 336, CANVAS_H - th - 24, tw, th))
            build_collage(pieces, stem + ".png")
    with open(stem + ".json", "w") as fh:
        json.dump(provenance_json(args.slug, args.seed, len(made),
                                  "homage" if args.homogeneous else "collage"),
                  fh,
                  indent=1)
        fh.write("\n")
    print(stem + ".png" if not args.homogeneous else stem + "-*.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())