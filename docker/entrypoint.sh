#!/bin/bash
set -euo pipefail
umask 077
if [[ ! ${DESKTOP_RESOLUTION} =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]]; then
    echo 'DESKTOP_RESOLUTION must be WIDTHxHEIGHT' >&2
    exit 1
fi
password=${VNC_PASSWORD:-}
if [[ -n ${VNC_PASSWORD_FILE:-} ]]; then
    password=$(cat "$VNC_PASSWORD_FILE")
fi
if (( ${#password} < 6 || ${#password} > 8 )); then
    echo 'Set VNC_PASSWORD or VNC_PASSWORD_FILE to a 6–8 character password (VNC uses only 8 characters).' >&2
    exit 1
fi
export XDG_RUNTIME_DIR=/tmp/runtime-desktop
mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.config/tigervnc"
chmod 700 "$XDG_RUNTIME_DIR"
printf '%s\n' "$password" | tigervncpasswd -f > "$HOME/.config/tigervnc/passwd"
unset password VNC_PASSWORD
cleanup() {
    kill "${web_pid:-}" "${session_pid:-}" "${vnc_pid:-}" 2>/dev/null || true
    wait || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
Xtigervnc :1 -geometry "$DESKTOP_RESOLUTION" -depth 24 -localhost yes \
    -nolisten tcp \
    -SecurityTypes VncAuth -PasswordFile "$HOME/.config/tigervnc/passwd" \
    -AlwaysShared -rfbport 5901 &
vnc_pid=$!
for attempt in {1..60}; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then break; fi
    kill -0 "$vnc_pid"
    sleep 0.5
done
xdpyinfo -display :1 >/dev/null
/usr/local/bin/desktop-session &
session_pid=$!
websockify --web=/usr/share/novnc 6080 localhost:5901 &
web_pid=$!
wait -n "$vnc_pid" "$session_pid" "$web_pid"
exit 1
