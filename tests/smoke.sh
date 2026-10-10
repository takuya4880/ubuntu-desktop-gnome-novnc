#!/bin/bash
set -euo pipefail
image=${1:-desktop:test}
password_dir=$(mktemp -d)
trap 'rm -rf "$password_dir"' EXIT
printf '%s' testpass > "$password_dir/password"
chmod 644 "$password_dir/password"
container=$(docker run -d -e VNC_PASSWORD_FILE=/run/secrets/vnc_password \
    --mount "type=bind,source=$password_dir/password,target=/run/secrets/vnc_password,readonly" \
    --shm-size=1g "$image")
trap 'docker logs "$container"; docker rm -f "$container" >/dev/null; rm -rf "$password_dir"' EXIT
for attempt in {1..90}; do
    if docker exec "$container" bash -c 'curl -fsS http://localhost:6080/vnc.html >/dev/null && pgrep -x gnome-panel >/dev/null && pgrep -x metacity >/dev/null' 2>/dev/null; then
        break
    fi
    sleep 2
done
docker exec "$container" bash -c 'curl -fsS http://localhost:6080/vnc.html >/dev/null && pgrep -x gnome-panel && pgrep -x metacity && xdpyinfo -display :1 >/dev/null'
# Exercise noVNC's actual WebSocket bridge and the RFB server greeting.
docker exec -i "$container" python3 - <<'PY'
import base64, os, socket, struct
s = socket.create_connection(('127.0.0.1', 6080), timeout=10)
key = base64.b64encode(os.urandom(16)).decode()
s.sendall((f'GET /websockify HTTP/1.1\r\nHost: localhost:6080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: binary\r\n\r\n').encode())
def exact(n):
    data = b''
    while len(data) < n:
        part = s.recv(n - len(data))
        assert part, 'Unexpected disconnect'
        data += part
    return data
header = b''
while not header.endswith(b'\r\n\r\n'):
    header += exact(1)
assert b'101 Switching Protocols' in header, header
first, second = exact(2)
assert first & 15 == 2, 'Expected binary WebSocket frame'
length = second & 127
if length == 126: length = struct.unpack('!H', exact(2))[0]
elif length == 127: length = struct.unpack('!Q', exact(8))[0]
assert exact(length).startswith(b'RFB 003.'), 'Missing VNC greeting'
print('noVNC WebSocket → TigerVNC RFB greeting verified')
PY
docker exec -d "$container" env GDK_BACKEND=x11 GSK_RENDERER=cairo dbus-run-session -- gnome-calculator
for attempt in {1..30}; do
    if docker exec "$container" xwininfo -name Calculator 2>/dev/null | grep -q 'Map State: IsViewable'; then
        break
    fi
    sleep 1
done
docker exec "$container" xwininfo -name Calculator | grep 'Map State: IsViewable'
docker stop -t 10 "$container" >/dev/null
