# /etc/skel/.zprofile — land a tty1 autologin in the omarchy graphical
# session (uwsm). Other TTYs, ssh and non-login shells keep a plain console;
# in-session terminals come from foot. Lands for every useradd -m user:
# the live-env liveuser account and the installed system's tier user
# (the tty1 autologin drop-in points at the tier user there, at liveuser
# in the live env).
if [ "$(tty)" = /dev/tty1 ] && command -v uwsm >/dev/null 2>&1; then
  exec uwsm start hyprland
fi
