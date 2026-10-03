#!/usr/bin/env python3
"""dashboard-introspect -- the metacyclic feedback loop beat (2026-09-27).

Evaluates the operator-intent probes in docs/design/dashboard-intent.md
against the dashboard surface at file/JSON level (no browser; DOM-level
judgment stays with the ui-evolve overlay machinery), then closes the
loop:

  unmet probe  -> one research arc row in research-subjects.txt
                  (id arc-<date>-dashboard-<slug>, deduped by id; the
                  hourly 33-research-beat chews the arc like any other
                  subject)
  regression   -> report-queue alert, identity
                  dashboard-regression:<slug>, window 86400, evidence =
                  the fresh failing detail (a met probe that turned unmet
                  re-fires only while it stays unmet at the same detail)
  grade        -> report-queue progress row, identity
                  dashboard-introspect:grade, evidence = "M/T" (re-fires
                  only when the grade moves)

Jev doctrine (operator addendum 2026-09-27): the deterministic probe
results alone decide met/unmet and WHETHER an arc files. When several
gaps are pending, ONE batched typesafe ask_nouls call may ORDER the
filing (input-only priced, timeout-bounded, fail-open: unreachable Jev
files arcs in probe order). Jev advises, never certifies.

Closure criterion: a probe met on introspect-retire-streak consecutive
grades closes its era (state era counter increments) and stops filing
duplicate arcs; if it goes unmet again a FRESH arc id (-r<era>) re-opens
it. State: automation/state/introspect-state.json (gitignored).

Fail-open everywhere: probe errors count as unmet with the error as
detail, every report/arc write is best-effort, exit 0 always.

Test seams (automation/tests/test-dashboard-introspect.sh):
  INTROSPECT_DASH / INTROSPECT_SUBJECTS / INTROSPECT_STATE
  HNGH_REPORT_QUEUE / HNGH_REPORT_ROOT
  INTROSPECT_JEV=0 disables the Jev ordering call (tests)
  INTROSPECT_MIN_GAP_HOURS / INTROSPECT_RETIRE_STREAK /
  INTROSPECT_WIRE_MAX_SHARE / INTROSPECT_JEV_MIN_GAPS env overrides
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time

AUTOMATION_ROOT = os.environ.get(
    "AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DASH = os.environ.get(
    "INTROSPECT_DASH", os.path.join(AUTOMATION_ROOT, "dashboard"))
SUBJECTS = os.environ.get(
    "INTROSPECT_SUBJECTS",
    os.path.join(AUTOMATION_ROOT, "research-subjects.txt"))
STATE_FILE = os.environ.get(
    "INTROSPECT_STATE",
    os.path.join(AUTOMATION_ROOT, "state", "introspect-state.json"))
RQ = os.environ.get(
    "HNGH_REPORT_QUEUE",
    os.path.join(AUTOMATION_ROOT, "..", "scripts", "report-queue"))
REPORT_ROOT = os.environ.get(
    "HNGH_REPORT_ROOT", os.path.dirname(AUTOMATION_ROOT))

VOICE_CATS = {"system", "operator", "research", "hngh", "resources"}
WIRE_CATS = {"politics", "world", "business", "sports", "technology",
             "military", "space", "entertainment", "games"}

# slug -> (severity, research question)
INTENTS = [
    ("masthead-splash", "major",
     "How should the broadsheet masthead render a volumetric ASCII-art "
     "splash title (banner-glyph table in broadsheet-view.js), and which "
     "module owns the glyph renderer?"),
    ("masthead-expansion", "major",
     "Where should the procedural H.N.G.H. expansion generator live so "
     "newspaper.json edition.masthead.expansion carries four fully "
     "spelled words with initials H N G H?"),
    ("masthead-varies", "minor",
     "How should edition.masthead.expansion vary per edition without "
     "colliding across the editions history window?"),
    ("masthead-emboss", "minor",
     "What ink-emboss text-shadow treatment should broadsheet.css apply "
     "to the masthead rule?"),
    ("masthead-temperature", "minor",
     "How should broadsheet-view.js emit the masthead temperature in "
     "both degrees C and degrees F?"),
    ("paper-texture", "major",
     "How should the paper-texture canvas stay animated across the whole "
     "page without breaching the single-WebGL-context budget?"),
    ("printed-frames", "minor",
     "Which printed-frame border treatment should broadsheet.css use so "
     "every card reads as ink on paper?"),
    ("leaf-light-motion", "minor",
     "How should the dappled leaf-light animation stay frame-rate "
     "independent and honor prefers-reduced-motion?"),
    ("choice-previews", "major",
     "How should operator-item choices always carry outcome preview text "
     "in newspaper.json composition?"),
    ("dismiss-immediate", "major",
     "How should broadsheet dismissals update the rendered stream "
     "immediately (in-place DOM/state update) instead of waiting for a "
     "refetch? Landed 2026-10-03: dismissed-family verbs drop the card "
     "on rebuild via the broadsheet-dismissed store; handle/acknowledge "
     "mark the card in place (dim + chip) via broadsheet-handled."),
    ("no-dead-buttons", "major",
     "Which wiring pass guarantees every broadsheet.html button id has a "
     "live handler in broadsheet-view.js?"),
    ("family-card", "major",
     "How should newspaper composition collapse a flood of empty "
     "feedback ideas into one family card (family:true marker)?"),
    ("no-empty-feedback", "major",
     "What composition-side filter drops or folds empty [feedback:idea] "
     "items so they never render as individual articles?"),
]
INTENTS += [
    ("voice-majority", "major",
     "How should newspaper composition reach the operator's voice-"
     "majority target (>=60% system/operator/research/hngh articles)?"),
    ("wire-capped", "minor",
     "What cap and demotion rule keeps wire-category articles at or "
     "below the configured share of the edition?"),
    ("single-webgl", "minor",
     "How should the paper texture and the megastructure map share one "
     "WebGL context (or one canvas) in broadsheet-view.js?"),
    ("reduced-motion", "major",
     "Where does the broadsheet honor prefers-reduced-motion so all "
     "animations (paper, leaf-light, map) collapse to static?"),
    ("no-client-today", "major",
     "How should the broadsheet keep every displayed date sourced from "
     "newspaper.json rather than client Date?"),
    ("evidence-sources", "major",
     "What composition guard drops wire articles lacking sources so the "
     "broadsheet stays evidence-only?"),
    ("fail-closed-auth", "major",
     "How should broadsheet fetches attach the dashboard token and fail "
     "closed (error state, no fake data) on 401/403?"),
    ("feed-error-banner", "minor",
     "How should the broadsheet surface a feed-missing error banner "
     "instead of an empty page?"),
    ("scroll-60fps", "minor",
     "How should the broadsheet stream stay lazily rendered "
     "(IntersectionObserver sentinel) so scroll holds 60fps?"),
]
INTENTS += [
    ("feedback-flood", "major",
     "What keeps open [feedback:idea] from email items at zero in "
     "operator-items.json (the 2026-09-11..27 flood leak must never "
     "recapture the operator lane)?"),
    ("edition-fresh", "major",
     "How does newspaper composition keep newspaper.json fresh within "
     "its compose cadence so the front page never trails by hours?"),
    ("editorial-present", "major",
     "How does composition surface real hngh editorial rows (alerts, "
     "fleet notes, real operator decisions) instead of only stub-class "
     "internal content?"),
    ("expansion-rotation", "major",
     "How should broadsheet-view.js carry a rotation table of at least "
     "N spelled H.N.G.H. expansions so the masthead varies durably?"),
    ("ghost-desk", "major",
     "How should each edition carry ghost-counsel summary blocks or an "
     "explicit ghost_quiet marker, never silently neither?"),
    ("dismissed-clean", "major",
     "What keeps test-artifact ids out of operator-dismissed.json so "
     "smoke sentinels (dunder-prefixed keys) never pollute the "
     "durable dismiss ledger?"),
]
SLUGS = [i[0] for i in INTENTS]
SEVERITY = {i[0]: i[1] for i in INTENTS}
QUESTION = {i[0]: i[2] for i in INTENTS}


def get_param(key, default):
    """env > cadence-params.tsv col2 > default (params.sh precedence)."""
    env = os.environ.get(key.upper().replace("-", "_"))
    if env not in (None, ""):
        return env
    try:
        with open(os.path.join(AUTOMATION_ROOT, "cadence-params.tsv"),
                  encoding="utf-8") as f:
            for line in f:
                cols = line.rstrip("\n").split("\t")
                if len(cols) >= 2 and cols[0] == key and cols[1] != "":
                    return cols[1]
    except OSError:
        pass
    return default


def _read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def probe_feed(data):
    """JSON-level probes -> {slug: (met, detail)} for newspaper.json."""
    out = {}
    edit = data.get("edition") or {}
    arts = data.get("articles") or []

    # masthead-expansion / masthead-varies
    mh = edit.get("masthead") or {}
    exp = mh.get("expansion") or ""
    words = [w.strip(".") for w in exp.split()]
    initials_ok = (len(words) == 4
                   and all(len(w) >= 3 for w in words)
                   and "".join(w[0].lower() for w in words) == "hngh")
    out["masthead-expansion"] = (
        initials_ok, "expansion=%r" % exp[:60])
    hist = set()
    for e in data.get("editions") or []:
        x = ((e.get("masthead") or {}).get("expansion") or "").strip()
        if x:
            hist.add(x)
    out["masthead-varies"] = (
        len(hist) >= 2, "distinct expansions=%d" % len(hist))

    # ghost-desk: ghost summary blocks or an explicit quiet marker
    out["ghost-desk"] = (
        bool(edit.get("ghost")) or bool(edit.get("ghost_quiet")),
        "ghost=%s ghost_quiet=%s" % (
            bool(edit.get("ghost")), bool(edit.get("ghost_quiet"))))

    # choice-previews: every choice of every article has an outcome
    bad = n_choice_arts = 0
    for a in arts:
        ch = a.get("choices")
        if not ch:
            continue
        n_choice_arts += 1
        bad += sum(1 for c in ch if not (c.get("outcome") or "").strip())
    out["choice-previews"] = (
        n_choice_arts > 0 and bad == 0,
        "choice-articles=%d missing-outcomes=%d" % (n_choice_arts, bad))
    return out


def probe_feed_balance(data):
    """family/noise/balance probes (split out: probe_feed stays small)."""
    arts = data.get("articles") or []
    out = {}
    fam = sum(1 for a in arts if a.get("family") is True)
    empty_fb = voice = wire = wire_missing_src = 0
    for a in arts:
        cat = (a.get("category") or "").strip().lower()
        head = (a.get("headline") or "").strip()
        if cat in VOICE_CATS:
            voice += 1
        if cat in WIRE_CATS:
            wire += 1
            if not [s for s in (a.get("sources") or []) if str(s).strip()]:
                wire_missing_src += 1
        if head.startswith("[feedback:idea]") and a.get("family") is not True:
            body = a.get("body")
            blocks = body if isinstance(body, list) else (
                [body] if body else [])
            if not [b for b in blocks if str(b).strip()]:
                empty_fb += 1
    total = len(arts)
    out["family-card"] = (fam <= 1, "family-marked=%d" % fam)
    out["no-empty-feedback"] = (
        empty_fb == 0, "individual-empty-feedback=%d" % empty_fb)
    voice_share = (100.0 * voice / total) if total else 0.0
    out["voice-majority"] = (
        total > 0 and voice_share >= 60.0,
        "voice=%d/%d=%.0f%%" % (voice, total, voice_share))
    try:
        wire_max = float(get_param("introspect-wire-max-share", "25"))
    except ValueError:
        wire_max = 25.0
    wire_share = (100.0 * wire / total) if total else 0.0
    out["wire-capped"] = (
        total > 0 and wire_share <= wire_max,
        "wire=%d/%d=%.0f%% cap=%.0f%%" % (wire, total, wire_share, wire_max))
    out["evidence-sources"] = (
        wire > 0 and wire_missing_src == 0,
        "wire-articles-without-sources=%d" % wire_missing_src)

    # editorial-present: real hngh editorial rows (review 2026-09-27:
    # 100% of internal content was stub-class). File-level discriminator:
    # alerts/fleet categories, or a real operator decision card (not
    # feedback-flood residue). Research-route stubs carry no payload
    # discriminator, so they do not count.
    try:
        edit_min = int(get_param("introspect-editorial-min", "1"))
    except ValueError:
        edit_min = 1
    editorial = sum(
        1 for a in arts
        if (a.get("category") or "").strip().lower() in ("alerts", "fleet")
        or ((a.get("category") or "").strip().lower() == "operator"
            and "[feedback:idea]" not in (a.get("headline") or "")))
    out["editorial-present"] = (
        total > 0 and editorial >= edit_min,
        "editorial=%d min=%d" % (editorial, edit_min))
    return out


def probe_code(view, css, html):
    """File-level probes over the view/css/html text."""
    out = {}
    # masthead-temperature: view emits both units (review axis-1:
    # client-side cToF conversion, e.g. "14.3°C / 57.7°F")
    degc = "°C" in view
    degf = "°F" in view
    out["masthead-temperature"] = (degc and degf, "°C=%s °F=%s" % (
        degc, degf))

    # expansion-rotation: view declares an expansion rotation table
    # (EXPANSION marker) with >= N spelled H.N.G.H. candidates
    try:
        exp_min = int(get_param("introspect-expansion-min", "4"))
    except ValueError:
        exp_min = 4
    pos = view.find("EXPANSION")
    rotations = 0
    if pos >= 0:
        for lit in re.findall(r"['\"]([^'\"]{12,})['\"]",
                              view[pos:pos + 800]):
            words = [w for w in re.split(r"\W+", lit) if len(w) >= 3]
            if len(words) == 4 and "".join(
                    w[0] for w in words).lower() == "hngh":
                rotations += 1
    out["expansion-rotation"] = (
        pos >= 0 and rotations >= exp_min,
        "table=%s expansions=%d min=%d" % (
            pos >= 0, rotations, exp_min))

    out["masthead-splash"] = (
        "splash" in view and "ascii" in view.lower(),
        "splash=%s ascii=%s" % ("splash" in view, "ascii" in view.lower()))

    emboss = False
    lines = css.splitlines()
    for i, ln in enumerate(lines):
        if "masthead" in ln and "{" in ln:
            if any("text-shadow" in x for x in lines[i:i + 7]):
                emboss = True
                break
    out["masthead-emboss"] = (emboss, "css masthead text-shadow=%s" % emboss)

    out["paper-texture"] = (
        "paper-canvas" in html and "paperInit" in view,
        "html-canvas=%s paperInit=%s" % (
            "paper-canvas" in html, "paperInit" in view))
    dbl = re.search(r"border[^;:]*:\s*[^;]*\bdouble\b", css) is not None
    out["printed-frames"] = (dbl, "css double-rule=%s" % dbl)
    dapple = "dapple" in view.lower() or "leaf" in view.lower()
    out["leaf-light-motion"] = (dapple, "dapple/leaf=%s" % dapple)
    out["dismiss-immediate"] = (
        "dismiss" in view.lower()
        and re.search(r"removeChild|classList|\.remove\(|hidden", view)
        is not None,
        "dismiss+dom-update")
    ids = re.findall(r'<button[^>]*\bid="([^"]+)"', html)
    missing = [i for i in ids if i not in view]
    out["no-dead-buttons"] = (
        len(ids) > 0 and not missing,
        "buttons=%d unbound=%s" % (len(ids), ",".join(missing) or "none"))
    gl_sites = (len(re.findall(r"getContext\(\s*['\"]webgl", view))
                + len(re.findall(r"WebGLRenderer", view)))
    out["single-webgl"] = (gl_sites <= 1, "webgl-context-sites=%d" % gl_sites)
    rm = ("prefers-reduced-motion" in view
          or "prefers-reduced-motion" in css)
    out["reduced-motion"] = (rm, "prefers-reduced-motion=%s" % rm)
    client_today = "new Date(" in view or "toISOString(" in view
    out["no-client-today"] = (
        not client_today, "client-date-derivation=%s" % client_today)
    auth = ("hngh-token" in view
            and re.search(r"\b40[13]\b", view) is not None)
    out["fail-closed-auth"] = (auth, "token+401/403=%s" % auth)
    banner = "papererr" in html and "papererr" in view
    out["feed-error-banner"] = (banner, "papererr html+view=%s" % banner)
    out["scroll-60fps"] = (
        "IntersectionObserver" in view,
        "IntersectionObserver=%s" % bool("IntersectionObserver" in view))
    return out


FEED_SLUGS = {"masthead-expansion", "masthead-varies",
              "choice-previews", "family-card", "no-empty-feedback",
              "voice-majority", "wire-capped", "evidence-sources",
              "ghost-desk", "editorial-present", "feedback-flood",
              "edition-fresh", "dismissed-clean"}


def probe_operator():
    """feedback-flood: open [feedback:idea] items must be zero (the
    2026-09-11..27 leak filled all 40 operator-items slots)."""
    path = os.environ.get(
        "INTROSPECT_OPERATOR_ITEMS",
        os.path.join(DASH, "operator-items.json"))
    try:
        with open(path, encoding="utf-8") as f:
            op = json.load(f)
    except (OSError, ValueError) as exc:
        return {"feedback-flood": (False,
                "operator-items.json unreadable: %s" % exc)}
    rows = op.get("items") if isinstance(op, dict) else None
    rows = [r for r in rows or [] if isinstance(r, dict)]
    open_flood = sum(
        1 for r in rows
        if r.get("status") in (None, "", "open")
        and "[feedback:idea]" in (r.get("text") or ""))
    return {"feedback-flood": (open_flood == 0,
            "open-flood=%d items=%d" % (open_flood, len(rows)))}


def probe_dismissed():
    """dismissed-clean: no test-artifact keys in operator-dismissed.json.
    Sentinels are dunder-prefixed (observed: "__smoke_no_such_item__"
    leaked 2026-09-27T06:21Z from an unseamed smoke test); real ids are
    8-hex hashes or task slugs, never starting with '__'."""
    path = os.environ.get(
        "INTROSPECT_OPERATOR_DISMISSED",
        os.path.join(DASH, "operator-dismissed.json"))
    try:
        with open(path, encoding="utf-8") as f:
            op = json.load(f)
    except (OSError, ValueError) as exc:
        return {"dismissed-clean": (False,
                "operator-dismissed.json unreadable: %s" % exc)}
    rows = op.get("dismissed") if isinstance(op, dict) else None
    rows = [k for k in (rows or {}) if isinstance(k, str)]
    bad = [k for k in rows if k.startswith("__")]
    return {"dismissed-clean": (not bad,
            "sentinels=%s total=%d" % (",".join(bad) or "none", len(rows)))}


def probe_fresh(now):
    """edition-fresh: newspaper.json mtime within the compose cadence
    (hourly 41-newspaper-edition; 2h tolerates one missed compose)."""
    path = os.path.join(DASH, "newspaper.json")
    try:
        age_h = (now - os.path.getmtime(path)) / 3600.0
    except OSError as exc:
        return {"edition-fresh": (False, "newspaper.json: %s" % exc)}
    try:
        max_h = float(get_param("introspect-feed-max-age-hours", "2"))
    except ValueError:
        max_h = 2.0
    return {"edition-fresh": (age_h <= max_h,
            "age=%.1fh max=%.1fh" % (age_h, max_h))}


def run_probes():
    try:
        with open(os.path.join(DASH, "newspaper.json"),
                  encoding="utf-8") as f:
            data = json.load(f)
        feed_err = ""
    except (OSError, ValueError) as exc:
        data = None
        feed_err = "newspaper.json unreadable: %s" % exc
    view = _read(os.path.join(DASH, "broadsheet-view.js"))
    css = _read(os.path.join(DASH, "broadsheet.css"))
    html = _read(os.path.join(DASH, "broadsheet.html"))
    feed_probes = {}
    if data is not None:
        feed_probes = probe_feed(data)
        feed_probes.update(probe_feed_balance(data))
    feed_probes.update(probe_operator())
    feed_probes.update(probe_dismissed())
    feed_probes.update(probe_fresh(now=time.time()))
    results = {}
    for slug in SLUGS:
        if slug in feed_probes:
            results[slug] = feed_probes[slug]
        elif slug in FEED_SLUGS:
            results[slug] = (False, feed_err or "no feed data")
    results.update(probe_code(view, css, html))
    return [(slug, 1 if results[slug][0] else 0, str(results[slug][1])[:160])
            for slug in SLUGS]


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            st = json.load(f)
        if isinstance(st, dict) and isinstance(st.get("probes"), dict):
            st.setdefault("last_file_epoch", 0)
            return st
    except (OSError, ValueError):
        pass
    return {"probes": {}, "last_file_epoch": 0}


def save_state(st):
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(st, f, indent=1, sort_keys=True)
        os.replace(tmp, STATE_FILE)
    except OSError:
        pass  # fail-open: state loss only re-files one deduped arc


JEV_CHILD = r"""
import json, sys
sys.path.insert(0, sys.argv[1])
import typesafe
payload = json.load(open(sys.argv[2]))
scores = typesafe.ask_nouls(payload["state"], payload["questions"])
print(json.dumps(scores))
"""


def jev_order(pending):
    """ONE batched ask_nouls call ordering the pending gaps. ADVISORY
    ONLY: returns [] on any failure (caller falls back to probe order).
    Runs in a bounded child so a hung SDK can never stall the tick."""
    state = ("Dashboard intent-probe gap triage for the hngh broadsheet. "
             "Unmet probes decide arc filing already; you only rank which "
             "gap most deserves an engineering arc filed this hour. "
             "Pending gaps: "
             + "; ".join("%s (severity %s): %s" % (s, SEVERITY[s], QUESTION[s])
                         for s in pending))
    try:
        payload = json.dumps({"state": state, "questions": {
            s: "File a research arc for this gap this hour? "
               "(1 = file early, 0 = defer behind the others)"
            for s in pending}})
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".json",
                                         delete=False) as tf:
            tf.write(payload)
            path = tf.name
        try:
            timeout = float(get_param("introspect-jev-timeout", "20"))
            r = subprocess.run(
                [sys.executable, "-c", JEV_CHILD,
                 os.path.join(AUTOMATION_ROOT, "lib"), path],
                capture_output=True, text=True, timeout=timeout)
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass
        if r.returncode != 0:
            return []
        scores = json.loads(r.stdout or "{}")
        if not isinstance(scores, dict):
            return []
        return sorted(pending, key=lambda s: 0.0 if scores.get(s) is None
                      else -float(scores[s]))
    except Exception:
        return []  # fail-open: probe order


def rq(*args):
    try:
        env = dict(os.environ, HNGH_REPORT_ROOT=REPORT_ROOT)
        subprocess.run([RQ] + list(args), capture_output=True,
                       text=True, timeout=30, env=env)
    except Exception:
        pass  # fail-open: ledger rows are best-effort


def main():
    results = run_probes()
    st = load_state()
    probes = st["probes"]
    now = int(time.time())
    try:
        retire = max(1, int(get_param("introspect-retire-streak", "3")))
    except ValueError:
        retire = 3
    try:
        gap_hours = max(0.0, float(get_param("introspect-min-gap-hours",
                                             "1")))
    except ValueError:
        gap_hours = 1.0

    met = 0
    regressions = []
    pending = []  # unmet, not retired: arc candidates this run
    for slug, ok, detail in results:
        prev = probes.get(slug) or {}
        was_met = prev.get("last") == "met"
        if ok:
            met += 1
            streak = int(prev.get("streak", 0)) + 1
            era = int(prev.get("era", 0))
            if streak >= retire and int(prev.get("streak", 0)) < retire:
                era += 1  # era closes; a re-gap files a fresh -r<N> id
            probes[slug] = {"streak": streak, "era": era, "last": "met",
                            "detail": detail}
        else:
            probes[slug] = {"streak": 0, "era": int(prev.get("era", 0)),
                            "last": "unmet", "detail": detail}
            if was_met:
                regressions.append((slug, detail))
            pending.append(slug)
    total = len(results)
    window_open = (now - int(st.get("last_file_epoch", 0))) \
        >= gap_hours * 3600

    # Jev advises the filing ORDER only (one batched call, bounded);
    # the deterministic probes already decided the SET.
    order = pending
    try:
        jev_min = int(get_param("introspect-jev-min-gaps", "2"))
    except ValueError:
        jev_min = 2
    if len(pending) >= jev_min \
            and os.environ.get("INTROSPECT_JEV", "1") != "0":
        ranked = jev_order(pending)
        if ranked:
            order = ranked

    filed = []
    existing = set()
    try:
        with open(SUBJECTS, encoding="utf-8") as f:
            for line in f:
                existing.add(line.split("\t", 1)[0].strip())
    except OSError:
        pass
    day = time.strftime("%Y%m%d", time.gmtime())
    # regressions bypass the pacing window: fresh damage files now
    if (window_open or regressions) and pending:
        reg_slugs = {s for s, _ in regressions}
        rows = []
        for slug in order:
            if not window_open and slug not in reg_slugs:
                continue
            era = int(probes[slug].get("era", 0))
            arc_id = "arc-%s-dashboard-%s%s" % (
                day, slug, "-r%d" % era if era else "")
            if arc_id in existing:
                continue  # dedupe by id, never file duplicates
            rows.append("%s\t%s\n" % (arc_id, QUESTION[slug]))
            existing.add(arc_id)
            filed.append(arc_id)
        if rows:
            try:
                with open(SUBJECTS, "a", encoding="utf-8") as f:
                    f.writelines(rows)
                st["last_file_epoch"] = now
            except OSError:
                filed = []  # fail-open

    for slug, detail in regressions:
        rq("--add", "alert",
           "dashboard regression: probe %s was met, now unmet (%s) -- "
           "intent docs/design/dashboard-intent.md" % (slug, detail),
           "--identity", "dashboard-regression:%s" % slug,
           "--window", "86400", "--evidence",
           hashlib.sha256(detail.encode("utf-8")).hexdigest()[:12])
    grade = "%d/%d" % (met, total)
    rq("--add", "progress",
       "dashboard introspection grade %s met; filed=%d regressions=%d "
       "(probes docs/design/dashboard-intent.md)" % (
           grade, len(filed), len(regressions)),
       "--identity", "dashboard-introspect:grade",
       "--window", "86400", "--evidence", grade)

    save_state(st)
    # last line = machine summary the beat wrapper turns into a crumb
    print("dashboard-introspect: grade %s met; arcs=%s regressions=%d "
          "window=%s" % (grade, ",".join(filed) if filed else "none",
                         len(regressions),
                         "open" if window_open else "closed"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
