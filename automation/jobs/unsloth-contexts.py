#!/usr/bin/env python3
"""Per-model context-limit registry for the local Unsloth llama-server.

Load-time probing per model is impractical (each load swaps weights, minutes
of VRAM pressure). Instead: the RUNNING model's limit is captured
opportunistically (server 400 errors / props), every other model's limit
comes from its HF model card, and the registry records the source per row.

Usage:
  unsloth-contexts.py --fixture DIR   # run against cached card snippets
  unsloth-contexts.py --update        # hit HF, refresh the TSV (polite 1s spacing)

Output: automation/config/unsloth-contexts.tsv
  model_id  server_observed  card_native  card_max_extended  source_url  checked_at
"""
import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, "config", "unsloth-contexts.tsv")
HF = "https://huggingface.co"
UA = {"User-Agent": "hngh-context-registry/1"}

# "131072", "262144 (1M with YaRN)" etc. — the two numbers we care about.
CTX_NUM = r"(\d{3,9})"
NATIVE_PATTERNS = [
    r"native context length of " + CTX_NUM,
    r"context length of " + CTX_NUM,
    r"max(?:imum)? context (?:length|window)?(?: of)? " + CTX_NUM,
    r"max_position_embeddings\D{0,20}" + CTX_NUM,
    r"trained (?:with|at|on) (\d[\d,.]*\s*[KMB]?)",
]
EXTEND_PATTERNS = [
    r"(\d[\d,.]*\s*[KMB])\s*(?:\(?)(?:with|via|using|extends? to|extends up to)",
    r"YaRN[^.]{0,80}?(\d[\d,.]*\s*[KMB])",
    r"(\d[\d,.]*\s*[KMB])[^.]{0,40}?YaRN",
    r"extended? (?:to|up to) (\d[\d,.]*\s*[KMB])",
]


def _kmb(value):
    m = re.match(r"([\d.]+)\s*([KMB])", value)
    if not m:
        return None
    n = float(m.group(1))
    return int(n * {"K": 1024, "M": 1024 * 1024, "B": 1024 ** 3}[m.group(2)])


def extract_contexts(card_text):
    """(native, max_extended) token counts from a model card, or None each."""
    native = None
    for pat in NATIVE_PATTERNS:
        m = re.search(pat, card_text, re.I)
        if m:
            g = m.group(1)
            native = _kmb(g) if re.search(r"[KMB]", g, re.I) else int(g)
            if native:
                break
    ext = None
    for pat in EXTEND_PATTERNS:
        m = re.search(pat, card_text, re.I)
        if m:
            ext = _kmb(m.group(1))
            if ext:
                break
    if native is not None and ext is not None and ext < native:
        ext = None
    return native, ext


def server_models():
    key = os.environ.get("UNSLOTH_API_KEY", "")
    req = urllib.request.Request("http://127.0.0.1:8888/v1/models",
                                 headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=10) as r:
        return sorted(m["id"] for m in json.load(r)["data"])


def hf_fetch(url):
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read().decode("utf-8", "replace")
    except Exception as e:
        print(f"  fetch failed {url}: {e}", file=sys.stderr)
        return None


def card_for(repo):
    """README text for a repo; for GGUF repos with no ctx claim, fall back
    to the base_model repo named in its README front-matter."""
    text = hf_fetch(f"{HF}/{repo}/raw/main/README.md")
    native, ext = extract_contexts(text or "")
    if native is None and text:
        m = re.search(r"base_model:\s*(?:\[?)(?:repo:\s*)?([\w.-]+/[\w.-]+)", text)
        if m and m.group(1) != repo:
            parent = m.group(1)
            ptext = hf_fetch(f"{HF}/{parent}/raw/main/README.md")
            pn, pe = extract_contexts(ptext or "")
            if pn is not None:
                return pn, pe, f"{HF}/{parent}"
    return native, ext, f"{HF}/{repo}" if text else ""


def update(out=TSV):
    today = datetime.date.today().isoformat()
    rows = []
    for mid in server_models():
        time.sleep(1.0)  # polite HF spacing
        native, ext, src = card_for(mid)
        rows.append([mid, "", native or "", ext or "", src, today])
        print(f"  {mid}: native={native} max_ext={ext}", file=sys.stderr)
    with open(out, "w") as f:
        f.write("model_id\tserver_observed\tcard_native\tcard_max_extended\t"
                "source_url\tchecked_at\n")
        for r in rows:
            f.write("\t".join(str(c) for c in r) + "\n")
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--fixture", help="dir of <id>.txt card snippets; emit TSV")
    ap.add_argument("--update", action="store_true", help="refresh from HF")
    ap.add_argument("--out", default=TSV, help="TSV output path")
    args = ap.parse_args()
    if args.update:
        update()
        return 0
    if args.fixture:
        today = "FIXTURE-DATE"
        with open(args.out, "w") as f:
            f.write("model_id\tserver_observed\tcard_native\tcard_max_extended\t"
                    "source_url\tchecked_at\n")
            found = []
            for dirpath, _dirs, files in os.walk(args.fixture):
                for name in sorted(files):
                    if name.endswith(".txt"):
                        found.append(os.path.join(dirpath, name))
            for path in sorted(found):
                text = open(path).read()
                native, ext = extract_contexts(text)
                mid = os.path.relpath(path, args.fixture)[:-4]
                f.write(f"{mid}\t\t{native or ''}\t{ext or ''}\t\t{today}\n")
        return 0
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
