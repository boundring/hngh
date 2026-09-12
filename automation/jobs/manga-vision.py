#!/usr/bin/env python3
"""manga-vision -- multimodal narrative comprehension over sampled pages.

Complement to manga-metrics.py (metrics = geometry, vision = narrative).
The local unsloth llama-server runs Qwen3.8-27B with --mmproj: the
/v1/chat/completions endpoint accepts image_url parts (live-verified
2026-09-12 with a synthetic fixture). kimi K3 and ocgo glm-5.3-flash
are text-only; the deck leg carries no mmproj -- the unsloth local leg
is the only vision path on this machine today.

Provenance law (docs/research/2026-09-12-manga-collection-study.md):
pages are extracted to a TEMP dir, described, and deleted. What
survives is structured lessons (docs/research/), never pixels.
Calls are bounded: MAX_SPREADS spreads per run, max 2 images each.

usage: manga-vision.py --archive ARCHIVE [--title NAME] [--lessons PATH]
       manga-vision.py --selftest            (fixture images, stubbed vision)
"""
import argparse
import base64
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

VISION_URL = os.environ.get(
    "VISION_URL",
    "http://127.0.0.1:8888/v1/chat/completions")  # studio orchestrator
VISION_MODEL = os.environ.get("VISION_MODEL", "unsloth/Qwen3.8-27B-GGUF")
TOKEN_FILE = os.environ.get(
    "TOKEN_FILE", os.path.expanduser("~/.hngh-automation/unsloth.token"))
MAX_SPREADS = int(os.environ.get("MANGA_VISION_SPREADS", "4"))
# ponytail: 2-page spreads only; facing-page stitching deferred until a
# real spread question needs it.

# Test seam: monkeypatched in tests; prod impl set at the bottom.
VISION_CALL = None  # type: ignore


def _one_call(prompt, image_paths, max_tokens, thinking, timeout):
    parts = [{"type": "text", "text": prompt}]
    for p in image_paths:
        mime = mimetypes.guess_type(p)[0] or "image/png"
        with open(p, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        parts.append({"type": "image_url",
                      "image_url": {"url": "data:%s;base64,%s" % (mime, b64)}})
    body = json.dumps({"model": VISION_MODEL, "max_tokens": max_tokens,
                       "chat_template_kwargs": {"enable_thinking": thinking},
                       "messages": [{"role": "user", "content": parts}]
                       }).encode()
    headers = {"Content-Type": "application/json"}
    try:
        with open(TOKEN_FILE) as f:  # value never logged/echoed
            headers["Authorization"] = "Bearer " + f.read().strip()
    except OSError:
        pass
    req = urllib.request.Request(VISION_URL, body, headers)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.loads(r.read())
    msg = out["choices"][0]["message"]
    text = msg.get("content") or ""
    if not text:
        text = msg.get("reasoning_content") or ""
    return text


def vision_call(prompt, image_paths, timeout=300):
    """One bounded multimodal call -> text, or raise RuntimeError.
    Empty content (reasoning ate the budget) -> one retry with thinking
    off and budget x4, mirroring unsloth_chat's cure in lib/model.sh."""
    text = _one_call(prompt, image_paths, 900, True, timeout)
    if not text:
        text = _one_call(prompt, image_paths, 3600, False, timeout)
    if "{" not in text:
        text = _one_call(prompt, image_paths, 3600, False, timeout)
    if not text:
        raise RuntimeError("empty vision content after retry")
    return text


def _image_members(archive):
    """Sorted page filenames inside a zip/cbz (stdlib) or rar/7z."""
    arc = archive.lower()
    if arc.endswith((".zip", ".cbz")):
        import zipfile
        with zipfile.ZipFile(archive) as z:
            names = [n for n in z.namelist()
                     if n.lower().endswith((".png", ".jpg", ".jpeg",
                                            ".webp", ".bmp", ".gif"))]
        return sorted(names)
    out = subprocess.run(["7z", "-ba", "-slt", "l", archive],
                         capture_output=True, text=True, timeout=120)
    names = []
    for block in out.stdout.split("Path = ")[1:]:
        name = block.splitlines()[0].strip()
        if name.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            names.append(name)
    return sorted(names)


def _extract_pages(archive, members, tmp):
    """Extract selected members into tmp; returns {member: local path}."""
    if archive.lower().endswith((".zip", ".cbz")):
        import zipfile
        got = {}
        with zipfile.ZipFile(archive) as z:
            for m in members:
                z.extract(m, tmp)
                got[m] = os.path.join(tmp, m)
        return got
    got = {}
    for m in members:
        subprocess.run(["7z", "e", archive, "-o" + tmp, m, "-y"],
                       check=True, capture_output=True, timeout=120)
        got[m] = os.path.join(tmp, os.path.basename(m))
    return got


def pick_spreads(names, count=MAX_SPREADS):
    """Chapter-transition sampling: pairs around the start, middle, and
    end of the sequence -- the transitions carry the narrative arc.
    The first 2 members are skipped on long sequences (cover/TOC)."""
    n = len(names)
    if n < 2:
        return []
    lo = 2 if n > 8 else 0
    hi = n - 2
    span = hi - lo
    idx = sorted({lo, lo + 1, lo + span // 4, lo + span // 4 + 1,
                  lo + span // 2, lo + span // 2 + 1,
                  lo + 3 * span // 4, lo + 3 * span // 4 + 1,
                  hi, hi + 1})
    pairs, used = [], set()
    for a, b in zip(idx, idx[1:]):
        if b - a == 1 and a not in used:
            pairs.append((names[a], names[b]))
            used.add(b)
        if len(pairs) >= count:
            break
    return pairs


SPREAD_PROMPT = """You are a silent observer describing how a story is
told in pictures on two consecutive comic pages. NO artist names, NO
titles, NO real people. Answer as compact JSON only:
{"panel_flow": "<how panels guide the eye, e.g. tall establishing panel then rapid strips>",
"reading_order": "<right-to-left / left-to-right / ambiguous>",
"narrative_mode": "<image-only | dialogue-only | mixed>",
"dialogue_elements": "<speech bubbles, captions, SFX, or none>",
"imagery_carries": "<what the pictures alone communicate>",
"page_turn_hook": "<does the second page end on a cliff / reveal / quiet beat>"}"""


def _parse_json_loose(text):
    s = text.find("{")
    if s < 0:
        raise ValueError("no JSON object in vision output")
    depth = 0
    for i in range(s, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return json.loads(text[s:i + 1])
    raise ValueError("unbalanced JSON in vision output")


def distill(spreads):
    """Spread observations -> structured lessons (the manga-draft.py feed).
    narrative_mode per beat + grammar ratios, BLAME!/Homunculus axis."""
    modes = [s["narrative_mode"] for s in spreads if s.get("narrative_mode")]
    n = len(modes) or 1
    lessons = {
        "beats": [{"narrative_mode": s.get("narrative_mode", "unknown"),
                   "panel_flow": s.get("panel_flow", ""),
                   "page_turn_hook": s.get("page_turn_hook", ""),
                   "imagery_carries": s.get("imagery_carries", "")}
                  for s in spreads],
        "ratios": {"image_only": modes.count("image-only") / n,
                   "dialogue_only": modes.count("dialogue-only") / n,
                   "mixed": modes.count("mixed") / n},
        "grammar_notes": sorted({s.get("panel_flow", "") for s in spreads
                                 if s.get("panel_flow")}),
        "hooks": [s["page_turn_hook"] for s in spreads
                  if s.get("page_turn_hook")],
        "script_annotation": ("narrative-mode register per beat: "
                              "image-only beats need no dialogue bank; "
                              "dialogue-only beats lean on narration; "
                              "mixed is the house default"),
    }
    return lessons


def run(archive, title=None):
    names = _image_members(archive)
    pairs = pick_spreads(names)
    if not pairs:
        raise RuntimeError("no spreadable pages in %s" % archive)
    tmp = tempfile.mkdtemp(prefix="manga-vision-")
    try:
        flat = [m for pair in pairs for m in pair]
        extracted = _extract_pages(archive, flat, tmp)
        spreads = []
        for pair in pairs:
            paths = [extracted[m] for m in pair]
            raw = VISION_CALL(SPREAD_PROMPT, paths)
            spreads.append(_parse_json_loose(raw))
        lessons = distill(spreads)
        lessons["title"] = title or os.path.basename(archive)
        lessons["spreads_sampled"] = len(pairs)
        return lessons
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


VISION_CALL = vision_call


def _maybe_stub_from_env():
    """Hermetic CLI hook: MANGA_VISION_TEST_STUB=1 swaps the real
    multimodal call for a deterministic stub (tests only, never prod)."""
    if os.environ.get("MANGA_VISION_TEST_STUB") == "1":
        def stub(prompt, paths, timeout=300):
            return json.dumps({
                "panel_flow": "stub flow", "reading_order": "right-to-left",
                "narrative_mode": "image-only", "dialogue_elements": "none",
                "imagery_carries": "stub imagery",
                "page_turn_hook": "stub hook"})
        global VISION_CALL
        VISION_CALL = stub


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True)
    ap.add_argument("--title")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    _maybe_stub_from_env()
    lessons = run(args.archive, args.title)
    out = json.dumps(lessons, indent=1, sort_keys=True)
    if args.out:
        with open(args.out, "w") as f:
            f.write(out + "\n")
    else:
        print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
