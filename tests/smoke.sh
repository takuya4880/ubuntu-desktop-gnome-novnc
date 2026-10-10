#!/bin/bash
set -euo pipefail
image=${1:-desktop:test}
cd "$(dirname "$0")"
run_case() (
    mode=$1
    password_dir=$(mktemp -d)
    trap 'rm -rf "$password_dir"' EXIT
    args=()
    expected=password
    case "$mode" in
        password-file)
            printf '%s' testpass > "$password_dir/password"
            chmod 644 "$password_dir/password"
            args=(-e VNC_PASSWORD_FILE=/run/secrets/vnc_password
                --mount "type=bind,source=$password_dir/password,target=/run/secrets/vnc_password,readonly")
            ;;
        password-env) args=(-e VNC_PASSWORD=testpass) ;;
        none) expected=none ;;
    esac
    echo "Testing $mode"
    container=$(docker run -d "${args[@]}" --shm-size=1g "$image")
    trap 'docker logs "$container"; docker rm -f "$container" >/dev/null; rm -rf "$password_dir"' EXIT
    for attempt in {1..90}; do
        if docker exec "$container" bash -c 'curl -fsS http://localhost:6080/vnc.html >/dev/null && pgrep -x gnome-panel >/dev/null && pgrep -x metacity >/dev/null' 2>/dev/null; then
            break
        fi
        sleep 2
    done
    docker exec "$container" bash -c 'curl -fsS http://localhost:6080/vnc.html >/dev/null && pgrep -x gnome-panel && pgrep -x metacity && xdpyinfo -display :1 >/dev/null'
    docker exec -i "$container" python3 - "$expected" < rfb.py
    docker exec -d "$container" env GDK_BACKEND=x11 GSK_RENDERER=cairo dbus-run-session -- gnome-calculator
    for attempt in {1..30}; do
        if docker exec "$container" xwininfo -name Calculator 2>/dev/null | grep -q 'Map State: IsViewable'; then
            break
        fi
        sleep 1
    done
    docker exec "$container" xwininfo -name Calculator | grep 'Map State: IsViewable'
    docker stop -t 10 "$container" >/dev/null
)
for mode in password-file password-env none; do
    run_case "$mode"
done
