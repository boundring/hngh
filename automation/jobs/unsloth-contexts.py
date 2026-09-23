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

Per-row source semantics (hngh-npi; card_native vs card_max_extended):
  server_observed: opportunistically captured limit of the RUNNING model only
    (observe(): /api/inference/status > journal n_ctx line > 400 probe).
    Empty for every non-loaded model — never guessed, never copied from cards.
  card_native: base context length parsed from the model's HF card
    (extract_contexts NATIVE_PATTERNS); empty when the card states none.
  card_max_extended: extended limit via YaRN/RoPE phrasing (EXTEND_PATTERNS);
    empty when the card claims no extension. Dropped when < card_native.
  source_url: HF repo the numbers were read from; for GGUF repos with no ctx
    claim this is the base_model parent repo (card_for fallback), else "".
  Empty-field policy for non-context models (image/ASR, e.g. Z-Image-Turbo,
    qwen3-asr): all three numeric fields stay empty rather than guessed
    (extract_contexts returns (None, None); see test_non_context_model_unresolved).
Guard coordination (single source of truth: automation/lib/vip-gate.sh,
hngh-vip): heavy refresh/update runs (--update, --observe against a live
server) defer while an interactive session holds the resource (beat-skip
defer guard) and are gated to the midnight window (default 00:00-05:00
local). No guard logic is duplicated here; callers source vip-gate.sh.
"""
import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.request

_sys_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "automation", "lib")
sys.path.insert(0, _sys_path)
from secrets import secret  # noqa: E402 — sole 1Password seam

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, "config", "unsloth-contexts.tsv")
HF = "https://huggingface.co"
UA = {"User-Agent": "hngh-context-registry/1"}

# "131072", "262144 (1M with YaRN)" etc. — the two numbers we care about.
CTX_NUM = r"(\d{3,9})"
NATIVE_PATTERNS = [
    r"native context length of " + CTX_NUM,
    r"native context length of (?:up to )?(\d[\d.]*\s*[KM]?)",
    r"Context [Ll]ength:?\s*" + CTX_NUM,
    r"Context window\s*[|: ]+\s*(\d[\d.]*\s*[KM]?)",
    r"context length of " + CTX_NUM,
    r"max(?:imum)? context (?:length|window)?(?: of)? " + CTX_NUM,
    r"max_position_embeddings\D{0,20}" + CTX_NUM,
    r"trained (?:with|at|on) (\d[\d,.]*\s*[KMB]?)",
]
EXTEND_PATTERNS = [
    # K/M only: "35B"/"9B" are parameter counts, never token windows
    r"(\d[\d,.]*\s*[KM])\s*(?:\(?)(?:with|via|using|extends? to|extends up to)",
    r"YaRN[^.]{0,80}?(\d[\d,.]*\s*[KM])",
    r"(\d[\d,.]*\s*[KM])[^.]{0,40}?YaRN",
    r"extended? (?:to|up to) (\d[\d,.]*\s*[KMB])",
    r"extensible up to (\d[\d,.]*\s*[KM]?)",
]


def _kmb(value):
    m = re.match(r"([\d.]+)\s*([KMB])", value)
    if not m:
        return None
    n = float(m.group(1))
    return int(n * {"K": 1024, "M": 1024 * 1024, "B": 1024 ** 3}[m.group(2)])


def extract_contexts(card_text):
    """(native, max_extended) token counts from a model card, or None each."""
    card_text = re.sub(r"(\d),(\d\d\d)", r"\1\2", card_text)  # 262,144 -> 262144
    native = None
    for pat in NATIVE_PATTERNS:
        m = re.search(pat, card_text, re.I)
        if m:
            g = m.group(1)
            native = _kmb(g) if re.search(r"[KMB]", g, re.I) else int(g)
            if native and native >= 1024:  # else it caught a version/size
                break
            native = None
    ext = None
    for pat in EXTEND_PATTERNS:
        m = re.search(pat, card_text, re.I)
        if m:
            g = m.group(1)
            ext = _kmb(g) if re.search(r"[KMB]", g, re.I) else int(g.replace(",", ""))
            if ext and ext >= 1024:
                break
            ext = None
    if native is not None and ext is not None and ext < native:
        ext = None
    return native, ext


def server_models():
    key = secret("UNSLOTH_API_KEY")
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
    ap.add_argument("--observe", action="store_true",
                    help="refresh server_observed for the loaded model only")
    args = ap.parse_args()
    if args.observe:
        return observe(args.out)
    if args.update:
        update(args.out)
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




def _local_api(path):
    key = secret("UNSLOTH_API_KEY")
    req = urllib.request.Request("http://127.0.0.1:8888" + path,
                                 headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def match_row(rows, active_model):
    """Longest two-segment suffix match of the active model id -> row idx."""
    best = None
    for i, r in enumerate(rows):
        parts = r[0].split("/")
        key = "/".join(parts[:2]) if len(parts) > 1 else parts[0]
        if active_model and active_model.startswith(key):
            if best is None or len(r[0]) > len(rows[best][0]):
                best = i
    return best


def match_path(rows, model_path):
    """Journal -m path (a filesystem path, not an HF id) -> row idx:
    case-insensitive substring of the row id's leaf segment."""
    best = None
    for i, r in enumerate(rows):
        leaf = r[0].split("/")[-1].lower()
        if leaf and leaf in model_path.lower():
            if best is None or len(r[0]) > len(rows[best][0]):
                best = i
    return best


def hf_cache_id(model_ref):
    """HF hub-cache path -> "ORG/NAME" from its models--ORG--NAME dir
    component (models--unsloth--Ornith-1.0-9B-GGUF -> unsloth/Ornith-1.0-9B-GGUF),
    independent of the snapshot filename's variant+quant suffix; None when
    the ref carries no such component. (2026-09-23 defect cleanup)"""
    m = re.search(r"(?:^|/)models--([^/]+)", str(model_ref or ""))
    if not m:
        return None
    org, sep, name = m.group(1).partition("--")
    return f"{org}/{name}" if sep and name else None


def resolve_row(rows, *refs):
    """Row idx for the loaded model's references, preference order: (1) the
    served model id (match_row), (2) HF-cache path mapping (hf_cache_id).
    Fail-open None: unknown models get the breadcrumb, never a guessed row.
    (2026-09-23 defect cleanup)"""
    refs = [str(r) for r in refs if r]
    for ref in refs:  # (1) served model id
        idx = match_row(rows, ref)
        if idx is not None:
            return idx
    for ref in refs:  # (2) HF-cache path -> ORG/NAME
        hid = hf_cache_id(ref)
        idx = match_row(rows, hid) if hid else None
        if idx is not None:
            return idx
    return None


def journal_n_ctx():
    """Fallback #2: llama-server startup log line (model path + n_ctx)."""
    import subprocess
    out = subprocess.run(["journalctl", "--user", "-u", "unsloth-studio.service",
                          "-b", "--no-pager"], capture_output=True, text=True).stdout
    ctx = re.findall(r"n_ctx\D{0,8}(\d{3,9})", out)
    path = re.findall(r"-m\s+(\S+\.gguf)", out)
    return (path[-1] if path else None, int(ctx[-1]) if ctx else None)


def probe_payload():
    """Request body for probe_400: 'a ' pairs are ~1 token each, so this
    exceeds the largest registry context (card_max_extended 1048576)
    and is guaranteed a 400 -- hngh-bud: the old 150k-pair body FIT the
    studio's 262144 context and got processed (~4.4 min GPU)."""
    return {"model": "any", "max_tokens": 1, "messages": [
        {"role": "user", "content": "a " * 1_200_000}]}


def probe_400():
    """Last resort: one oversized-prompt request; the 400 message states n_ctx."""
    req = urllib.request.Request(
        "http://127.0.0.1:8888/v1/chat/completions",
        data=json.dumps(probe_payload()).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + secret("UNSLOTH_API_KEY")})
    try:
        urllib.request.urlopen(req, timeout=10)
        return None
    except urllib.error.HTTPError as e:
        m = re.search(r"n_ctx\D{0,8}(\d{3,9})", e.read().decode("utf-8", "replace"))
        return int(m.group(1)) if m else None


def observe(out=TSV):
    """Refresh server_observed for the LOADED model only.
    Signal order: /api/inference/status > journal n_ctx line > 400 probe."""
    with open(out) as f:
        lines = f.read().splitlines()
    header, rows = lines[0], [l.split("\t") for l in lines[1:]]
    today = datetime.date.today().isoformat()

    value = model_id = served_id = None
    try:
        st = _local_api("/api/inference/status")
        served_id = st.get("model_identifier")
        model_id = st.get("active_model")
        if st.get("loaded") and not st.get("loading"):
            value = st.get("max_context_length") or st.get("context_length")
    except Exception as e:
        print(f"  status endpoint unavailable: {e}", file=sys.stderr)
    src = "webapp:/api/inference/status"
    if value is None:
        path, nctx = journal_n_ctx()
        if nctx:
            value, model_id = nctx, path
            src = "journal:n_ctx"
        elif path:
            model_id = path
    if value is None:
        if model_id:
            idx = match_path(rows, str(model_id))
            if idx is not None and rows[idx][1].strip():
                print(f"observe: {rows[idx][0]} already server_observed="
                      f"{rows[idx][1]}; probe skipped", file=sys.stderr)
                return 0
        value = probe_400()
        src = "probe:400" if value else None
    if value is None or not (served_id or model_id):
        print("observe: no loaded model / no signal; registry unchanged",
              file=sys.stderr)
        return 0

    idx = resolve_row(rows, served_id, model_id)
    if idx is None:
        print(f"observe: no registry row matches {(model_id or served_id)!r}",
              file=sys.stderr)
        return 0
    rows[idx][1] = str(value)
    rows[idx][5] = today
    with open(out, "w") as f:
        f.write(header + "\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    print(f"observe: {rows[idx][0]} server_observed={value} ({src})", file=sys.stderr)
    return 0
# observe is wired below via argparse


if __name__ == "__main__":
    sys.exit(main())
