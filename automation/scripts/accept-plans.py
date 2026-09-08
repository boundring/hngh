#!/usr/bin/env python3
"""accept-plans — machine acceptance of proposed normal-risk plans.

Kernel contract (hngh docs/project/plans/README.md): a proposed
normal-risk plan is auto-accepted when its Verification steps are
runnable and both repos' gates are green; the accepted timestamp is
written into the front-matter. risk=critical plans park automatically —
alert row, never machine-touched. A blocked acceptance (red gate or
non-runnable verification) files an alert row naming the failed check:
a blocked cycle must never be silent again (2026-08-31 lesson — two
proposed plans sat unexecuted overnight while the machine reported
healthy).

Fail-closed: exits 0 in every expected path. Prints one
"accepted|blocked|parked <slug> <detail>" line per plan for the caller
to breadcrumb.

Seams (hermetic tests, never real gates/plans): HNGH_HOME (kernel
root), HNGH_AUTOMATION_ROOT, ACCEPT_KERNEL_GATE / ACCEPT_AUTOMATION_GATE
(command string, default "make test"), HNGH_REPORT_QUEUE /
HNGH_REPORT_ROOT (report writer), ACCEPT_LOG (execution log), DRY_RUN=1
(report what would happen, write nothing).
"""
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

FRONT = re.compile(
    r"<!--\s*plan:\s*status=(\w+)\s+risk=(\w+)\s+accepted=([^\s>]+)[^>]*-->")
VERIFICATION = re.compile(r"(?m)^[ \t]+Verification[ \t]*:")
DESIGN_REF = re.compile(r"docs/design/[A-Za-z0-9._/-]+\.md")
DESIGN_VAGUE = re.compile(
    r"(?i)\bdesign\s+(?:is\s+)?(?:pending|missing|needed|required)\b"
    r"|\bneeds?\s+a\s+design\b|\bno\s+design\b|\bawaits?\s+(?:a\s+)?design\b")

KERNEL = Path(os.environ.get(
    "HNGH_HOME", os.path.expanduser("~/Projects/etc/hngh")))
AUTOMATION = Path(os.environ.get(
    "HNGH_AUTOMATION_ROOT", Path(__file__).resolve().parent.parent))
PLANS = KERNEL / "docs" / "project" / "plans"
KERNEL_GATE = os.environ.get("ACCEPT_KERNEL_GATE", "make test")
AUTOMATION_GATE = os.environ.get("ACCEPT_AUTOMATION_GATE", "make test")
REPORT_QUEUE = os.environ.get(
    "HNGH_REPORT_QUEUE", str(KERNEL / "scripts" / "report-queue"))
REPORT_ROOT = os.environ.get("HNGH_REPORT_ROOT", str(KERNEL))
ACCEPT_LOG = os.environ.get(
    "ACCEPT_LOG", str(AUTOMATION / "logs" / "acceptance.log"))
EMAIL_NOTIFY = AUTOMATION / "scripts" / "notify-email.py"
EMAIL_LOG = AUTOMATION / "logs" / "notify-email.log"
DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"

now_utc = lambda: datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def steps_text(text):
    """Content of the '## Steps' section (up to the next '## ' heading)."""
    m = re.search(r"(?m)^## Steps[ \t]*$", text)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"(?m)^## ", rest)
    return rest[:nxt.start()] if nxt else rest


def first_unverified_step(steps):
    """1-based number of the first unchecked step lacking a following
    `Verification:` line, or 0 when every unchecked step is runnable."""
    lines = steps.splitlines()
    starts = [i for i, ln in enumerate(lines)
              if ln.startswith("- [ ]") or ln.startswith("- [x]")]
    for n, i in enumerate(starts, 1):
        if not lines[i].startswith("- [ ]"):
            continue  # checked steps are already met
        end = starts[starts.index(i) + 1] if n < len(starts) else len(lines)
        if not VERIFICATION.search("\n".join(lines[i:end])):
            return n
    return 0


def accepted_text(text, ts):
    """Front-matter flip: status=proposed -> accepted, accepted=- -> ts."""
    m = FRONT.search(text)
    new = m.group(0).replace("status=proposed", "status=accepted", 1) \
                    .replace("accepted=-", "accepted=" + ts, 1)
    return text[:m.start()] + new + text[m.end():]


def held_text(text, ts):
    """status=proposed -> held with cause=missing-design held=<ts> appended
    inside the header comment."""
    m = FRONT.search(text)
    new = m.group(0).replace("status=proposed", "status=held", 1)
    if "held=" in new:
        new = re.sub(r"held=[^\s>]+", "held=" + ts, new)
    else:
        new = new.replace("-->", "cause=missing-design held=%s -->" % ts)
    return text[:m.start()] + new + text[m.end():]


def reproposed_text(text):
    """status=held -> proposed; cause=/held= stay in the header as history."""
    m = FRONT.search(text)
    new = m.group(0).replace("status=held", "status=proposed", 1)
    return text[:m.start()] + new + text[m.end():]


def missing_designs(text, kernel=None):
    """Explicit docs/design/*.md paths named by the plan that do not exist
    in the kernel repo. Only written-out paths trigger (precision-first);
    vague wording is the caller's warning-only concern."""
    kernel = kernel or KERNEL
    return [ref for ref in sorted(set(DESIGN_REF.findall(text)))
            if not (kernel / ref).exists()]


def append_research_subject(slug, question):
    """Python mirror of lib/causes.sh append_research_subject: append a
    fail-<date>-<slug> row to research-subjects.txt with the same dedup
    rule — skip when an id with that prefix already exists OR any row
    already asks the same question. Returns True when a row was appended."""
    path = Path(os.environ.get("HNGH_RESEARCH_SUBJECTS")
                or (AUTOMATION / "research-subjects.txt"))
    day = datetime.now(timezone.utc).strftime("%Y%m%d")
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "-", slug).strip("-")
    if not slug:
        return False
    sid = "fail-%s-%s" % (day, slug)
    try:
        rows = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        rows = []
    for row in rows:
        cols = row.split("\t")
        if (cols and cols[0].startswith(sid)) or \
                (len(cols) > 1 and cols[1] == question):
            return False
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write("%s\t%s\n" % (sid, question))
    except OSError:
        return False
    return True


def write_atomic(path, text):
    tmp = str(path) + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, path)


def report(kind, text, ident, window):
    if DRY_RUN:
        return
    try:
        subprocess.run(
            [REPORT_QUEUE, "--add", kind, text,
             "--identity", ident, "--window", str(window)],
            env={**os.environ, "HNGH_REPORT_ROOT": REPORT_ROOT},
            capture_output=True, timeout=30)
    except Exception:
        pass  # a lost report row must not block the cycle
    if kind == "alert":
        email_sidechannel("hngh alert: %s" % ident, text)


def email_sidechannel(subject, text):
    """Best-effort email relay when the operator config exists.
    Only immediate-class alerts mail (classify_alert rubric in
    scripts/notify-email.py); the rest defer to the daily digest.
    Never blocks or fails the alert row (the row is the contract)."""
    conf = os.environ.get(
        "HNGH_NOTIFY_EMAIL_CONF",
        os.path.expanduser("~/.hngh-automation/notify-email.conf"))
    if not os.path.isfile(conf):
        return  # dormant: missing creds are an operator setup item
    try:
        cls = subprocess.run(
            [sys.executable, str(EMAIL_NOTIFY), "classify", "--text", text],
            capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        cls = "digest"  # classify failure defers to the quiet side
    if cls != "immediate":
        return
    try:
        subprocess.run(
            [sys.executable, str(EMAIL_NOTIFY), "send",
             "--subject", subject, "--body-text", text],
            capture_output=True, timeout=45)
    except Exception as exc:
        try:
            EMAIL_LOG.parent.mkdir(parents=True, exist_ok=True)
            with open(EMAIL_LOG, "a", encoding="utf-8") as fh:
                fh.write("%s | relay failed: %s\n" % (now_utc(), exc))
        except OSError:
            pass


def run_gate(cmd, cwd):
    try:
        p = subprocess.run(shlex.split(cmd), cwd=str(cwd), capture_output=True,
                           text=True, timeout=600)
        return p.returncode, (p.stdout + p.stderr)[-400:]
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, str(exc)[-400:]


def note(line):
    print(line)
    if DRY_RUN:
        return
    try:
        os.makedirs(os.path.dirname(ACCEPT_LOG), exist_ok=True)
        with open(ACCEPT_LOG, "a", encoding="utf-8") as fh:
            fh.write("%s | %s\n" % (now_utc(), line))
    except OSError:
        pass


def main():
    candidates = []
    try:
        names = sorted(os.listdir(PLANS))
    except OSError:
        return 0
    for name in names:
        if not name.endswith(".plan.md"):
            continue
        try:
            with open(os.path.join(PLANS, name), encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        m = FRONT.search(text)
        if not m:
            continue
        slug = name[:-len(".plan.md")]
        if m.group(1) == "held":
            # the gate re-evaluates held plans every run: when the design
            # has landed, the plan re-enters the proposed pool
            if missing_designs(text):
                note("still-held %s missing-design" % slug)
            else:
                if not DRY_RUN:
                    write_atomic(PLANS / name, reproposed_text(text))
                report("progress", "plan %s: design landed; plan re-proposed"
                       % slug, "design-hold:" + slug, 86400)
                note("re-proposed %s design-landed" % slug)
            continue
        if m.group(1) != "proposed":
            continue
        if m.group(2) == "critical":
            report("alert", "critical-class plan %s parked for the operator "
                   "(never machine-executed)" % slug,
                   "overnight:plan-critical:" + slug, 604800)
            note("parked %s critical-class" % slug)
            continue
        missing = missing_designs(text)
        if missing:
            # grow cannot outrun its designs: an explicit reference to a
            # design doc that does not exist holds admission and demands
            # the design through the research beat
            ts = now_utc()
            names = ", ".join(missing)
            if not DRY_RUN:
                write_atomic(PLANS / name, held_text(text, ts))
            report("alert", "plan %s held (missing design): %s — delve: "
                   "produce or locate the design" % (slug, names),
                   "design-hold:" + slug, 86400)
            if not DRY_RUN:
                append_research_subject(
                    slug, "design %s missing for plan %s — delve: produce "
                    "or locate the design" % (names, slug))
            note("held %s missing-design:%s" % (slug, names))
            continue
        if DESIGN_VAGUE.search(text):
            note("warn %s vague-design-wording (no explicit path; "
                 "not a hold)" % slug)
        candidates.append((slug, text))
        # contract: runnable verification, then both gates green
    runnable = []
    for slug, text in candidates:
        bad = first_unverified_step(steps_text(text))
        if bad:
            report("alert", "plan %s not auto-accepted: step %d has no "
                   "Verification line" % (slug, bad),
                   "overnight:plan-accept-blocked:" + slug, 86400)
            note("blocked %s step-%d-no-verification" % (slug, bad))
            continue
        runnable.append((slug, text))
    if not runnable:
        return 0
    krc, kout = run_gate(KERNEL_GATE, KERNEL)
    arc, aout = run_gate(AUTOMATION_GATE, AUTOMATION)
    if krc != 0:
        report("alert", "plan acceptance blocked: kernel make test FAILED "
               "(rc=%d)\n%s" % (krc, kout.strip()),
               "overnight:plan-accept-gate:kernel", 86400)
        for slug, _ in runnable:
            note("blocked %s kernel-gate-red-rc%d" % (slug, krc))
        return 0
    if arc != 0:
        report("alert", "plan acceptance blocked: hngh-automation make test "
               "FAILED (rc=%d)\n%s" % (arc, aout.strip()),
               "overnight:plan-accept-gate:automation", 86400)
        for slug, _ in runnable:
            note("blocked %s automation-gate-red-rc%d" % (slug, arc))
        return 0
    ts = now_utc()
    for slug, text in runnable:
        if not DRY_RUN:
            write_atomic(PLANS / (slug + ".plan.md"), accepted_text(text, ts))
        report("progress", "plan %s auto-accepted (normal-risk, verification "
               "runnable, both gates green); accepted=%s" % (slug, ts),
               "overnight:plan-accepted:" + slug, 86400)
        note("accepted %s %s" % (slug, ts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
