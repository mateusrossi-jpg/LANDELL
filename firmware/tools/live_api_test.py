#!/usr/bin/env python3
"""
ENDAP firmware — live API test suite (non-destructive).

Runs against a real controller on the LAN. Every write test snapshots the
original state first and restores it afterwards. Endpoints that reboot,
wipe, crash, change Wi-Fi or revoke nodes are NEVER called.

Usage:  python3 tools/live_api_test.py [IP]        (default 192.168.0.27)
Exit code 0 = all PASS, 1 = at least one FAIL.
"""
import concurrent.futures as cf
import json
import socket
import statistics
import sys
import time
import urllib.error
import urllib.request

IP = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.27"
BASE = f"http://{IP}"
TIMEOUT = 6

# Never invoked by this suite (destructive / connectivity-breaking).
FORBIDDEN = {
    "/api/reboot", "/api/system/factory-reset", "/api/chaos/crash",
    "/api/chaos/inject_delay", "/api/onboarding/reset", "/api/input/reset",
    "/api/output/reset", "/api/automation/clear", "/api/nodes/revoke",
    "/api/wifi", "/api/wifi/scan", "/api/onboarding/wifi/confirm",
    "/api/network/ethernet/ip", "/api/recovery",
}

results = []  # (section, name, ok, detail)


def req(method, path, body=None, headers=None, timeout=TIMEOUT):
    assert path.split("?")[0] not in FORBIDDEN, f"forbidden endpoint {path}"
    data = None
    h = dict(headers or {})
    if body is not None:
        data = body if isinstance(body, (bytes, bytearray)) else json.dumps(body).encode()
        h.setdefault("Content-Type", "application/json")
    r = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            raw = resp.read()
            return resp.status, raw, (time.perf_counter() - t0) * 1000, dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), (time.perf_counter() - t0) * 1000, dict(e.headers or {})


def jget(path):
    code, raw, ms, _ = req("GET", path)
    try:
        return code, json.loads(raw.decode(errors="replace")), ms
    except Exception:
        return code, None, ms


def check(section, name, ok, detail=""):
    results.append((section, name, bool(ok), str(detail)))
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {name}" + (f"  — {detail}" if detail else ""))
    return ok


# ---------------------------------------------------------------- sections
def t_read_endpoints():
    print("\n## 1. Endpoints de leitura (status, JSON válido, latência)")
    endpoints = [
        "/api/auth/status", "/api/status", "/api/public/status", "/api/io/map",
        "/api/pve", "/api/pve/alarms/history", "/api/profile", "/api/hardware/gpios",
        "/api/failsafe", "/api/failsafe/status", "/api/failsafe/outputs",
        "/api/installation/channel-map", "/api/resources", "/api/nodes",
        "/api/network/metrics", "/api/onboarding/status", "/api/wifi/status",
        "/api/kernel/load", "/api/sensors/config", "/api/automation",
        "/api/cluster/status", "/api/i2c/scan",
    ]
    for p in endpoints:
        code, data, ms = jget(p)
        check("read", f"GET {p}", code == 200 and data is not None,
              f"HTTP {code}, {ms:.0f} ms" + ("" if data is not None else ", JSON inválido"))


def t_static_and_captive():
    print("\n## 2. Dashboard embarcado e portal cativo")
    code, raw, ms, h = req("GET", "/")
    check("static", "GET / serve dashboard HTML", code == 200 and b"<html" in raw[:4096].lower(),
          f"HTTP {code}, {len(raw)} bytes, {ms:.0f} ms")
    for p in ["/favicon.ico", "/bag"]:
        code, _, _, _ = req("GET", p)
        check("static", f"GET {p} sem conteúdo", code in (200, 204), f"HTTP {code}")
    for p in ["/generate_204", "/hotspot-detect.html", "/ncsi.txt", "/connecttest.txt", "/fwlink"]:
        r = urllib.request.Request(BASE + p, method="GET")
        opener = urllib.request.build_opener(NoRedirect)
        try:
            resp = opener.open(r, timeout=TIMEOUT)
            code = resp.status
        except urllib.error.HTTPError as e:
            code = e.code
        check("static", f"GET {p} captive redirect", code in (200, 302, 303, 307), f"HTTP {code}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


def t_io_consistency():
    print("\n## 3. Consistência do mapa de I/O entre endpoints")
    _, iomap, _ = jget("/api/io/map")
    _, pub, _ = jget("/api/public/status")
    ins = {i["channel_id"]: i for i in iomap.get("inputs", [])}
    outs = {o["channel_id"]: o for o in iomap.get("outputs", [])}
    check("io", "io/map tem entradas I0.0..I0.4 (10..14)", all(c in ins for c in range(10, 15)),
          f"ids={sorted(ins)}")
    check("io", "io/map tem saídas Q0.0..Q0.4 (100..104)", all(c in outs for c in range(100, 105)),
          f"ids={sorted(outs)}")
    expected_gpio = {10: 16, 11: 17, 12: 19, 13: 18, 14: 27}
    bad = {c: ins[c].get("gpio") for c in expected_gpio if ins.get(c, {}).get("gpio") != expected_gpio[c]}
    check("io", "Pinagem das entradas = projeto do Studio", not bad, f"divergências={bad}" if bad else "16/17/19/18/27")
    expected_out = {100: 23, 101: 4, 102: 32, 103: 14, 104: 33}
    bad = {c: outs[c].get("gpio") for c in expected_out if outs.get(c, {}).get("gpio") != expected_out[c]}
    check("io", "Pinagem das saídas = projeto do Studio", not bad, f"divergências={bad}" if bad else "23/4/32/14/33")
    pub_in = {i["id"]: i["value"] for i in pub.get("inputs", [])}
    mism = {c: (ins[c].get("state"), pub_in.get(c)) for c in range(10, 15)
            if c in pub_in and ins[c].get("state") != pub_in.get(c)}
    check("io", "Estado das entradas: io/map == public/status", not mism, str(mism) if mism else "coerente")
    for c, o in outs.items():
        if "desired" in o and "reported" in o and o["desired"] != o["reported"]:
            check("io", f"Saída {c}: desired == reported (readback físico)", False,
                  f"desired={o['desired']} reported={o['reported']}")
            break
    else:
        check("io", "Saídas: desired == reported (readback físico GPIO)", True)


def t_pve():
    print("\n## 4. Variáveis de processo (PVE) e sensores")
    _, pve, _ = jget("/api/pve")
    vs = pve.get("variables", []) if pve else []
    check("pve", "PVE expõe variáveis", len(vs) > 0, f"{len(vs)} variáveis: {[v.get('name') for v in vs]}")
    for v in vs:
        lo, hi = v.get("scaled_min"), v.get("scaled_max")
        sv = v.get("scaled_value", v.get("scaled"))
        name = v.get("name")
        if None not in (lo, hi, sv) and v.get("source") == "ADC_NATIVE":
            check("pve", f"{name}: valor escalonado dentro da faixa", min(lo, hi) <= sv <= max(lo, hi),
                  f"{sv} em [{lo},{hi}]")
        if "cal_gain" in v:
            check("pve", f"{name}: cal_gain válido (>0)", v["cal_gain"] > 0, f"gain={v['cal_gain']}")
    temps = [v for v in vs if "TEMP" in str(v.get("name"))]
    for v in temps:
        t = v.get("scaled_value", 0) / (10 ** v.get("decimals", 1))
        check("pve", f"{v['name']}: temperatura plausível (-20..80 °C)", -20 <= t <= 80, f"{t:.1f} °C")
    hums = [v for v in vs if "HUM" in str(v.get("name"))]
    for v in hums:
        hh = v.get("scaled_value", 0) / (10 ** v.get("decimals", 1))
        check("pve", f"{v['name']}: umidade plausível (0..100 %)", 0 <= hh <= 100, f"{hh:.1f} %")
    code, i2c, _ = jget("/api/i2c/scan")
    if i2c is not None:
        devs = json.dumps(i2c)
        check("pve", "I2C scan encontra AHT10 (0x38)", "0x38" in devs.lower() or "56" in devs, devs[:120])


def t_ladder():
    print("\n## 5. Motor Ladder (programa carregado no CLP)")
    code, raw, ms, h = req("GET", "/api/automation/ladder")
    check("ladder", "GET programa ladder carregado", code == 200 and len(raw) > 0,
          f"HTTP {code}, {len(raw)} bytes de bytecode")
    if code == 200 and raw:
        global LADDER_BACKUP
        LADDER_BACKUP = raw
    code, raw, _, _ = req("OPTIONS", "/api/automation/ladder")
    check("ladder", "OPTIONS (CORS preflight) ladder", code in (200, 204), f"HTTP {code}")


LADDER_BACKUP = None


def t_ladder_redeploy():
    print("\n## 6. Redeploy idempotente do bytecode ladder (backup -> POST -> verifica)")
    if not LADDER_BACKUP:
        check("ladder", "Redeploy", False, "sem backup do programa")
        return
    code, raw, _, _ = req("POST", "/api/automation/ladder", body=LADDER_BACKUP,
                          headers={"Content-Type": "application/octet-stream"})
    check("ladder", "POST mesmo bytecode é aceito", code == 200, f"HTTP {code} {raw[:80]!r}")
    time.sleep(0.5)
    code, raw2, _, _ = req("GET", "/api/automation/ladder")
    check("ladder", "Bytecode lido == bytecode gravado (byte a byte)", raw2 == LADDER_BACKUP,
          f"{len(raw2)} vs {len(LADDER_BACKUP)} bytes")
    code, raw, _, _ = req("POST", "/api/automation/ladder", body=b"\xff\x00garbage-bytecode\x13\x37",
                          headers={"Content-Type": "application/octet-stream"})
    rejected = code >= 400
    check("ladder", "Bytecode corrompido é rejeitado (4xx)", rejected, f"HTTP {code} {raw[:80]!r}")
    # always restore, whatever happened above
    code, _, _, _ = req("POST", "/api/automation/ladder", body=LADDER_BACKUP,
                        headers={"Content-Type": "application/octet-stream"})
    code2, raw3, _, _ = req("GET", "/api/automation/ladder")
    check("ladder", "Programa original restaurado", code == 200 and raw3 == LADDER_BACKUP,
          f"HTTP {code}")


def _out_state(cid):
    _, m, _ = jget("/api/io/map")
    for o in m.get("outputs", []):
        if o["channel_id"] == cid:
            return o
    return {}


def t_manual_output():
    print("\n## 7. Atuação manual de saída física (Q0.4 / GPIO33, livre no ladder)")
    cid = 104
    before = _out_state(cid)
    orig = before.get("desired", before.get("state", 0)) or 0
    ok_all = True
    for val in (1, 0, 1):
        code, raw, ms, _ = req("GET", f"/api/set?id={cid}&value={val}")
        time.sleep(0.6)
        st = _out_state(cid)
        rep = st.get("reported", st.get("state"))
        ok = code == 200 and rep == val
        ok_all &= ok
        check("io", f"/api/set Q0.4 = {val} → readback GPIO = {rep}", ok, f"HTTP {code}, {ms:.0f} ms")
    code, _, _, _ = req("GET", f"/api/set?id={cid}&value={orig}")
    time.sleep(0.4)
    st = _out_state(cid)
    check("io", f"Q0.4 restaurada ao estado original ({orig})", st.get("reported", st.get("state")) == orig)
    code, raw, _, _ = req("GET", "/api/set?id=9999&value=1")
    check("io", "/api/set com id inexistente é rejeitado", code >= 400, f"HTTP {code} {raw[:60]!r}")
    code, raw, _, _ = req("GET", "/api/set")
    check("io", "/api/set sem parâmetros é rejeitado", code >= 400, f"HTTP {code} {raw[:60]!r}")


def t_calibration_roundtrip():
    print("\n## 8. Calibração universal: gravar → ler → restaurar (NVS)")
    _, pve, _ = jget("/api/pve")
    vs = pve.get("variables", [])
    target = next((v for v in vs if "cal_offset" in v), None) or (vs[0] if vs else None)
    if not target:
        check("cal", "Variável para calibrar", False, "nenhuma")
        return
    vid = target["id"]
    off0 = target.get("cal_offset", 0)
    gain0 = target.get("cal_gain", 1000)
    code, raw, _, _ = req("POST", "/api/pve/calibrate", body={"id": vid, "offset": off0 + 7, "gain": gain0})
    check("cal", f"POST calibrate id={vid} offset+7", code == 200 and b'"ok":true' in raw, f"HTTP {code} {raw[:60]!r}")
    time.sleep(0.5)
    _, pve2, _ = jget("/api/pve")
    v2 = next((v for v in pve2["variables"] if v["id"] == vid), {})
    check("cal", "Offset persistido e refletido em /api/pve", v2.get("cal_offset") == off0 + 7,
          f"cal_offset={v2.get('cal_offset')} (esperado {off0 + 7})")
    code, raw, _, _ = req("POST", "/api/pve/calibrate", body={"id": vid, "offset": off0, "gain": gain0})
    _, pve3, _ = jget("/api/pve")
    v3 = next((v for v in pve3["variables"] if v["id"] == vid), {})
    check("cal", "Calibração original restaurada", v3.get("cal_offset") == off0 and v3.get("cal_gain", gain0) == gain0,
          f"offset={v3.get('cal_offset')} gain={v3.get('cal_gain')}")
    # negative validation
    for body, label in [({}, "sem id"), ({"id": 999}, "id inválido"),
                        ({"id": vid, "input_min": 5, "input_max": 5}, "input_min == input_max"),
                        ({"id": vid, "name": "X" * 80}, "nome longo demais")]:
        code, raw, _, _ = req("POST", "/api/pve/config", body=body)
        check("cal", f"Validação rejeita {label}", code == 400, f"HTTP {code} {raw[:60]!r}")
    _, pve4, _ = jget("/api/pve")
    v4 = next((v for v in pve4["variables"] if v["id"] == vid), {})
    same = all(v4.get(k) == target.get(k) for k in ("name", "input_min", "input_max", "scaled_min", "scaled_max"))
    check("cal", "Requisições inválidas não alteraram a configuração", same)


def t_malformed():
    print("\n## 9. Robustez a entradas malformadas")
    cases = [
        ("POST", "/api/pve/config", b"{not json", "JSON quebrado"),
        ("POST", "/api/pve/config", b"", "corpo vazio"),
        ("POST", "/api/pve/config", b"A" * 6000, "corpo gigante (6 KB)"),
        ("GET", "/api/set?id=abc&value=xyz", None, "parâmetros não numéricos"),
        ("GET", "/api/set?id=104&value=" + "9" * 40, None, "valor overflow"),
        ("GET", "/api/does-not-exist", None, "rota inexistente"),
    ]
    for m, p, b, label in cases:
        try:
            code, raw, ms, _ = req(m, p, body=b, headers={"Content-Type": "application/json"} if b is not None else None)
            check("robust", f"{label} → resposta controlada", 400 <= code < 500, f"HTTP {code}")
        except Exception as e:
            check("robust", f"{label} → resposta controlada", False, f"exceção {e}")
    alive, _, _ = jget("/api/public/status")
    check("robust", "Controlador continua respondendo após entradas malformadas", alive == 200)
    # restore Q0.4 just in case the overflow case was accepted
    req("GET", "/api/set?id=104&value=0")


def t_websocket():
    print("\n## 10. WebSocket /ws (handshake RFC 6455)")
    try:
        s = socket.create_connection((IP, 80), timeout=TIMEOUT)
        s.sendall((f"GET /ws HTTP/1.1\r\nHost: {IP}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                   "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        resp = s.recv(1024).decode(errors="replace")
        s.close()
        ok = "101" in resp.split("\r\n")[0] and "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" in resp
        check("ws", "Upgrade 101 + Sec-WebSocket-Accept correto", ok, resp.split("\r\n")[0])
    except Exception as e:
        check("ws", "Upgrade 101", False, str(e))


def t_performance():
    print("\n## 11. Desempenho e estabilidade sob carga")
    lat = []
    errors = 0
    for _ in range(60):
        try:
            code, _, ms, _ = req("GET", "/api/io/map")
            lat.append(ms)
            errors += code != 200
        except Exception:
            errors += 1
    p50 = statistics.median(lat) if lat else 0
    p95 = sorted(lat)[int(len(lat) * 0.95) - 1] if lat else 0
    check("perf", "60 polls sequenciais de /api/io/map sem erro", errors == 0, f"erros={errors}")
    check("perf", "Latência p95 < 250 ms (Studio faz polling a cada 500 ms)", p95 < 250,
          f"p50={p50:.0f} ms, p95={p95:.0f} ms, max={max(lat):.0f} ms")

    def hit(p):
        try:
            return req("GET", p, timeout=10)[0]
        except Exception as e:
            return str(e)[:40]
    paths = ["/api/io/map", "/api/pve", "/api/public/status", "/api/status"] * 6
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        codes = list(ex.map(hit, paths))
    ok = sum(1 for c in codes if c == 200)
    check("perf", "24 requisições concorrentes (6 clientes: Studio+IHM+celular)", ok == len(codes),
          f"{ok}/{len(codes)} OK, falhas={[c for c in codes if c != 200][:4]}")
    time.sleep(1)
    code, _, _ = jget("/api/public/status")
    check("perf", "Controlador saudável após rajada", code == 200)


def t_security_audit():
    print("\n## 12. Auditoria de segurança (somente observação, sem ações destrutivas)")
    _, st, _ = jget("/api/auth/status")
    configured = st.get("configured") if st else None
    authed = st.get("authenticated") if st else None
    # A guarded write that requires MANUAL_IO, called anonymously. Uses the free Q0.4 with its
    # current value, so even if accepted it changes nothing physically.
    cur = _out_state(104).get("desired", 0) or 0
    code, raw, _, _ = req("GET", f"/api/set?id=104&value={cur}")
    check("security", "Escrita anônima em /api/set é bloqueada (401/403)", code in (401, 403),
          f"HTTP {code} — auth configurada={configured}, sessão={authed}")
    code, raw, _, _ = req("POST", "/api/pve/config", body={"id": 999})
    check("security", "Escrita anônima em /api/pve/config é bloqueada (401/403)", code in (401, 403),
          f"HTTP {code}")
    code, raw, _, h = req("GET", "/api/auth/users")
    leaked = code == 200 and raw[:1] in (b"{", b"[")
    check("security", "Lista de usuários não é exposta anonimamente", not leaked, f"HTTP {code} {raw[:60]!r}")


def main():
    print(f"ENDAP live API test — alvo {BASE}")
    code, _, ms = jget("/api/public/status")
    if code != 200:
        print(f"Controlador inacessível (HTTP {code}).")
        sys.exit(2)
    for fn in (t_read_endpoints, t_static_and_captive, t_io_consistency, t_pve, t_ladder,
               t_ladder_redeploy, t_manual_output, t_calibration_roundtrip, t_malformed,
               t_websocket, t_performance, t_security_audit):
        try:
            fn()
        except Exception as e:
            check(fn.__name__, "seção abortou com exceção", False, repr(e)[:160])
    total = len(results)
    fails = [r for r in results if not r[2]]
    print(f"\n==== RESULTADO: {total - len(fails)}/{total} PASS, {len(fails)} FAIL ====")
    for s, n, _, d in fails:
        print(f"  FAIL [{s}] {n} — {d}")
    json.dump([dict(section=s, name=n, ok=o, detail=d) for s, n, o, d in results],
              open("/tmp/endap_live_api_results.json", "w"), ensure_ascii=False, indent=1)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
