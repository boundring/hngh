#!/usr/bin/env bash
# test-omarchy-readiness.sh -- hermetic proofs for the omarchy phase-1
# readiness beat (31-omarchy-readiness.sh, 2026-09-27):
#   a) all-yes -> one progress row, phase1 summary with every flag yes.
#   b) clone missing -> a=no b=yes(...).
#   c) manifest empty file -> b=no(0).
#   d) hyprland absent (stub rc=1) -> c=no, no pending alert.
#   e) desktop present (c=yes d=yes) -> no alert.
#   f) c=yes d=no -> alert omarchy-ready:phase1-pending naming file.
#   g) pins-drift module absent -> e=unknown.
#   h) pins-drift ok:false -> e=drift.
#   i) rerun same day -> no duplicate progress row (identity dedupe).
#   j) manifest only comments -> b=no(0), beat exits 0.
# Hermetic: sandbox repo copy, stub pacman, stub pins-drift, no real
# telemetry, no writes outside mktemp roots.
set -u
umask 022
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
home="$(mktemp -d)"
pass=0 fail=0
trap 'rm -rf "$sb" "$home"' EXIT

mkdir -p "$sb/lib" "$sb/kernel/scripts" "$sb/report-root" \
 "$sb/hnghhome/db" "$sb/config" "$sb/jobs" "$sb/cadence/calendar/daily" \
 "$sb/stubbin" "$sb/sessions"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
cp "$root/cadence/calendar/daily/31-omarchy-readiness.sh" \
 "$sb/cadence/calendar/daily/"

# pacman stub: rc from PACMAN_RC (default 0 = hyprland installed)
cat >"$sb/stubbin/pacman" <<'EOF'
#!/usr/bin/env bash
exit "${PACMAN_RC:-0}"
EOF
chmod +x "$sb/stubbin/pacman"

clone="$home/Projects/etc/omarchy-upstream"

seed_clone() { [ "$1" = yes ] && mkdir -p "$clone/.git" || rm -rf "$clone"; }
seed_manifest() { # text ("" deletes)
 if [ -n "$1" ]; then
  printf '%s\n' "$1" >"$sb/config/omarchy-base.packages"
 else rm -f "$sb/config/omarchy-base.packages"; fi
}
seed_pins() { # code|none
 if [ "$1" = none ]; then
  rm -f "$sb/jobs/pins-drift.py"
 else printf '#!/usr/bin/env python3\nimport json\nprint(json.dumps(%s))\n' \
  "$2" >"$sb/jobs/pins-drift.py"; fi
}
seed_desktop() { [ "$1" = yes ] && printf '[Desktop Entry]\n' \
 >"$sb/sessions/hyprland.desktop" || rm -f "$sb/sessions/"*.desktop 2>/dev/null; }
set_all_yes() {
 seed_clone yes
 seed_manifest 'linux-cachyos
hyprland'
 seed_pins code "{'ok': True}"
 seed_desktop yes
}
seed_all_yes() { PACMAN_RC=0 set_all_yes; }

bodies() { ls "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
count_body() { grep -rl "$1" "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
reset_docs() { rm -rf "$sb/report-root/docs"; }

run() { # extra env via env command
 (
  export PATH="$sb/stubbin:$PATH"
  export HOME="$home" HNGH_HOME_DIR="$sb/hnghhome" \
   HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
   OMARCHY_UPSTREAM_DIR="$clone" OMARCHY_SESSIONS_DIR="$sb/sessions" \
   PACMAN_RC="${PACMAN_RC:-0}"
  bash "$sb/cadence/calendar/daily/31-omarchy-readiness.sh" >/dev/null 2>&1
 )
}

ok() { pass=$((pass + 1)); }
bad() {
 fail=$((fail + 1))
 echo "FAIL: $1"
}
chk() { if [ "$2" = "$3" ]; then ok; else bad "$1 (got '$2' want '$3')"; fi; }

day="$(date -u +%Y-%m-%d)"
ready_row="omarchy-readiness:$day"
alert_row="omarchy-ready:phase1-pending"

# --- a) all-yes -> one progress row, phase1 summary ------------------------
rm -rf "$sb/report-root/docs"
seed_all_yes
rc=0
run || rc=$?
chk "a: rc 0" "$rc" "0"
chk "a: one progress row" "$(count_body "$ready_row")" "1"
chk "a: all flags yes" "$(count_body 'phase1 a=yes b=yes(2) c=yes d=yes e=ok')" "1"
chk "a: no alert when d=yes" "$(count_body "$alert_row")" "0"

# --- b) clone missing -> a=no, b flag kept ---------------------------------
rm -rf "$clone"
reset_docs
run
chk "b: a=no" "$(count_body 'phase1 a=no b=yes(2)')" "1"

# --- c) manifest empty file -> b=no(0) --------------------------------------
: >"$sb/config/omarchy-base.packages"
seed_clone yes
reset_docs
run
chk "c: empty manifest b=no(0)" "$(count_body 'a=yes b=no(0) c=yes')" "1"

# --- d) hyprland absent -> c=no, no alert -----------------------------------
seed_manifest 'linux-cachyos'
reset_docs
PACMAN_RC=1 run
chk "d: c=no" "$(count_body 'b=yes(1) c=no')" "1"
chk "d: no alert (c=no)" "$(count_body "$alert_row")" "0"

# --- e) desktop present again (c=yes d=yes) -> no alert ---------------------
reset_docs
PACMAN_RC=0 run
chk "e: no alert restored" "$(count_body "$alert_row")" "0"

# --- f) c=yes d=no -> pending alert naming the file --------------------------
seed_desktop no
reset_docs
run
chk "f: progress still filed" "$(count_body 'c=yes d=no')" "1"
chk "f: alert filed" "$(count_body "$alert_row")" "1"
chk "f: alert names session file" \
 "$(count_body 'missing .*sessions/hyprland\.desktop')" "1"

# --- g) pins-drift module absent -> e=unknown -------------------------------
seed_pins none
reset_docs
run
chk "g: e=unknown" "$(count_body 'd=no e=unknown')" "1"

# --- h) pins-drift ok:false -> e=drift ---------------------------------------
seed_pins code "{'ok': False}"
reset_docs
run
chk "h: e=drift" "$(count_body 'e=drift')" "1"

# --- i) rerun same day -> no duplicate progress row --------------------------
n_before="$(count_body "$ready_row")"
run
chk "i: dedupe holds on rerun" "$(count_body "$ready_row")" "$n_before"

# --- j) manifest only comments -> b=no(0), rc 0 ------------------------------
seed_manifest '# a comment
# another'
rm -rf "$sb/report-root/docs"
rc=0
run || rc=$?
chk "j: rc 0 past comment-only manifest" "$rc" "0"
chk "j: b=no(0)" "$(count_body 'b=no(0)')" "1"

echo "test-omarchy-readiness: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
