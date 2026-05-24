#!/bin/bash
set -eu

if [[ -z "${CLAMBHOOK_BIN:-}" ]]; then
    echo "CLAMBHOOK_BIN is not set; skipping clambhook compatibility test."
    exit 77
fi

if [[ ! -x "$CLAMBHOOK_BIN" ]]; then
    echo "CLAMBHOOK_BIN is not executable: $CLAMBHOOK_BIN"
    exit 77
fi

CLAMBHOOK_BIN_ABS="$(cd "$(dirname "$CLAMBHOOK_BIN")" && pwd)/$(basename "$CLAMBHOOK_BIN")"

source "$(dirname "$0")/../LinuxSmokeTest/common.sh"

cd "$TMPDIR"

cleanup() {
    for pid in ${PID_HOOK:-} ${PID_BACK:-} ${PID_HTTP:-}; do
        if [[ -n "$pid" ]]; then
            kill "$pid" >/dev/null 2>&1 || true
        fi
    done
}
trap cleanup EXIT

wait_port_or_die() {
    local port="$1"
    local name="$2"
    for _ in $(seq 1 50); do
        if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    echo "$name did not listen on 127.0.0.1:$port"
    echo "--- clambback.log ---"
    tail -50 clambback.log 2>/dev/null || true
    echo "--- clambhook.log ---"
    tail -50 clambhook.log 2>/dev/null || true
    exit 1
}

openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes -subj /CN=localhost >/dev/null 2>&1

mkdir target
echo clambback-through-clambhook > target/whoami.txt
python3 -m http.server 10091 --directory target > http.log 2>&1 &
PID_HTTP="$!"

cat > server.json <<'JSON'
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 10453,
    "remote_addr": "127.0.0.1",
    "remote_port": 9,
    "password": ["clambhook-compat-password"],
    "log_level": 0,
    "ssl": {
        "cert": "cert.pem",
        "key": "key.pem",
        "key_password": "",
        "cipher": "",
        "cipher_tls13": "",
        "prefer_server_cipher": true,
        "alpn": [],
        "alpn_port_override": {},
        "reuse_session": false,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "",
        "server_port": 0,
        "database": "",
        "username": "",
        "password": "",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
JSON

cat > clambhook.toml <<'TOML'
active = "compat"

[traffic]
enabled = false

[[profile]]
name = "compat"

  [profile.listen]
  socks5 = "127.0.0.1:11093"

  [[profile.chain]]
  name = "clambback"

    [[profile.chain.server]]
    name = "clambback-local"
    address = "127.0.0.1:10453"
    protocol = "clambback"

      [profile.chain.server.settings]
      password = "clambhook-compat-password"
      sni = "localhost"
      skip_cert_verify = true
TOML

./clambback -t server.json
./clambback server.json -l clambback.log &
PID_BACK="$!"

"$CLAMBHOOK_BIN_ABS" -config clambhook.toml -api 127.0.0.1:19093 -no-watch > clambhook.log 2>&1 &
PID_HOOK="$!"

wait_port_or_die 10091 "http target"
wait_port_or_die 10453 "clambback"
wait_port_or_die 11093 "clambhook socks5"

WHOAMI=$(curl --fail --silent --show-error --socks5 127.0.0.1:11093 http://127.0.0.1:10091/whoami.txt)
if [[ "$WHOAMI" != "clambback-through-clambhook" ]]; then
    echo "unexpected TCP response: $WHOAMI"
    exit 1
fi

python3 - <<'PY'
import socket
import struct
import threading

echo = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
echo.bind(("127.0.0.1", 10093))
stopped = False

def serve():
    while not stopped:
        try:
            data, addr = echo.recvfrom(4096)
        except OSError:
            return
        echo.sendto(data, addr)

threading.Thread(target=serve, daemon=True).start()

ctrl = socket.create_connection(("127.0.0.1", 11093), timeout=5)
ctrl.settimeout(5)
ctrl.sendall(b"\x05\x01\x00")
if ctrl.recv(2) != b"\x05\x00":
    raise SystemExit("bad SOCKS5 greeting")
ctrl.sendall(b"\x05\x03\x00\x01\x00\x00\x00\x00\x00\x00")
reply = ctrl.recv(10)
if len(reply) != 10 or reply[1] != 0:
    raise SystemExit(f"bad UDP ASSOCIATE reply: {reply.hex()}")

relay_port = struct.unpack("!H", reply[8:10])[0]
udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp.bind(("127.0.0.1", 0))
udp.settimeout(5)
payload = b"clambback-udp-through-clambhook"
frame = b"\x00\x00\x00\x01" + socket.inet_aton("127.0.0.1") + struct.pack("!H", 10093) + payload
udp.sendto(frame, ("127.0.0.1", relay_port))
received, _ = udp.recvfrom(4096)
idx = 4 + 4 + 2
if received[:3] != b"\x00\x00\x00" or received[3] != 1:
    raise SystemExit(f"bad UDP response header: {received.hex()}")
if received[idx:] != payload:
    raise SystemExit(f"payload mismatch: {received[idx:]!r}")

print(received[idx:].decode())
stopped = True
echo.close()
ctrl.close()
udp.close()
PY
