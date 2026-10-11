"""Check the RFB authentication policy through the actual noVNC bridge."""
import base64
import os
import socket
import struct
import sys

expected = sys.argv[1]
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
buffer = bytearray()


def read(n):
    while len(buffer) < n:
        first, second = exact(2)
        assert first & 15 == 2, 'Expected binary WebSocket frame'
        assert not second & 128, 'Server frames must be unmasked'
        length = second & 127
        if length == 126:
            length = struct.unpack('!H', exact(2))[0]
        elif length == 127:
            length = struct.unpack('!Q', exact(8))[0]
        buffer.extend(exact(length))
    result = bytes(buffer[:n])
    del buffer[:n]
    return result


def send(data):
    assert len(data) < 126
    mask = os.urandom(4)
    payload = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    s.sendall(bytes((0x82, 0x80 | len(data))) + mask + payload)


assert read(12) == b'RFB 003.008\n'
send(b'RFB 003.008\n')
count = read(1)[0]
assert count > 0, 'Server rejected protocol negotiation'
security = set(read(count))
if expected == 'password':
    assert security == {2}, f'Expected VncAuth only, got {security}'
    send(b'\x02')
    assert len(read(16)) == 16, 'Missing VNC password challenge'
    print('WebSocket/RFB: password authentication required')
else:
    assert expected == 'none'
    assert security == {1}, f'Expected None only, got {security}'
    send(b'\x01')
    assert read(4) == bytes(4), 'Unauthenticated connection rejected'
    send(b'\x01')  # Shared ClientInit.
    server = read(24)
    width, height = struct.unpack('!HH', server[:4])
    assert (width, height) == (1920, 1080), (width, height)
    name_length = struct.unpack('!I', server[20:24])[0]
    assert read(name_length), 'Missing desktop name'
    print('WebSocket/RFB: connected without a password, desktop 1920x1080')
s.close()
