#!/usr/bin/env python3
"""
LANDELL Software-in-the-Loop (SIL) HTTP PLC Server.

Expõe a API HTTP oficial do controlador LANDELL em localhost acoplada diretamente
ao binário C real do firmware (`build/ladder_vm_cli` -> `ladder_engine.c` + `ladder_pid.c` + `state.c`).
Permite executar `landell_bench_test.py` e `live_esp32_hardware_test.dart` ponta-a-ponta
sobre HTTP real mesmo quando a placa física ESP32 está desligada.
"""

import json
import os
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CLI_BIN = os.path.join(SCRIPT_DIR, "build", "ladder_vm_cli")


class RealCLadderBridge:
    def __init__(self, cli_path: str):
        self._lock = threading.Lock()
        self._proc = subprocess.Popen(
            [cli_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self._bytecode = b""
        self._boot_ts = time.monotonic()
        # Inicializa AI0.0 bruto/escalado realista (ex: 2450 raw -> ~58.7%)
        self._cmd_unlocked("SET 22 2450")
        self._cmd_unlocked("SET 72 59")

    def _cmd_unlocked(self, line: str) -> str:
        assert self._proc.stdin and self._proc.stdout
        self._proc.stdin.write(line + "\n")
        self._proc.stdin.flush()
        return self._proc.stdout.readline().strip()

    def load_bytecode(self, raw: bytes) -> bool:
        with self._lock:
            resp = self._cmd_unlocked("LOAD " + raw.hex())
            if resp.startswith("OK LOAD"):
                self._bytecode = raw
                self._cmd_unlocked("STEP 1")
                return True
            return False

    def get_bytecode(self) -> bytes:
        with self._lock:
            return self._bytecode

    def set_state(self, ch_id: int, val: int) -> None:
        with self._lock:
            self._cmd_unlocked(f"SET {ch_id} {val}")
            if self._bytecode:
                self._cmd_unlocked("ADVANCE 10")
                self._cmd_unlocked("STEP 1")

    def snapshot(self) -> dict[int, int]:
        ids = list(range(10, 16)) + [22, 26, 27, 40, 56, 72, 80] + list(range(100, 106))
        with self._lock:
            if self._bytecode:
                self._cmd_unlocked("ADVANCE 5")
                self._cmd_unlocked("STEP 1")
            resp = self._cmd_unlocked("QUERY " + " ".join(str(i) for i in ids))
        out: dict[int, int] = {}
        if resp.startswith("STATE"):
            for tok in resp.split()[1:]:
                k, v = tok.split("=")
                out[int(k)] = int(v)
        return out

    def uptime_ms(self) -> int:
        return int((time.monotonic() - self._boot_ts) * 1000)

    def close(self) -> None:
        with self._lock:
            try:
                self._cmd_unlocked("QUIT")
            except Exception:
                pass
            self._proc.terminate()


BRIDGE: RealCLadderBridge | None = None
DI_GPIOS = [16, 17, 18, 19, 27, 13]
DO_GPIOS = [4, 21, 22, 33, 23, 32]


class SilPlcHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # Mantém saída limpa nos testes

    def _send_json(self, code: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        assert BRIDGE is not None
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if path in ("/api/status", "/api/public/status"):
            st = BRIDGE.snapshot()
            inputs = [
                {"channel_id": 10 + i, "plc_code": f"I0.{i}", "name": f"I0.{i}", "gpio": DI_GPIOS[i], "value": st.get(10 + i, 0)}
                for i in range(6)
            ]
            outputs = [
                {"channel_id": 100 + i, "plc_code": f"Q0.{i}", "name": f"Q0.{i}", "gpio": DO_GPIOS[i], "reported": st.get(100 + i, 0), "value": st.get(100 + i, 0)}
                for i in range(6)
            ]
            self._send_json(200, {
                "device": "LANDELL-SIL-HOST",
                "mode": "sil_c_vm",
                "operational_state": "running",
                "uptime_ms": BRIDGE.uptime_ms(),
                "k_exec_max": 18,
                "k_jitter_max": 4,
                "ladder_active": len(BRIDGE.get_bytecode()) > 0,
                "inputs": inputs,
                "outputs": outputs,
            })
        elif path == "/api/io/map":
            st = BRIDGE.snapshot()
            self._send_json(200, {
                "inputs": [
                    {"channel_id": 10 + i, "plc_code": f"I0.{i}", "gpio": DI_GPIOS[i], "state": st.get(10 + i, 0)}
                    for i in range(6)
                ],
                "outputs": [
                    {"channel_id": 100 + i, "plc_code": f"Q0.{i}", "gpio": DO_GPIOS[i], "reported": st.get(100 + i, 0)}
                    for i in range(6)
                ],
            })
        elif path == "/api/pve":
            st = BRIDGE.snapshot()
            self._send_json(200, {
                "variables": [
                    {"id": 0, "name": "AIN1", "raw": st.get(22, 2450), "scaled": st.get(72, 59), "unit": "%"},
                ]
            })
        elif path == "/api/wifi/scan":
            self._send_json(200, {
                "count": 1,
                "networks": [{"ssid": "LANDELL_BENCH_SIL", "rssi": -48, "auth": "WPA2"}],
            })
        elif path == "/api/system/ota/status":
            self._send_json(200, {
                "running_partition": "ota_0",
                "running_version": "v3.2-sil",
                "next_partition": "ota_1",
            })
        elif path == "/api/set":
            ch_id = int(qs.get("id", ["0"])[0])
            val = int(qs.get("value", ["0"])[0])
            BRIDGE.set_state(ch_id, val)
            st = BRIDGE.snapshot()
            self._send_json(200, {"ok": True, "id": ch_id, "value": st.get(ch_id, val)})
        elif path in ("/api/automation/ladder", "/api/ladder/bytecode"):
            bc = BRIDGE.get_bytecode()
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(bc)))
            self.end_headers()
            self.wfile.write(bc)
        else:
            self._send_json(404, {"error": "not_found", "path": path})

    def do_POST(self):
        assert BRIDGE is not None
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length > 0 else b""

        if self.path == "/api/automation/ladder":
            if BRIDGE.load_bytecode(body):
                self._send_json(200, {"ok": True, "size": len(body), "engine": "c_ladder_engine"})
            else:
                self._send_json(400, {"ok": False, "error": "invalid_bytecode"})
        else:
            self._send_json(404, {"error": "not_found"})


def main():
    global BRIDGE
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18089
    if not os.path.exists(CLI_BIN):
        subprocess.run(["make", "-s", "all"], cwd=SCRIPT_DIR, check=True)
    BRIDGE = RealCLadderBridge(CLI_BIN)
    srv = ThreadingHTTPServer(("127.0.0.1", port), SilPlcHandler)
    print(f"SIL_PLC_READY http://127.0.0.1:{port}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
        BRIDGE.close()


if __name__ == "__main__":
    main()
