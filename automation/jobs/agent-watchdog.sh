#!/usr/bin/env bash
# agent-watchdog — roguelike death watchdog: observes the live agent session
# surface, detects stall / identical-tool-loop / error-without-recovery, and
# records a LOG-ONLY handoff (ledger line + alert + attention flag). It does
# NOT kill or launch agents; ending-the-session is a logged decision an
# operator/agentic leg can act on (see roguelike-agentic.md).
#
# Session surface (honest): omp writes per-project transcripts under
#   ~/.omp/agent/sessions/<slug>/<session>.jsonl   (every tool call / result /
# message is a JSON line with a timestamp), and the LIVE roster is the broker
# client list under ~/.omp/run/daemons/*/clients/* ({"pid","projectDir"}). We
# read only that surface. We CANNOT see the LM's in-flight "thinking"; a stall
# is only inferred when a current session's transcript is quiet for a full
# window AND has no live subagent transcript writing (a legit session sitting on
# a running subagent is never flagged).
#
# Mounted from the cadence continuum via oversight-tick (5m tier). Fail-open on
# any scan error (a read hiccup is a crumb, never a false alarm).
#
# usage: agent-watchdog.sh   # scan + report
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/causes.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

HNGH_REPO="${HNGH_REPO:-/home/bricker/Projects/etc/hngh}"
REPORT_QUEUE="${REPORT_QUEUE:-$HNGH_REPO/scripts/report-queue}"
ATTENTION_FLAG="${ATTENTION_FLAG:-/tmp/hngh-overseer-attention}"

# --- tunables (env-overridable) -------------------------------------------
WATCHDOG_SESS_DIR="${WATCHDOG_SESS_DIR:-$HOME/.omp/agent/sessions}"
WATCHDOG_CLIENTS_ROOT="${WATCHDOG_CLIENTS_ROOT:-$HOME/.omp/run/daemons}"
HANDOFFS="${WATCHDOG_HANDOFFS:-$AUTOMATION_ROOT/agent-handoffs.md}"
SEEN="${WATCHDOG_SEEN:-/tmp/hngh-watchdog-seen.$(id -u)}"
STALL_MIN="${WATCHDOG_STALL_MIN:-$(get_param watchdog-stall-min 10)}"
LIVE_MIN="${WATCHDOG_LIVE_MIN:-$(get_param watchdog-live-min 180)}"
ERROR_GRACE_MIN="${WATCHDOG_ERROR_GRACE_MIN:-$(get_param watchdog-error-grace-min 2)}"
LOOP_N="${WATCHDOG_LOOP_N:-$(get_param watchdog-loop-n 3)}"

# --- detection (python3 for robust JSONL reads) ---------------------------
scan() {
 WATCHDOG_SESS_DIR="$WATCHDOG_SESS_DIR" \
  WATCHDOG_CLIENTS_ROOT="$WATCHDOG_CLIENTS_ROOT" \
  _HOME="$HOME" _STALL_MIN="$STALL_MIN" _LIVE_MIN="$LIVE_MIN" \
  _ERROR_GRACE_MIN="$ERROR_GRACE_MIN" _LOOP_N="$LOOP_N" \
  _EXTRA_PROJECTS="${WATCHDOG_EXTRA_PROJECTS:-}" \
  python3 -c '
import os,glob,json,time,datetime
home=os.environ["_HOME"]; now=time.time()
STALL=int(os.environ["_STALL_MIN"])*60
LIVE=int(os.environ["_LIVE_MIN"])*60
GRACE=int(os.environ["_ERROR_GRACE_MIN"])*60
LOOP=max(2,int(os.environ["_LOOP_N"]))
def slug(p):
    p=p[len(home):] if p.startswith(home) else p
    p=p.lstrip("/"); return "-"+p.replace("/","-")
def age(ts):
    try: d=datetime.datetime.strptime(ts.split(".")[0], "%Y-%m-%dT%H:%M:%S")
    except: return None
    return now - d.replace(tzinfo=datetime.timezone.utc).timestamp()
def errish(t):
    t=(t or "").lower()
    return any(k in t for k in ("traceback","fatal","exception","does not exist",
        "not found","error:","failed","permission denied","exit status",
        "assertionerror","fail:"))
live=set()
for f in glob.glob(os.path.join(os.environ["WATCHDOG_CLIENTS_ROOT"],"clients","*")):
    try:
        with open(f) as fh: live.add(json.load(fh)["projectDir"])
    except Exception: pass
for x in (os.environ.get("_EXTRA_PROJECTS") or "").split():
    if x: live.add(x)
for proj in sorted(live):
    s=os.path.join(os.environ["WATCHDOG_SESS_DIR"], slug(proj))
    if not os.path.isdir(s): continue
    js=[x for x in glob.glob(s+"/*.jsonl") if not x.endswith(".acp.json")]
    if not js: continue
    newest=max(js,key=os.path.getmtime)
    try: recs=[json.loads(l) for l in open(newest) if l.strip()]
    except Exception: continue
    if not recs: continue
    base=os.path.splitext(os.path.basename(newest))[0]
    sid=slug(proj)
    lrts=age(recs[-1].get("timestamp"))
    if lrts is None or lrts > LIVE: continue          # not a "current" session
    # last message role/kind
    last_role=None; last_kind=None; last_name=None
    for r in reversed(recs):
        m=r.get("message",{})
        if r.get("type")=="message":
            last_role=m.get("role")
            for c in (m.get("content") or []):
                if not isinstance(c,dict): continue
                if c.get("type")=="toolCall": last_kind="toolCall"; last_name=c.get("name")
                elif c.get("type")=="text": last_kind="text"
            break
    # C) error-without-recovery
    if last_role=="toolResult":
        text="".join(c.get("text","") for c in ((recs[-1].get("message",{}).get("content")) or []) if isinstance(c,dict))
        if errish(text) and lrts > GRACE and lrts <= LIVE:
            print("error|%s|%s|hard error result, no corrective step: %s" % (sid,base,text[:160])); continue
    # B) LOOP: trailing N tool calls identical
    calls=[]
    for r in recs:
        m=r.get("message",{})
        if m.get("role")!="assistant": continue
        for c in (m.get("content") or []):
            if isinstance(c,dict) and c.get("type")=="toolCall":
                try: args=json.dumps(c.get("arguments"),sort_keys=True)
                except Exception: args=str(c.get("arguments"))
                calls.append((c.get("name"),args))
    tail=calls[-LOOP:]
    if len(tail)==LOOP and all(x==tail[0] for x in tail):
        print("loop|%s|%s|identical tool call x%d: %s" % (sid,base,LOOP,tail[0][0])); continue
    # A) STALL: open thinking/toolcall turn quiet, no fresh subagent
    if last_role in ("assistant",) and last_kind in ("toolCall","text") and last_name!="hub" \
       and lrts > STALL and lrts <= LIVE:
        sub=os.path.join(s,base); fresh=0
        if os.path.isdir(sub):
            for root,dirs,files in os.walk(sub):
                for f in files:
                    if f.endswith(".jsonl") and not f.endswith(".acp.json"):
                        if age(os.path.join(root,f)) is not None and age(os.path.join(root,f)) < STALL: fresh=1
        if not fresh:
            mins=int(lrts//60)
            print("stall|%s|%s|no tool progress for %dm (turn %s open, no live subagent)" % (sid,base,mins,last_kind))
' 2>/dev/null
}

ingest() { # one finding line -> ledger + alert + attention (deduped)
 local cls subj sess reason
 IFS='|' read -r cls subj sess reason <<<"$1"
 [ -z "$cls" ] && return 0
 grep -qxF "$cls $subj $sess" "$SEEN" 2>/dev/null && return 0
 # cause column from the failure bestiary (lib/causes.sh), classified off
 # the session transcript tail; omitted when the transcript is gone
 # scan emits sid|base: subj is the project-slug directory, sess the
 # transcript basename
 local log_path="$WATCHDOG_SESS_DIR/$subj/$sess.jsonl" cause=""
 [ -f "$log_path" ] && cause=" cause=$(classify_cause "$log_path")"
 printf 'session-drop | %s | %s|%s | %s: %s%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$subj" "$sess" "$cls" "$reason" "$cause" >>"$HANDOFFS"
 [ -x "$REPORT_QUEUE" ] && "$REPORT_QUEUE" --add alert "[watchdog] $cls: $reason" >/dev/null 2>&1
 touch "$ATTENTION_FLAG" 2>/dev/null || true
 breadcrumb "agent-watchdog" "session-drop" "$cls | $subj|$sess | $reason"
 echo "$cls $subj $sess" >>"$SEEN"
}

main() {
 local line
 while IFS= read -r line; do
  ingest "$line"
 done
 exit 0
}
scan | main
