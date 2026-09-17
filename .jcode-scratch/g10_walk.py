#!/usr/bin/env python3
"""g10: reconcile guard checked-count 121 (HEAD=129da833) vs 130 (HEAD=52380f4a).

Read-only: only git reads, all writes to this scratch dir.
Replicates tests/scripts/test-loop-history-guard.py main() walk semantics:
  - range RESTATEMENT(1915713)..HEAD
  - skip subtree-squash subjects
  - touches_code via `git diff --name-only <parent|EMPTY_TREE> <sha>` over CODE_SURFACE prefixes
"""
import ast
import re
import subprocess

REPO = "~/Projects/etc/hngh"
RESTATEMENT = "1915713"
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
CODE_SURFACE = ("src/", "tests/", "scripts/", "Makefile", "hngh.asd")
SQUASH = re.compile(r"^Squashed '.*' content from commit [0-9a-f]+$")
CAND = re.compile(r"^hngh: candidate [0-9a-f]{64}$")
EXEMPT_LABEL = "excluded from cert manifest by dependency guard"

A3_HEAD = "129da83355aa07d96975276718f0f87ad044c412"  # 2026-09-16 15:36:18 -0400
NOW_HEAD = "52380f4a8df765aa97298d57eac4bc841004302a"  # 2026-09-17 08:04:07 -0400


def run(args, **kw):
    return subprocess.run(["git"] + args, capture_output=True, text=True,
                          check=True, cwd=REPO, **kw).stdout


def run_config(args, cfg):
    return subprocess.run(["git"] + cfg + args, capture_output=True, text=True,
                          check=True, cwd=REPO).stdout


# ---- extract committed exemption table from the HEAD blob ----
blob = run(["show", f"{NOW_HEAD}:tests/scripts/test-loop-history-guard.py"])
m = re.search(r"KNOWN_EXEMPTIONS = (\{.*?\n\})", blob, re.S)
TABLE = ast.literal_eval(m.group(1))
REGISTERED_PIDS = {e["patch-id"] for e in TABLE.values()}
print(f"table: {len(TABLE)} keys, {len(REGISTERED_PIDS)} unique patch-ids")
key_lens = {}
for k in TABLE:
    key_lens.setdefault(len(k), []).append(k)
print("key length histogram:", {n: len(v) for n, v in sorted(key_lens.items())})


def code_files(H):
    parents = run(["rev-list", "--parents", "-n", "1", H]).split()
    base = parents[1] if len(parents) > 1 else EMPTY_TREE
    files = run(["diff", "--name-only", base, H]).splitlines()
    return [p for p in files if any(p.startswith(x) for x in CODE_SURFACE)]


def walk(head):
    res = []
    out = run(["log", "--format=%H%x09%h%x09%ci%x09%s", f"{RESTATEMENT}..{head}"])
    for line in out.splitlines():
        if not line:
            continue
        H, h, ci, subject = line.split("\t", 3)
        if SQUASH.match(subject):
            continue
        code = code_files(H)
        if code:
            res.append({"H": H, "h": h, "ci": ci, "subject": subject, "code": code})
    return res


def pid_of(H, cfg=(), full_index=True):
    args = ["diff-tree", "-p"] + (["--full-index"] if full_index else []) + ["--root", H]
    diff = run_config(args, list(cfg))
    out = subprocess.run(["git"] + list(cfg) + ["patch-id", "--stable"], input=diff,
                         capture_output=True, text=True, check=True, cwd=REPO).stdout
    parts = out.split()
    return parts[0] if parts else ""


print("\n=== A. walk replication at both HEADs ===")
a = walk(A3_HEAD)
b = walk(NOW_HEAD)
Ha = {r["H"] for r in a}
Hb = {r["H"] for r in b}
print(f"checked@129da833 = {len(a)}   checked@52380f4a = {len(b)}")
print(f"set diff sizes: only-in-now={len(Hb - Ha)} only-in-a3={len(Ha - Hb)}")

print("\n=== B. delta commits (commit-dated arithmetic) ===")
delta = sorted((r for r in b if r["H"] not in Ha), key=lambda r: r["ci"])
print(f"delta count = {len(delta)}  ->  arithmetic: {len(a)} + {len(delta)} = {len(a)+len(delta)}")
for r in delta:
    print(f"{r['ci']}  {r['h']}  {r['subject'][:72]}  [{r['code'][0]}]")

print("\n=== C. exemption match path at NOW_HEAD ===")
hist = {}
exempt_rows = []
for r in b:
    if CAND.match(r["subject"]):
        hist["candidate"] = hist.get("candidate", 0) + 1
    elif r["h"] in TABLE:
        hist["hash-match"] = hist.get("hash-match", 0) + 1
        exempt_rows.append((r, "hash"))
    elif EXEMPT_LABEL in r["subject"]:
        hist["labeled-exempt"] = hist.get("labeled-exempt", 0) + 1
        exempt_rows.append((r, "label"))
    else:
        p = pid_of(r["H"])
        if p in REGISTERED_PIDS:
            hist["patch-id-match"] = hist.get("patch-id-match", 0) + 1
            exempt_rows.append((r, "pid"))
        else:
            hist("VIOLATION")
            exempt_rows.append((r, "VIOLATION"))
print("classification histogram:", hist)
print("total:", sum(hist.values()))
for r, how in exempt_rows:
    print(f"  {how:5s} {r['ci'][:10]} {r['h']} keylen={len(r['h'])} {r['subject'][:56]}")

print("\n=== D. %h emission on THIS repo (default config) ===")
cfgq = subprocess.run(["git", "config", "--show-origin", "--get-all", "core.abbrev"],
                      capture_output=True, text=True, cwd=REPO)
print(f"core.abbrev configured: {'NO (unset in all scopes)' if cfgq.returncode != 0 else cfgq.stdout.strip()}")
lens = {}
sample = {}
out = run(["log", "--format=%h", f"{RESTATEMENT}..{NOW_HEAD}"])
for h in out.splitlines():
    lens[len(h)] = lens.get(len(h), 0) + 1
    sample.setdefault(len(h), h)
print(f"%h length histogram over RESTATEMENT..HEAD ({len(out.splitlines())} commits): {lens} sample={sample}")
print("per-key %h at default config (full-sha -> emitted abbreviation):")
for k in TABLE:
    full = run(["rev-parse", k]).strip()
    h = run(["log", "-1", "--format=%h", full]).strip()
    fires = "HASH-MATCH" if k == h else "pid-fallback"
    print(f"  key={k}({len(k)})  %h={h}({len(h)})  {fires}")

print("\n=== E. abbrev-config dependence ===")
for cfgname in ("-c", "core.abbrev=7"), ("-c", "core.abbrev=12"):
    h7 = run_config(["log", "-1", "--format=%h", "e6e98f75db5d6aa128a8bdcdd664644ad4b86e9d"], list(cfgname)).strip()
    h915 = run_config(["log", "-1", "--format=%h", run(["rev-parse", "915e0e3"]).strip()], list(cfgname)).strip()
    print(f"  [{' '.join(cfgname)}] %h(e6e98f75..)={h7}  %h(915e0e3..)={h915}")
p_def = pid_of("526cd3f")
p_7 = pid_of("526cd3f", ["-c", "core.abbrev=7"])
p_12 = pid_of("526cd3f", ["-c", "core.abbrev=12"])
p_leg7 = pid_of("526cd3f", ["-c", "core.abbrev=7"], full_index=False)
p_leg12 = pid_of("526cd3f", ["-c", "core.abbrev=12"], full_index=False)
print(f"  hermetic pid(526cd3f) default={p_def[:12]} abbrev7={p_7[:12]} abbrev12={p_12[:12]} stable={p_def==p_7==p_12}")
print(f"  legacy  pid(526cd3f) abbrev7={p_leg7[:12]} abbrev12={p_leg12[:12]} drifts={p_leg7!=p_leg12}")
nobj = run(["count-objects", "-v"])
inc = [l for l in nobj.splitlines() if l.startswith(("in-pack", "count"))]
print(f"  object counts: {inc}  (auto-abbrev = int(log2(count)/2)+1, min 7)")

print("\n=== F. guard-walk vs plain pathspec count at NOW_HEAD ===")
ps = set(run(["log", "--format=%H", f"{RESTATEMENT}..{NOW_HEAD}", "--"] + list(CODE_SURFACE)).splitlines())
only_guard = Hb - ps
only_ps = ps - Hb
print(f"pathspec={len(ps)}  guard-walk={len(Hb)}  only-in-guard={len(only_guard)}  only-in-pathspec={len(only_ps)}")
for H in sorted(only_guard):
    line = run(["log", "-1", "--format=%ci %h %s || parents=%P", H]).strip()
    print(f"  GUARD-ONLY: {line[:120]}")
for H in sorted(only_ps):
    line = run(["log", "-1", "--format=%ci %h %s || parents=%P", H]).strip()
    print(f"  PS-ONLY:    {line[:120]}")

print("\n=== G. guard script blob identity across the two HEADs ===")
d = subprocess.run(["git", "diff", "--stat", A3_HEAD, NOW_HEAD, "--",
                    "tests/scripts/test-loop-history-guard.py"],
                   capture_output=True, text=True, cwd=REPO)
print("committed-blob diff 129da833..52380f4a for the guard:",
      "IDENTICAL" if not d.stdout.strip() else d.stdout.strip())
log_guard = run(["log", "--oneline", f"{A3_HEAD}..{NOW_HEAD}", "--",
                 "tests/scripts/test-loop-history-guard.py"]).strip()
print("commits touching guard in range:", log_guard if log_guard else "(none)")
wt = subprocess.run(["git", "diff", "--stat", "--", "tests/scripts/test-loop-history-guard.py"],
                    capture_output=True, text=True, cwd=REPO)
print("working-tree vs HEAD guard diff stat:", wt.stdout.strip() or "(clean)")
