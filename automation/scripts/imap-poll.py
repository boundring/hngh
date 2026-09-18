#!/usr/bin/env python3
"""imap-poll — bidirectional email contact (read leg). Stdlib only.

Authorized by docs/records/2026-09-09-operator-flexibility-doctrine.md
s4 (operator-load surfaces) and stall-recovery plan step 11: notify-email
is send-only (SMTP); this script polls the same account over IMAP for
operator replies and converts each UNSEEN message into an operator-item
through the existing contract (lib/operator-item.sh -> alert_row +
breadcrumb). A reply carrying a decision on a parked plan additionally
writes a plan-proposal DRAFT under automation/digest/ (draft only --
accept-plans scans kernel docs/project/plans/, never automation/digest/,
so nothing is ever auto-accepted). A reply whose subject carries
[hngh <report-id>] (the 8-hex id of a docs/project/reports.md row)
additionally annotates that report's body sidecar
docs/project/report-bodies/<ts>-<kind>-<id>.md (created if absent) with
the reply date/from/body, and applies its directive grammar to matching
open operator-items (approve: -> handled, deny: -> dismissed,
note: / unknown / missing -> annotation only). No-match replies keep
the plain operator-item behavior; the linked path never writes the
ledger itself, never auto-accepts plans, and never deletes anything.

Config: the SAME notify-email.conf the send leg uses
(env seam HNGH_NOTIFY_EMAIL_CONF); this script never creates or edits
it. Keys beside the SMTP ones:

    [imap]
    host = imap.example.com
    port = 993
    user = the same account as [smtp] user
    ; optional alternative to the 1Password item:
    pass_cmd = secret-tool lookup ...   (argv, no shell)

Password precedence: [1password] item via `op read` (service-token
guarded, same as notify-email.py) -> [imap] pass_cmd -> [smtp] pass.
Nothing resolvable -> fail closed.

Fail-closed cadence-drop-in convention (cadence/1m/05-operator-items.sh):
missing conf, loose mode, missing [smtp]/[imap] keys, unresolvable
password, or any IMAP error -> one stderr line, one breadcrumb, exit 0,
nothing touched. Processed messages are marked \\Seen; messages are
NEVER deleted or expunged. Attachments/links/images are saved under
automation/inbox/ and the item text carries the PATH, never the content.

usage: imap-poll.py [--dry-run]
  --dry-run lists what WOULD be processed (count, senders, subjects)
  read-only; mutates nothing.
"""
import configparser
import email
import email.policy
import email.utils
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time

OP_TIMEOUT = 45
MAX_PER_TICK = 20
BODY_CAP = 2000  # chars of body inlined into the item text (path-only rule for attachments)
INBOX_SUBDIR = "inbox"       # under automation/: saved attachments
DRAFT_SUBDIR = "digest"      # under automation/: DRAFT-PLAN proposals (overnight-cycle convention)

LIBROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTOMATION = os.environ.get("HNGH_AUTOMATION_ROOT", LIBROOT)
KERNEL = os.environ.get("HNGH_HOME",
                        os.path.dirname(LIBROOT))


def noop(msg):
    """Fail-closed no-op: one stderr line + breadcrumb, exit 0."""
    sys.stderr.write("imap-poll: %s — no-op\n" % msg)
    env = dict(os.environ)
    env.setdefault("HOME", AUTOMATION)  # breadcrumbs.sh set -u needs HOME
    env.update({"AUTOMATION_ROOT": AUTOMATION,
                "STATE_FILE": os.path.join(AUTOMATION, "STATE.md"),
                "JOB_NAME": "imap-poll",
                "CRUMB": msg[:200]})
    subprocess.run(['bash', '-c',
                    '. "%s/lib/breadcrumbs.sh"\n'
                    'breadcrumb "$JOB_NAME" imap-dormant "$CRUMB"'
                    % LIBROOT], env=env, timeout=15,
                   capture_output=True)


def conf_path():
    return (os.environ.get("HNGH_NOTIFY_EMAIL_CONF")
            or os.path.join(os.path.expanduser("~"),
                            ".hngh-automation", "notify-email.conf"))


def load_conf():
    """The IMAP view of notify-email.conf, or (None, reason) to no-op on."""
    path = conf_path()
    if not os.path.isfile(path):
        return None, "no config at %s" % path
    if os.stat(path).st_mode & 0o077:
        return None, "config %s must be chmod 600" % path
    cp = configparser.ConfigParser()
    cp.read(path)
    if not cp.has_section("smtp") or not cp.has_section("imap"):
        return None, "config missing [smtp]/[imap] section"
    for key in ("host", "port", "user"):
        if not cp.has_option("imap", key):
            return None, "config missing [imap] %s" % key
    return cp, None


def op_password(item):
    """Secret from `op read`, or None on any failure. Never logged.
    Service-token-guarded: never reach the desktop-app integration
    (same discipline as notify-email.py op_run)."""
    if not os.environ.get("OP_SERVICE_ACCOUNT_TOKEN"):
        _key = os.environ.get("ONEPASSWORD_SERVICE_KEY")
        if _key:
            os.environ["OP_SERVICE_ACCOUNT_TOKEN"] = _key
    if not (os.environ.get("OP_SERVICE_ACCOUNT_TOKEN")
            or os.environ.get("ONEPASSWORD_SERVICE_KEY")):
        return None
    try:
        got = subprocess.run(
            [os.environ.get("HNGH_OP_BIN", "op"), "read", item],
            capture_output=True, timeout=OP_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    if got.returncode != 0:
        return None
    return got.stdout.decode("utf-8", "replace").strip() or None


def resolve_password(cp):
    """[1password] item -> [imap] pass_cmd -> [smtp] pass -> None."""
    if cp.has_section("1password") and cp.has_option("1password", "item"):
        pw = op_password(cp.get("1password", "item").strip())
        if pw:
            return pw
    if cp.has_option("imap", "pass_cmd"):
        try:
            got = subprocess.run(
                shlex.split(cp.get("imap", "pass_cmd").strip()),
                capture_output=True, timeout=OP_TIMEOUT)
        except (OSError, subprocess.SubprocessError):
            got = None
        if got and got.returncode == 0:
            pw = got.stdout.decode("utf-8", "replace").strip()
            if pw:
                return pw
    pw = cp.get("smtp", "pass", fallback="").strip()
    return pw or None


def body_text(msg):
    """First text/plain part (html stripped of tags as fallback)."""
    part = msg.get_body(preferencelist=("plain",))
    if part is None:
        part = msg.get_body(preferencelist=("html",))
        if part is None:
            return ""
        text = re.sub(r"(?s)<[^>]+>", " ",
                      part.get_content())
    else:
        text = part.get_content()
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()[:BODY_CAP]


def save_attachments(msg, msgid):
    """Non-text parts -> automation/inbox/<msgid8>-<name>; -> path list."""
    out = []
    inbox = os.path.join(AUTOMATION, INBOX_SUBDIR)
    for part in msg.iter_attachments():
        name = os.path.basename(part.get_filename() or "unnamed")
        payload = part.get_payload(decode=True)
        if payload is None:
            continue
        os.makedirs(inbox, exist_ok=True)
        path = os.path.join(inbox, "%s-%s" % (msgid, name))
        with open(path, "wb") as f:
            f.write(payload)
        out.append(path)
    return out


DECISION_RE = re.compile(r"(?im)^\s*decision:\s*(\w+)")
PLAN_REF_RE = re.compile(r"([0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+)\.plan\.md")
# [hngh <report-id>]: links a reply to a kernel report row (the same
# 8-hex id docs/project/reports.md carries in its third column).
REPORT_REF_RE = re.compile(r"\[hngh ([0-9a-f]{8})\]")
# directive grammar: approve/deny/note lines; anything else is a note
DIRECTIVES = {"approve": "handled", "deny": "dismissed", "note": None}


def annotate_report(report_id, msg, text):
    """Append an operator-reply annotation block to the linked report's
    body sidecar docs/project/report-bodies/<ts>-<kind>-<id>.md; create
    the sidecar when the ledger has the row but the file was pruned.
    Never touches docs/project/reports.md and never deletes anything."""
    root = os.path.join(KERNEL, "docs", "project")
    ledger = os.path.join(root, "reports.md")
    try:
        with open(ledger, encoding="utf-8") as f:
            row = next((ln for ln in f
                        if "| %s |" % report_id in ln), None)
    except OSError:
        row = None
    if row is None:
        return None
    parts = [p.strip() for p in row.strip().strip("|").split("|")]
    if len(parts) < 5:
        return None
    ts, kind = parts[0], parts[1]
    if not re.match(r"^[0-9A-Za-z:.-]+$", ts) or \
            not re.match(r"^[a-z0-9-]+$", kind):
        return None  # malformed row: never guess at a path
    bodies = os.path.join(root, "report-bodies")
    os.makedirs(bodies, exist_ok=True)
    path = os.path.join(bodies, "%s-%s-%s.md" % (ts, kind, report_id))
    try:
        exists = os.path.exists(path)
        with open(path, "a", encoding="utf-8") as f:
            if exists and f.tell() == 0:
                exists = False
            if not exists:
                f.write("# %s — %s\n\n" % (kind, report_id))
            f.write("\n## operator reply\n\n"
                    "- **date:** %s\n"
                    "- **from:** %s\n\n%s\n"
                    % (msg.get("date", ""), msg.get("from", ""), text))
    except OSError:
        return None
    return path


def record_dismissal(item_ids):
    """Persist deny: targets into dashboard/operator-dismissed.json --
    the SAME ledger and schema dashboard-server.py POST
    /operator-item/dismiss writes ({"dismissed": {"<id>": "<UTC ts>"}},
    atomic replace). Existing entries (UI dismissals) are merged, never
    dropped; an unparsable/absent ledger is rebuilt fresh. Fail-closed:
    OSError leaves the prior ledger untouched."""
    if not item_ids:
        return
    path = os.path.join(AUTOMATION, "dashboard", "operator-dismissed.json")
    try:
        with open(path, encoding="utf-8") as f:
            dismissed = json.load(f).get("dismissed") or {}
    except (OSError, ValueError):
        dismissed = {}
    if not isinstance(dismissed, dict):
        dismissed = {}
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for iid in item_ids:
        dismissed[str(iid)] = ts
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"dismissed": dismissed}, f, indent=2)
    os.replace(tmp, path)


def record_approval(item_ids):
    """Persist approve: targets into dashboard/operator-approved.json --
    same schema/atomic-replace pattern as record_dismissal's ledger
    ({"approved": {"<id>": "<UTC ts>"}}). Existing entries are merged,
    never dropped; an unparsable/absent ledger is rebuilt fresh.
    Fail-closed: OSError leaves the prior ledger untouched."""
    if not item_ids:
        return
    path = os.path.join(AUTOMATION, "dashboard", "operator-approved.json")
    try:
        with open(path, encoding="utf-8") as f:
            approved = json.load(f).get("approved") or {}
    except (OSError, ValueError):
        approved = {}
    if not isinstance(approved, dict):
        approved = {}
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for iid in item_ids:
        approved[str(iid)] = ts
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"approved": approved}, f, indent=2)
    os.replace(tmp, path)


def apply_directive(report_id, text):
    """First approve:/deny:/note: line in the reply -> the matching
    open operator-items' status transition (approve -> handled,
    deny -> dismissed, note/default -> annotation only). Matches only
    items whose text/identity references the report id; unknown or
    missing directives default to note. Fail-closed: any error leaves
    the feed byte-identical."""
    feed = os.path.join(AUTOMATION, "dashboard", "operator-items.json")
    try:
        with open(feed, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items")
        if not isinstance(items, list):
            return None
        changed = False
        dismissed_ids = []
        approved_ids = []
        for it in items:
            if not isinstance(it, dict) or it.get("status") != "open":
                continue
            blob = "%s %s" % (it.get("id", ""), it.get("text", ""))
            if report_id not in blob:
                continue
            status = None
            for ln in text.splitlines():
                # grammar: a line beginning approve:/deny:/note: (the
                # colon is part of the grammar; bare words never count)
                dm = re.match(r"\s*(approve|deny|note):", ln)
                if dm:
                    status = DIRECTIVES[dm.group(1)]
                    break
            it["status"] = status or "open"
            if status:
                prev = (it.get("evidence") or "").strip()
                it["evidence"] = (
                    "%s operator reply %s via imap-poll"
                    % (prev, dm.group(1))).strip()
                if status == "dismissed":
                    # durable across feed rebuilds: the 1m rebuild
                    # (jobs/operator-items-feed.py) resets the live
                    # feed from sources, so the emailed decision is
                    # also recorded in the dismissal ledger (the same
                    # ledger the dashboard-server dismiss path owns).
                    dismissed_ids.append(it.get("id", ""))
                elif status == "handled":
                    # same rebuild-clobber durability for approvals:
                    # without this the 1m rebuild resets handled to
                    # open within a minute.
                    approved_ids.append(it.get("id", ""))
            changed = True
        if not changed:
            return None
        tmp = "%s.%d.tmp" % (feed, os.getpid())
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, feed)
        try:
            record_dismissal(dismissed_ids)
            record_approval(approved_ids)
        except OSError:
            pass  # ledgers are best-effort durability, never fatal
        return feed
    except (OSError, ValueError):
        return None


def handle_report_reply(msg, text):
    """Subject carries [hngh <report-id>]: annotate the report sidecar,
    apply the directive grammar to matching operator-items. Returns
    (sidecar path or None). No match -> (None), behavior unchanged."""
    m = REPORT_REF_RE.search(msg.get("subject", ""))
    if not m:
        return None
    report_id = m.group(1)
    return (annotate_report(report_id, msg, text),
            apply_directive(report_id, text))


def plan_decision(msg, text):
    """(slug, decision-word) when the reply carries a decision on a
    named parked plan; else None. Recognizes the kernel plans naming
    convention <date>-<slug>.plan.md."""
    m = DECISION_RE.search(text) or DECISION_RE.search(
        msg.get("subject", ""))
    ref = PLAN_REF_RE.search("%s\n%s" % (msg.get("subject", ""), text))
    if not (m and ref):
        return None
    return ref.group(1), m.group(1).lower()


def file_item(identity, text):
    """File via the existing operator-item contract — copy of
    jobs/feedback-ingest.py file_item (hermetic seams, dormant email
    channel)."""
    env = dict(os.environ)
    env.setdefault("HOME", AUTOMATION)
    env.update({
        "AUTOMATION_ROOT": LIBROOT,  # lib/ lives beside scripts/, never seamed
        "STATE_FILE": os.path.join(AUTOMATION, "STATE.md"),
        "HNGH_REPORT_ROOT": KERNEL,  # the ledger seam
        "HNGH_HOME": KERNEL,         # lib/notify-email.sh KERNEL resolution
        "HNGH_NOTIFY_EMAIL_CONF":
            "/dev/null/notify-email.conf",  # dormant by design
        "JOB_NAME": "imap-poll",
        "ITEM_IDENTITY": identity,
        "ITEM_TEXT": text,
    })
    script = ('. "%s/lib/breadcrumbs.sh"\n'
              '. "%s/lib/notify-email.sh"\n'
              '. "%s/lib/operator-item.sh"\n'
              'operator_item "$ITEM_IDENTITY" "$ITEM_TEXT"\n'
              % (LIBROOT, LIBROOT, LIBROOT))
    return subprocess.run(["bash", "-c", script], env=env,
                          capture_output=True, text=True, timeout=60)


def write_draft(slug, decision, msg, text):
    """Plan-proposal DRAFT under automation/digest/ (the DRAFT-PLAN
    convention: outside the kernel plans feed, so accept-plans never
    sees it; the operator promotes it by hand). Never auto-accepts."""
    ddir = os.path.join(AUTOMATION, DRAFT_SUBDIR)
    os.makedirs(ddir, exist_ok=True)
    path = os.path.join(
        ddir, "DRAFT-PLAN-%s-imap-%s.md"
        % (time.strftime("%Y-%m-%d", time.gmtime()), slug))
    with open(path, "w", encoding="utf-8") as f:
        f.write(
            "# DRAFT plan proposal from operator email reply\n\n"
            "Operator decision `%s` on parked plan %s.plan.md, read from\n"
            "an email reply by imap-poll. DRAFT ONLY: execution machinery\n"
            "does not run this; the operator promotes it by copying it into\n"
            "hngh docs/project/plans/ with a proper front-matter header.\n\n"
            "From: %s\nSubject: %s\nDate: %s\n\n"
            "--- reply excerpt ---\n%s\n"
            % (decision, slug, msg.get("from", ""), msg.get("subject", ""),
               msg.get("date", ""), text[:BODY_CAP]))
    return path


class ImapClient:
    """Thin imaplib wrapper: the only object tests replace. Methods
    deliberately do NOT expose delete/expunge — messages are only ever
    marked \\Seen."""

    def __init__(self, host, port, user, password):
        import imaplib
        self.imap = imaplib.IMAP4_SSL(host, int(port))
        self.imap.login(user, password)

    def unseen(self):
        typ, data = self.imap.select("INBOX", readonly=False)
        if typ != "OK":
            return []
        typ, data = self.imap.search(None, "UNSEEN")
        if typ != "OK" or not data or not data[0]:
            return []
        return data[0].split()

    def fetch(self, num):
        # BODY.PEEK[]: never sets \Seen on fetch (RFC 3501 s6.4.5); the
        # mutating path marks \Seen explicitly via mark_seen.
        typ, data = self.imap.fetch(num, "(BODY.PEEK[])")
        if typ != "OK":
            return None
        for part in data:
            if isinstance(part, tuple) and part[1]:
                return email.message_from_bytes(part[1])
        return None

    def mark_seen(self, num):
        self.imap.store(num, "+FLAGS", "\\Seen")

    def close(self):
        try:
            # CLOSE would expunge \\Deleted messages -- we never set any,
            # so this is a plain deselect; logout never expunges either.
            self.imap.close()
        except Exception:
            pass
        try:
            self.imap.logout()
        except Exception:
            pass


def process_one(client, num, dry=False):
    """One message -> (identity, text) items filed; marks \\Seen on
    success. Returns the item identity or None. Dry-run: parse only."""
    raw = client.fetch(num)
    if raw is None:
        return None
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    msgid = hashlib.sha256((msg.get("message-id") or str(num))
                           .encode("utf-8")).hexdigest()[:8]
    text = body_text(msg)
    if dry:
        return "DRY"
    paths = save_attachments(msg, msgid)
    for p in paths:  # path only in ledgers, never content
        text += "\nattachment: %s" % p
    identity = "imap-reply-%s" % msgid
    r = file_item(identity, "[imap-reply] %s — from %s: %s"
                  % (msg.get("subject", ""), msg.get("from", ""), text))
    if r.returncode != 0:
        sys.stderr.write("imap-poll: file rc=%d for %s: %s\n"
                         % (r.returncode, identity,
                            (r.stderr or "").strip()))
        return None
    hit = plan_decision(msg, text)
    if hit:
        write_draft(hit[0], hit[1], msg, text)
    handle_report_reply(msg, text)  # [hngh <report-id>]: annotate + directives
    client.mark_seen(num)  # processed: read, never deleted
    return identity


def poll(client, dry=False):
    """UNSEEN messages, oldest first, capped per tick. -> processed n."""
    nums = client.unseen()
    if dry:
        for num in nums:
            raw = client.fetch(num)
            if raw is not None:
                m = email.message_from_bytes(raw,
                                             policy=email.policy.default)
                print("unread: %s | %s" % (m.get("from", ""),
                                           m.get("subject", "")))
        print("imap-poll: %d unread message(s) would be processed"
              % len(nums))
        return 0
    n = 0
    for num in nums[:MAX_PER_TICK]:
        if process_one(client, num) is not None:
            n += 1
    if n:
        print("imap-poll: filed %d item(s) (%d unread remaining)"
              % (n, max(len(nums) - n, 0)))
    return n


def main(argv):
    cp, why = load_conf()
    if cp is None:
        noop(why)
        return 0  # fail closed: dormant channel is a normal state
    pw = resolve_password(cp)
    if not pw:
        noop("no IMAP password available (1password/pass_cmd/smtp pass)")
        return 0
    try:
        client = ImapClient(cp.get("imap", "host"), cp.get("imap", "port"),
                            cp.get("imap", "user"), pw)
    except Exception as exc:
        noop("imap login failed: %s" % str(exc).replace("\n", " "))
        return 0
    try:
        poll(client, dry="--dry-run" in argv)
    except Exception as exc:
        noop("imap poll failed: %s" % str(exc).replace("\n", " "))
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
