#!/usr/bin/env python3
"""manga-manifest -- read-only inventory of the operator's manga collection.

Scans the collection root (default ~/Documents/manga) and emits a JSON
manifest: per top-level title, format counts (zip/cbz/rar), approx page
counts (archive member counts on a SAMPLE of archives -- no extraction),
and style-reference flags for the operators named study artists
(Tezuka, Nihei, Matsumoto, Hayashida Q incl. Dorohedoro).

Provenance law (docs/design/manga-style-research.md): listing and member
counts only. Never extracts, never reads pixel data, never touches the
network. Study outputs are metrics + descriptive language, never pages.

usage: manga-manifest.py [--root DIR] [--out FILE] [--sample N]
"""
import argparse
import json
import os
import re
import subprocess
import sys
import zipfile

ARCHIVE_EXTS = {".zip": "zip", ".cbz": "cbz", ".rar": "rar", ".cbr": "cbr"}

# Operator-named style references (manga-style-research.md study lines).
# Flagged by case-insensitive keyword match on the title directory.
STYLE_REFS = [
    ("tezuka", ["tezuka"]),
    ("nihei", ["nihei"]),
    ("matsumoto", ["matsumoto"]),
    ("hayashida", ["hayashida", "dai dark", "dorohedoro"]),
]


def _member_count(path):
    """Approximate page count = archive member count. zip via stdlib,
    rar via `7z l` line count. Failure returns None (counts stay honest)."""
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext in (".zip", ".cbz"):
            with zipfile.ZipFile(path) as z:
                return sum(1 for n in z.namelist()
                           if n.lower().rsplit(".", 1)[-1] in
                           ("jpg", "jpeg", "png", "gif", "webp", "bmp"))
        out = subprocess.run(["7z", "l", "-ba", path], capture_output=True,
                             text=True, timeout=60)
        imgs = 0
        for line in out.stdout.splitlines():
            parts = line.split()
            if len(parts) > 2 and parts[-1].lower().rsplit(".", 1)[-1] in (
                    "jpg", "jpeg", "png", "gif", "webp", "bmp"):
                imgs += 1
        return imgs
    except Exception:
        return None


def scan(root, sample=3):
    titles = []
    for entry in sorted(os.listdir(root)):
        tdir = os.path.join(root, entry)
        if not os.path.isdir(tdir):
            continue
        archs = {}
        for dirpath, _dirnames, filenames in os.walk(tdir):
            for fn in filenames:
                ext = os.path.splitext(fn)[1].lower()
                if ext in ARCHIVE_EXTS:
                    archs[ext] = archs.get(ext, 0) + 1
        pages = None
        sampled = []
        if archs:
            # Page-count sample: first N archives PER EXTENSION (deterministic
            # via walk), so mixed-format titles extrapolate honestly.
            for dirpath, _dirnames, filenames in os.walk(tdir):
                for fn in sorted(filenames):
                    ext = os.path.splitext(fn)[1].lower()
                    ext_n = sum(1 for s in sampled
                                if os.path.splitext(s["archive"])[1].lower() == ext)
                    if ext in ARCHIVE_EXTS and ext_n < sample:
                        n = _member_count(os.path.join(dirpath, fn))
                        if n is not None:
                            sampled.append({"archive": fn, "image_members": n})
            counts = [s["image_members"] for s in sampled]
            if counts:
                # Total volumes estimated: sum(per-ext avg * per-ext count)
                per_ext = {}
                for s in sampled:
                    ext = os.path.splitext(s["archive"])[1].lower()
                    per_ext.setdefault(ext, []).append(s["image_members"])
                pages = sum(sum(v) // len(v) * archs.get(k, 0)
                            for k, v in per_ext.items())
        low = entry.lower()
        refs = [name for name, keys in STYLE_REFS
                if any(k in low for k in keys)]
        titles.append({
            "title": entry,
            "archives": archs,
            "approx_pages": pages,
            "page_count_sample": sampled,
            "style_reference": refs,
        })
    return {"root": root, "titles": titles,
            "style_reference_names": ["Tezuka", "Nihei", "Matsumoto",
                                      "Hayashida Q (Dai Dark, Dorohedoro)"]}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.expanduser("~/Documents/manga"))
    ap.add_argument("--out")
    ap.add_argument("--sample", type=int, default=3)
    args = ap.parse_args(argv)
    if not os.path.isdir(args.root):
        print("missing collection root: %s" % args.root, file=sys.stderr)
        return 1
    data = scan(args.root, args.sample)
    blob = json.dumps(data, indent=1, ensure_ascii=True)
    if args.out:
        with open(args.out, "w") as fh:
            fh.write(blob + "\n")
    else:
        print(blob)
    return 0


if __name__ == "__main__":
    sys.exit(main())