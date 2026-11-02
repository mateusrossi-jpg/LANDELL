#!/usr/bin/env python3
"""
LANDELL Live Monitor Daemon.
Monitora em segundo plano a integridade, telemetria, determinismo do kernel (1ms scan),
I/O físico e latência HTTP do CLP LANDELL durante a execução dos testes e intervenções.
"""

import sys
import time
import json
import urllib.request
import urllib.error

IP = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "192.168.4.1"
LOG_FILE = "/home/mateus/dev/github/LANDELL/firmware/tools/landell_monitor.log"
BASE_URL = f"http://{IP}"

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{ts}] {msg}"
    print(formatted, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(formatted + "\n")
    except Exception:
        pass

def main():
    log(f"=== LANDELL Live Monitor Daemon Iniciado em {BASE_URL} ===")
    prev_outputs = {}
    prev_inputs = {}
    last_uptime = 0
    poll_count = 0

    while True:
        poll_count += 1
        t0 = time.perf_counter()
        try:
            req = urllib.request.Request(f"{BASE_URL}/api/status", headers={"User-Agent": "LandellMonitor/1.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = resp.read().decode("utf-8", errors="replace")
                dt_ms = (time.perf_counter() - t0) * 1000
                status = json.loads(data)

                uptime = status.get("uptime_ms", 0)
                state = status.get("operational_state", "unknown")
                jitter = status.get("k_jitter_max", 0)
                exec_us = status.get("k_exec_max", 0)
                misses = status.get("k_deadline_miss", 0)
                overruns = status.get("k_overrun", 0)

                # Monitora mudanças em I/O
                current_outputs = {o.get("name", str(o.get("id"))): (o.get("reported", o.get("state", 0))) for o in status.get("outputs", [])}
                current_inputs = {i.get("name", str(i.get("id"))): (i.get("state", i.get("value", 0))) for i in status.get("inputs", [])}

                if prev_outputs:
                    for name, val in current_outputs.items():
                        if prev_outputs.get(name) != val:
                            log(f"⚡ [SAÍDA DETECTADA] {name} mudou para {val}")

                if prev_inputs:
                    for name, val in current_inputs.items():
                        if prev_inputs.get(name) != val:
                            log(f"⚡ [ENTRADA DETECTADA] {name} mudou para {val}")

                prev_outputs = current_outputs
                prev_inputs = current_inputs

                if poll_count % 10 == 0:
                    log(f"💚 [OK] Latência: {dt_ms:.1f}ms | Uptime: {uptime/1000.0:.0f}s | Estado: {state} | Scan Exec: {exec_us}µs | Jitter: {jitter}µs | Misses: {misses} | Overruns: {overruns}")

        except Exception as e:
            if poll_count % 5 == 0:
                log(f"⚠ [OFFLINE/BUSY] CLP não respondeu: {e}")

        time.sleep(1.0)

if __name__ == "__main__":
    main()
