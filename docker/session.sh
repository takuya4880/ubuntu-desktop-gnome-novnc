#!/bin/bash
set -euo pipefail
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME-Flashback:GNOME
export DESKTOP_SESSION=gnome-flashback-metacity
export XDG_MENU_PREFIX=gnome-flashback-
export LIBGL_ALWAYS_SOFTWARE=1
if [[ ${1:-} != --dbus ]]; then
    exec dbus-run-session -- "$0" --dbus
fi

# GNOME 50's session manager requires systemd. Start the Flashback
# components directly to keep this container independent of systemd.
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
pids=()
cleanup() {
    kill "${pids[@]}" 2>/dev/null || true
    wait || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
metacity --replace &
pids+=("$!")
gnome-flashback &
pids+=("$!")
/usr/libexec/gsd-xsettings &
pids+=("$!")
gnome-panel &
pids+=("$!")
wait -n "${pids[@]}"
exit 1
