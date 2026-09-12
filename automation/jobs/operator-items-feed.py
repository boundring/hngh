#!/usr/bin/env python3
"""operator-items-feed — build dashboard/operator-items.json: the structured
lifecycle (open -> handled -> dismissed) for "for the operator" items.

Sources (the existing dashboard pattern):
  - data.json digest: the "For the operator" bullet block
  - STATE.md breadcrumbs: lines whose detail matches papercut / flagged /
    needs / operator decision, plus alert details (first-lines)

Each item: {id: 8-hex of normalized text, text, first_seen, last_seen,
status, evidence}. status = "handled" when a LATER breadcrumb containing
resolved/fixed/closed shares a subject token with the item (date-ordered
scan); evidence carries that resolving crumb. first_seen survives reruns
via the prior operator-items.json. Dismissal lives in
dashboard/operator-dismissed.json (owned by dashboard-server.py POST
/operator-item/dismiss) — this feed never touches it.

Fail-closed: any parse failure exits leaving the prior file untouched.
Display layer only — never governance input.
"""
import hashlib
import json
import os
import re
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "dashboard", "data.json")
STATE = os.path.join(ROOT, "STATE.md")
OUT = os.path.join(ROOT, "dashboard", "operator-items.json")
DISMISSED = os.path.join(ROOT, "dashboard", "operator-dismissed.json")

RESOLVED_RE = re.compile(r"\b(resolved|fixed|closed)\b", re.I)
KEYWORD_RE = re.compile(r"papercut|flagged|needs|operator decision", re.I)
FILLER_RE = re.compile(r"^(otherwise|nothing)\b", re.I)
TOKEN_RE = re.compile(r"[a-z0-9][a-z0-9._/-]{4,}")
# ponytail: cap keeps the panel sane under stale-store alert spam; raise if real items get dropped
CAP = 40


def norm(text):
    return re.sub(r"\s+", " ", re.sub(r"\*+", "", str(text))).strip().lower()


def item_id(text):
    return hashlib.sha256(norm(text).encode()).hexdigest()[:8]


def subject_tokens(text):
    return set(TOKEN_RE.findall(norm(text)))


def digest_items():
    """'For the operator' bullets from the digest (same extraction as the
    dashboard's parseOperators)."""
    with open(DATA, encoding="utf-8") as f:
        d = json.load(f)
    txt = str(d.get("digest") or "")
    i = txt.lower().find("for the operator")
    if i < 0:
        return [], d.get("generated_at")
    sec = txt[i:]
    m = re.search(r"\n#{1,3}\s+\S", sec)
    if m:
        sec = sec[:m.start()]
    out = []
    for ln in sec.splitlines():
        ln = re.sub(r"\*+", "", ln.strip())
        if not re.match(r"^\d+[.)]\s|^\*\s|^-\s", ln):
            continue
        ln = re.sub(r"^\d+[.)]\s+|^\*\s+|^-\s+", "", ln).strip()
        if ln and not FILLER_RE.match(ln):
            out.append(ln)
    return out, d.get("generated_at")


def crumbs():
    """STATE.md lines date-ordered: (ts, 'job | event | detail', event, detail)."""
    rows = []
    with open(STATE, encoding="utf-8") as f:
        for ln in f:
            parts = [p.strip() for p in ln.rstrip("\n").split(" | ", 3)]
            if len(parts) != 4 or not parts[0]:
                continue
            ts, job, event, detail = parts
            rows.append((ts, "%s | %s | %s" % (job, event, detail),
                         event, detail))
    rows.sort(key=lambda r: r[0])
    return rows


def is_operator_item(event, joined):
    if re.match(r"alert", event, re.I):
        return True
    return bool(KEYWORD_RE.search(joined))


def main():
    prior = {}
    try:
        with open(OUT, encoding="utf-8") as f:
            for it in json.load(f).get("items") or []:
                if isinstance(it, dict) and it.get("id"):
                    prior[it["id"]] = it.get("first_seen")
    except Exception:
        pass  # no prior file / broken: first_seen falls back to today

    items, gen_at = [], None
    try:
        lines, gen_at = digest_items()
    except Exception:
        return  # unparsable data.json: keep prior file
    try:
        rows = crumbs()
    except Exception:
        return  # unparsable STATE.md: keep prior file
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    fallback_seen = gen_at or now

    # source items: digest bullets + matching STATE.md details
    for text in lines:
        items.append({"text": text, "first_seen": fallback_seen})
    for ts, joined, event, detail in rows:
        if is_operator_item(event, event + " " + detail) and not RESOLVED_RE.search(detail):
            items.append({"text": joined, "first_seen": ts})

    # dismissal ledger is read-only here: an item whose id the operator
    # already dismissed but the source still emits is marked recurring —
    # its dismissal is temporary by nature.
    dismissed = {}
    try:
        with open(DISMISSED, encoding="utf-8") as f:
            dismissed = json.load(f).get("dismissed") or {}
    except Exception:
        pass  # no ledger yet: nothing is recurring

    # merge: dedupe by id, keep earliest first_seen
    by_id = {}
    for it in items:
        iid = item_id(it["text"])
        cur = by_id.get(iid)
        if cur is None or it["first_seen"] < cur["first_seen"]:
            by_id[iid] = {"id": iid, "text": it["text"],
                          "first_seen": prior.get(iid, it["first_seen"])}
    # date-ordered resolution scan: first later RESOLVED crumb sharing a token
    for iid, it in by_id.items():
        toks = subject_tokens(it["text"])
        for ts, joined, _event, detail in rows:
            if ts <= it["first_seen"] or not RESOLVED_RE.search(detail):
                continue
            if toks & subject_tokens(detail):
                it["status"] = "handled"
                it["evidence"] = "%s %s" % (ts, joined)
                break
        it.setdefault("status", "open")
        it["last_seen"] = now
        if iid in dismissed:
            it["recurring"] = True

    # [feedback:] operator submissions outrank the standing alert crowd:
    # 4.5k historical alert crumbs would otherwise fill the whole cap and
    # leave the operator's own dashboard feedback invisible (2026-09-12).
    ranked = sorted(by_id.values(), key=lambda x: (
        "[feedback:" not in x["text"], x["status"] != "open"))
    out_items = ranked[:CAP]
    feed = {"generated_at": now, "items": out_items}
    # per-PID tmp — the 1m drop-in and refresh-dashboard.sh overlap (see
    # sessions-feed.py)
    tmp = "%s.%d.tmp" % (OUT, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(feed, f, indent=2)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    main()
