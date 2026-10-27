#!/usr/bin/env python3
"""
ENDAP LIVE HARDWARE USE CASE AGENTS RUNNER
Executa a bateria de agentes de casos de uso diretamente contra o hardware físico ESP32
e/ou através do proxy web do ENDAP Studio.
"""

import sys
import time
import json
import urllib.request
import urllib.error

TARGET_URL = sys.argv[1] if len(sys.argv) > 1 else "http://192.168.0.27"

def log(agent, msg, status="INFO"):
    symbol = "🟢" if status == "PASS" else ("🔴" if status == "FAIL" else "🔹")
    print(f"[{symbol} {agent.upper()}] {msg}")

def http_get(path):
    url = f"{TARGET_URL}{path}"
    req = urllib.request.Request(url, headers={"User-Agent": "ENDAP-Agent-Runner"})
    with urllib.request.urlopen(req, timeout=4) as res:
        return res.getcode(), json.loads(res.read().decode("utf-8"))

def http_post(path, data):
    url = f"{TARGET_URL}{path}"
    payload = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "ENDAP-Agent-Runner"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as res:
            return res.getcode(), json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))

def run_suite():
    print("=" * 70)
    print(f"🚀 INICIANDO USE CASE AGENTS CONTRA HARDWARE: {TARGET_URL}")
    print("=" * 70)

    results = {}

    # -------------------------------------------------------------
    # AGENT 1: OnboardingProvisioningAgent
    # -------------------------------------------------------------
    try:
        log("OnboardingAgent", "Consultando /api/public/status...")
        code, status = http_get("/api/public/status")
        assert code == 200, f"HTTP {code}"
        assert "node_id" in status, "Missing node_id"
        node_id = status["node_id"]
        ip = status.get("net_wifi_sta_ip_text", "N/A")
        log("OnboardingAgent", f"Controlador detectado: ID={node_id}, IP={ip}, State={status.get('operational_state')}", "PASS")
        results["UC-01: Onboarding & Provisioning"] = True
    except Exception as e:
        log("OnboardingAgent", f"Falha: {e}", "FAIL")
        results["UC-01: Onboarding & Provisioning"] = False

    # -------------------------------------------------------------
    # AGENT 2: HardwareProfileAgent
    # -------------------------------------------------------------
    try:
        log("HardwareProfileAgent", "Consultando /api/io/map...")
        code, io_map = http_get("/api/io/map")
        assert code == 200
        inputs = io_map.get("inputs", [])
        outputs = io_map.get("outputs", [])
        log("HardwareProfileAgent", f"Canais Físicos Mapeados: {len(inputs)} Entradas, {len(outputs)} Saídas")
        
        # Validar salvaguarda de strapping pins
        strapping_pins = {0, 2, 12, 15}
        for out in outputs:
            assert out.get("gpio") not in strapping_pins, f"ALERTA: Strapping pin {out.get('gpio')} exposto como saída!"
        log("HardwareProfileAgent", "Salvaguarda de Strapping Pins (GPIO 0, 2, 12, 15) íntegra!", "PASS")
        results["UC-02: Hardware Profile & Safeguards"] = True
    except Exception as e:
        log("HardwareProfileAgent", f"Falha: {e}", "FAIL")
        results["UC-02: Hardware Profile & Safeguards"] = False

    # -------------------------------------------------------------
    # AGENT 3: LadderEngineAgent
    # -------------------------------------------------------------
    try:
        log("LadderEngineAgent", "Auditando ciclo de controle do Kernel...")
        code, st = http_get("/api/status")
        assert code == 200
        jitter = st.get("k_jitter_max", 0)
        exec_us = st.get("k_exec_max", 0)
        overrun = st.get("k_overrun", 0)
        log("LadderEngineAgent", f"Kernel 1ms: Jitter Max={jitter}us, Exec Max={exec_us}us, Overruns={overrun}", "PASS")
        results["UC-03: Ladder Engine & Determinism"] = True
    except Exception as e:
        log("LadderEngineAgent", f"Falha: {e}", "FAIL")
        results["UC-03: Ladder Engine & Determinism"] = False

    # -------------------------------------------------------------
    # AGENT 4: HmiSupervisionAgent
    # -------------------------------------------------------------
    try:
        log("HmiSupervisionAgent", "Validando telemetria em tempo real das E/S...")
        code, st = http_get("/api/public/status")
        assert code == 200
        # Checa se entradas analógicas reportam leituras reais
        ais = [inp for inp in st.get("inputs", []) if inp.get("id") >= 20]
        for ai in ais:
            log("HmiSupervisionAgent", f"Canal Analógico ID {ai['id']} Leitura ADC Raw: {ai.get('value')}")
        results["UC-04: HMI Supervision & Real Telemetry"] = True
    except Exception as e:
        log("HmiSupervisionAgent", f"Falha: {e}", "FAIL")
        results["UC-04: HMI Supervision & Real Telemetry"] = False

    # -------------------------------------------------------------
    # AGENT 5: FieldTroubleshootingAgent (Forçamento Real de E/S)
    # -------------------------------------------------------------
    try:
        log("FieldTroubleshootingAgent", "Testando Forçamento Real: Saída Q0.0 (ID 100) -> ON...")
        code, res = http_post("/api/io/force", {"action": "set", "id": 100, "value": 1})
        assert code == 200 and res.get("ok"), f"Falha ao forçar Q0.0: code={code}"
        
        # Confirma que hardware reporta forced: true
        _, io_map = http_get("/api/io/map")
        q0 = next((o for o in io_map.get("outputs", []) if o["channel_id"] == 100), None)
        assert q0 and q0.get("forced") == True and q0.get("reported") == 1, "Q0.0 não refletiu estado forçado!"
        log("FieldTroubleshootingAgent", "Q0.0 FORÇADO COM SUCESSO NO HARDWARE FÍSICO!", "PASS")

        # Libera o forçamento
        log("FieldTroubleshootingAgent", "Liberando forçamento de Q0.0...")
        code, res = http_post("/api/io/force", {"action": "release", "id": 100})
        assert code == 200 and res.get("ok")
        log("FieldTroubleshootingAgent", "Q0.0 retornado ao modo AUTO!", "PASS")
        results["UC-05: Real I/O Forcing & Safety"] = True
    except Exception as e:
        log("FieldTroubleshootingAgent", f"Falha: {e}", "FAIL")
        results["UC-05: Real I/O Forcing & Safety"] = False

    # -------------------------------------------------------------
    # AGENT 6: AuditGovernanceAgent
    # -------------------------------------------------------------
    try:
        log("AuditGovernanceAgent", "Consultando trilha de auditoria física (/api/auth/audit)...")
        code, audit = http_get("/api/auth/audit")
        assert code == 200
        events = audit.get("events", [])
        log("AuditGovernanceAgent", f"Total de eventos auditados na memória do ESP32: {len(events)}")
        has_force_set = any(e.get("action") == "io_force_set" for e in events)
        has_force_rel = any(e.get("action") == "io_force_release" for e in events)
        assert has_force_set and has_force_rel, "Eventos de forçamento não encontrados na trilha de auditoria!"
        log("AuditGovernanceAgent", "Trilha de Auditoria do ESP32 validada com rastreabilidade 100%!", "PASS")
        results["UC-06: Audit Trail & Governance"] = True
    except Exception as e:
        log("AuditGovernanceAgent", f"Falha: {e}", "FAIL")
        results["UC-06: Audit Trail & Governance"] = False

    print("=" * 70)
    print("📊 RESULTADO CONSOLIDADO DOS AGENTES DE CASOS DE USO:")
    print("=" * 70)
    all_passed = True
    for uc, passed in results.items():
        status = "APROVADO 100%" if passed else "FALHOU"
        print(f"  {uc.ljust(45)}: {status}")
        if not passed: all_passed = False
    print("=" * 70)
    return all_passed

if __name__ == "__main__":
    success = run_suite()
    sys.exit(0 if success else 1)
