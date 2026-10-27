#!/usr/bin/env python3
import subprocess
import os

OUTPUT_DIRS = [
    "/home/mateus/dev/github/endap-firmware/docs/assets",
    "/home/mateus/dev/github/endap-studio/assets",
    "/home/mateus/.gemini/antigravity-cli/brain/5d5966f2-3d8f-4ed3-9f29-c423104eb460/assets"
]

for d in OUTPUT_DIRS:
    os.makedirs(d, exist_ok=True)

# -------------------------------------------------------------------------
# 1. SOFTWARE ARCHITECTURE DOT
# (ESP32 Controller + Push-Buttons DI + Capacitive Humidity Sensor AI + Relays DO + ATX PSU)
# -------------------------------------------------------------------------
SOFTWARE_DOT = """digraph ENDAP_Software_Architecture_Bancada {
    graph [
        rankdir=TB,
        dpi=300,
        bgcolor="#ffffff",
        fontname="Helvetica,Arial,sans-serif",
        fontsize=14,
        compound=true,
        nodesep=0.42,
        ranksep=0.58,
        pad=0.35,
        label="ENDAP — Arquitetura de Software e Fluxo de Execução (Ciclo Determinístico 1 ms + Supervisão Web)\\n",
        labelloc="t"
    ];
    node [
        fontname="Helvetica,Arial,sans-serif",
        fontsize=10.5,
        shape=box,
        style="filled,rounded",
        penwidth=1.5,
        margin="0.20,0.14"
    ];
    edge [
        fontname="Helvetica,Arial,sans-serif",
        fontsize=9.5,
        color="#475569",
        penwidth=1.3,
        arrowsize=0.85
    ];

    // 1. Personas Cluster
    subgraph cluster_personas {
        label="1. Atores e Modos de Interação na Bancada do TCC";
        style="filled,rounded";
        fillcolor="#f8fafc";
        color="#94a3b8";
        fontcolor="#0f172a";
        fontsize=12.5;

        eng [label="Engenheiro / Apresentador\\n• Edita Lógica Ladder IEC 61131-3 (NO/NC, TON, CMP, PID)\\n• Compila para Bytecode Binário (24 B Header + 16 B/Instr)\\n• Faz Hot-Swap sem Reiniciar o Controlador", fillcolor="#e0f2fe", color="#0284c7", fontcolor="#0369a1"];
        op  [label="Operador / Banca Avaliadora\\n• Aciona Botões de Pulso Físicos (DI: Partida / Parada / Reset)\\n• Submerge Sensor Capacitivo na Água (0% -> 100%)\\n• Acompanha Telemetria e Comanda Relés via Smartphone", fillcolor="#e0f2fe", color="#0284c7", fontcolor="#0369a1"];
    }

    // 2. UI Layer
    subgraph cluster_ui {
        label="2. Camada de Engenharia e Supervisão (ENDAP Studio & IHM Web)";
        style="filled,rounded";
        fillcolor="#faf5ff";
        color="#c084fc";
        fontcolor="#581c87";
        fontsize=12.5;

        studio [label="ENDAP Studio (Flutter Desktop / Web)\\n• Editor Ladder Visual + Compilador Bytecode (CRC16-CCITT)\\n• Matriz de Pinos e Tags (I0.0..I0.5, Q0.0..Q0.7, AI0.0..AI0.3, AO0.0..AO0.1)\\n• Power-Flow em Tempo Real e Telemetria Unificada (250 ms)", fillcolor="#f3e8ff", color="#9333ea", fontcolor="#6b21a8"];
        dash   [label="IHM Web Embarcada (/dash & /api/pve)\\n• Servida Diretamente da Flash do ESP32\\n• Indicadores de Entradas Digitais (Botões), Umidade (%) e Relés\\n• Forçamento Manual de Saídas e Diagnóstico de Saúde do Kernel", fillcolor="#f3e8ff", color="#9333ea", fontcolor="#6b21a8"];
    }

    // Wi-Fi Connection Link
    wifi_link [label="Barramento Sem Fio Wi-Fi 802.11 b/g/n (2.4 GHz)\\nDescoberta Prioritária (Gateway IP / endap.local / SoftAP)\\nTransporte HTTP REST JSON + Deploy de Bytecode Binário", shape=hexagon, fillcolor="#fef3c7", color="#d97706", fontcolor="#92400e", penwidth=2.0];

    // 3. ESP32 Hybrid Gateway
    subgraph cluster_esp32 {
        label="3. ENDAP Controller — Firmware ESP32 Dual-Core (ESP-IDF 5.5 + FreeRTOS)";
        style="filled,rounded";
        fillcolor="#f0fdf4";
        color="#16a34a";
        fontcolor="#14532d";
        fontsize=12.5;

        // Core 0: Async Services
        subgraph cluster_core0 {
            label="Core 0 — Serviços Assíncronos de Rede, Persistência e Supervisão";
            style="dashed,rounded";
            fillcolor="#eef2ff";
            color="#6366f1";
            fontcolor="#312e81";

            http_srv [label="Servidor HTTP REST (http_server.c)\\n• /api/telemetry, /api/pve, /api/io/map\\n• /api/plc/bytecode (Hot-Reload Ladder)\\n• /api/gpio/write (Forçamento de Relés)", fillcolor="#e0e7ff", color="#4f46e5", fontcolor="#312e81"];
            pve_eng  [label="Process Variable Engine (pve.c)\\n• Escalonamento Calibrado (3800..1500 -> 0.0..100.0%)\\n• Alarmes LOLO / LO / HI / HIHI com Histerese\\n• Persistência de Calibração em NVS", fillcolor="#e0e7ff", color="#4f46e5", fontcolor="#312e81"];
            nvs_mgr  [label="Persistência NVS Flash\\n• Salva Programa Bytecode Ladder\\n• Salva Perfil de Pinos (device_profile.c)", fillcolor="#e0e7ff", color="#4f46e5", fontcolor="#312e81"];
        }

        // Core 1: Deterministic Kernel 1ms
        subgraph cluster_core1 {
            label="Core 1 — Kernel Determinístico de Tempo Real (GPTimer Hardware ISR @ 1.000 µs)";
            style="dashed,rounded";
            fillcolor="#dcfce7";
            color="#16a34a";
            fontcolor="#14532d";

            gptimer [label="GPTimer 1 kHz (ISR IRAM)\\nDisparo Determinístico a Cada 1 ms", fillcolor="#bbf7d0", color="#15803d", fontcolor="#14532d", shape=ellipse];

            subgraph cluster_scan {
                label="Ciclo de Varredura de Controle (control_loop.c — Sem Bloqueios)";
                style="filled,rounded";
                fillcolor="#ffffff";
                color="#86efac";

                p1 [label="Fase 1: IO Scan (io_driver.c)\\n• Leitura Botões DI (Debounce 8 ms)\\n• Amostragem ADC1 (Sensor Umidade)\\n• Conversão Linear 0..100% (AI0.0)", fillcolor="#dcfce7", color="#16a34a"];
                p2 [label="Fase 2: VM Bytecode Ladder (ladder_engine.c)\\n• Executa Contatos NO/NC dos Botões (I0.0..I0.5)\\n• Avalia Comparadores de Umidade (AI0.0 < Setpoint)\\n• Processa Timers (TON/TOF), Contadores e PID", fillcolor="#dcfce7", color="#16a34a"];
                p3 [label="Fase 3: Output Flush & Watchdog\\n• Comuta Relés Físicos (Q0.0..Q0.7)\\n• Verifica Overrides e Failsafe", fillcolor="#dcfce7", color="#16a34a"];

                p1 -> p2 -> p3;
            }

            state_ram [label="Tabela de Estado Atômica (state_manager / Shadow RAM)\\n• Bits 0..15: Entradas Digitais I0.x (Botões)\\n• Bits 16..31: Saídas Digitais Q0.x (Relés)\\n• Ints 72..75: Entradas Analógicas AI0.0..AI0.3 (Umidade %)", fillcolor="#f1f5f9", color="#64748b", fontcolor="#0f172a"];
            failsafe [label="Supervisor Failsafe & Watchdog\\nDesenergiza Relés em Caso de Falha Crítica", fillcolor="#fee2e2", color="#dc2626", fontcolor="#991b1b"];
        }
    }

    // 4. Physical Bench Hardware
    subgraph cluster_hardware {
        label="4. Planta Física de Bancada (Alimentação ATX + Entradas + Sensor + Saídas a Relé)";
        style="filled,rounded";
        fillcolor="#f8fafc";
        color="#64748b";
        fontcolor="#0f172a";
        fontsize=12.5;

        btn_hw    [label="Botões de Pulso (Push-Buttons NA)\\n• Acionam Entradas Digitais (I0.0..I0.4)\\n• Pinos GPIO 16, 17, 18, 19, 27\\n• Partida, Parada, Selo e Reset", fillcolor="#fef9c3", color="#ca8a04", fontcolor="#854d0e"];
        sensor_hw [label="Sensor Capacitivo de Umidade v1.2\\n• Saída Analógica 3.0V (Seco) a 1.2V (Água)\\n• Conectado ao ADC1 (GPIO 35 / GPIO 34)\\n• Imune à Corrosão Galvânica", fillcolor="#dbeafe", color="#2563eb", fontcolor="#1e40af"];
        relay_hw  [label="Módulo de Relés Optoacoplados (Saídas DO)\\n• Canais Q0.0..Q0.3 (GPIO 4, 21, 22, 33)\\n• Canais Expansão Q0.4..Q0.7 (GPIO 23, 32, 14, 13)\\n• Comuta Bombas, Válvulas e Sinalizadores", fillcolor="#fee2e2", color="#dc2626", fontcolor="#991b1b"];
        atx_hw    [label="Fonte ATX Chaveada de Bancada\\n• Jumper PS_ON# (Fio Verde -> GND)\\n• Barramentos +12V, +5V, +3.3V e GND Comum", fillcolor="#fef08a", color="#ca8a04", fontcolor="#854d0e"];
    }

    // Connections
    eng -> studio [label="Programa & Compila"];
    op  -> dash   [label="Monitora & Opera"];
    op  -> btn_hw [label="Pressiona Pulso", style="dashed", color="#ca8a04"];
    op  -> sensor_hw [label="Imersão na Água", style="dashed", color="#2563eb"];

    studio -> wifi_link [label="POST /api/plc/bytecode\\nGET /api/telemetry", color="#9333ea"];
    dash   -> wifi_link [label="GET /dash & /api/pve", color="#9333ea"];

    wifi_link -> http_srv [label="TCP/IP Wi-Fi", color="#d97706", penwidth=2.0];
    http_srv -> nvs_mgr [label="Persiste Bytecode"];
    http_srv -> pve_eng [label="Lê Variáveis PVE"];
    http_srv -> state_ram [label="Leitura Lock-Free"];
    http_srv -> p2 [label="Hot-Swap Ponteiro VM", style="dashed", color="#4f46e5"];

    gptimer -> p1;
    p1 -> state_ram [label="Atualiza I0.x & AI0.x"];
    p1 -> pve_eng [label="Alimenta PVE"];
    state_ram -> p2 [label="Lê Operandos"];
    p2 -> state_ram [label="Escreve Q0.x"];
    p3 -> state_ram;
    failsafe -> p3 [label="Corte Seguro", style="dashed", color="#dc2626"];

    btn_hw    -> p1 [label="Pulsos Digitais 3.3V\\n(GPIO 16, 17, 18, 19, 27)", color="#ca8a04", penwidth=1.6];
    sensor_hw -> p1 [label="Tensão Analógica AOUT\\n(GPIO 35 / GPIO 34)", color="#2563eb", penwidth=1.6];
    p3 -> relay_hw  [label="Acionamento Digital Q0.x\\n(GPIO 4, 21, 22, 33...)", color="#dc2626", penwidth=1.6];

    atx_hw -> btn_hw    [label="+3.3V", style="dotted", color="#ca8a04"];
    atx_hw -> sensor_hw [label="+3.3V", style="dotted", color="#ca8a04"];
    atx_hw -> relay_hw  [label="+5V (Bobinas) / +12V (Cargas)", style="dotted", color="#ca8a04"];
}
"""

# -------------------------------------------------------------------------
# 2. ELECTRICAL / HARDWARE ARCHITECTURE DOT
# (ATX PSU + ESP32 + Push-Buttons DI + Capacitive Humidity Sensor AI + Relays DO)
# -------------------------------------------------------------------------
ELECTRICAL_DOT = """digraph ENDAP_Electrical_Architecture_Bancada {
    graph [
        rankdir=TB,
        dpi=300,
        bgcolor="#ffffff",
        fontname="Helvetica,Arial,sans-serif",
        fontsize=14,
        compound=true,
        nodesep=0.40,
        ranksep=0.60,
        pad=0.35,
        label="ENDAP — Diagrama Elétrico e de Pinagem da Bancada (Fonte ATX + ESP32 + Botões + Sensor Capacitivo + Relés)\\n",
        labelloc="t"
    ];
    node [
        fontname="Helvetica,Arial,sans-serif",
        fontsize=10.5,
        shape=box,
        style="filled,rounded",
        penwidth=1.5,
        margin="0.18,0.12"
    ];
    edge [
        fontname="Helvetica,Arial,sans-serif",
        fontsize=9.5,
        color="#334155",
        penwidth=1.3,
        arrowsize=0.85
    ];

    // 1. ATX Power Supply Cluster
    subgraph cluster_atx {
        label="1. Unidade de Alimentação — Fonte Chaveada ATX (Conector 24 Pinos)";
        style="filled,rounded";
        fillcolor="#fefce8";
        color="#eab308";
        fontcolor="#713f12";
        fontsize=12.5;

        atx_box [label="Fonte Chaveada ATX de Computador\\nAlta Estabilidade, Proteção contra Curto (SCP) e Sobretensão (OVP)", fillcolor="#fef08a", color="#ca8a04", fontcolor="#854d0e", shape=box3d];

        atx_pwr_on [label="Circuito de Partida da Fonte (Jumper de Bancada)\\nPino 16 (Fio Verde PS_ON#) -> Pino 15/17 (Fio Preto GND)\\nMantém a Fonte Ligada Continuamente na Apresentação", fillcolor="#bbf7d0", color="#16a34a", fontcolor="#14532d"];

        rail_3v3 [label="Barramento +3.3 VDC (Fio Laranja)\\nAlimenta Sensor Capacitivo e Linha dos Botões de Pulso", fillcolor="#fed7aa", color="#f97316", fontcolor="#9a3412"];
        rail_5v  [label="Barramento +5.0 VDC (Fio Vermelho)\\nAlimenta Pino VIN do ESP32 e Bobinas do Módulo de Relés", fillcolor="#fecaca", color="#ef4444", fontcolor="#991b1b"];
        rail_12v [label="Barramento +12.0 VDC (Fio Amarelo)\\nAlimenta Cargas Chaveadas pelos Contatos NA dos Relés", fillcolor="#fde047", color="#eab308", fontcolor="#854d0e"];
        rail_gnd [label="Barramento Comum GND (Fios Pretos)\\nReferência Equipotencial Unificada (0 V) de Toda a Bancada", fillcolor="#e2e8f0", color="#64748b", fontcolor="#334155"];

        atx_box -> atx_pwr_on [style="dashed"];
        atx_box -> rail_3v3;
        atx_box -> rail_5v;
        atx_box -> rail_12v;
        atx_box -> rail_gnd;
    }

    // 2. Inputs Cluster (Push Buttons + Capacitive Sensor)
    subgraph cluster_inputs {
        label="2. Estágio de Entradas de Campo (Botões de Pulso DI + Sensor Analógico AI)";
        style="filled,rounded";
        fillcolor="#eff6ff";
        color="#3b82f6";
        fontcolor="#1e3a8a";
        fontsize=12.5;

        push_buttons [label="Botoeira de Pulso (Push-Buttons NA — Normalmente Abertos)\\n• Botão B0 (Partida / Start) -> I0.0 (GPIO 16)\\n• Botão B1 (Parada / Stop)  -> I0.1 (GPIO 17)\\n• Botões B2..B4 (Modo / Reset / Pulso) -> I0.2..I0.4 (GPIO 18, 19, 27)\\n• Resistores Pull-Down / Filtro Debounce Digital de 8 ms no Kernel", fillcolor="#fef9c3", color="#ca8a04", fontcolor="#854d0e"];

        cap_sensor [label="Sensor Capacitivo de Umidade do Solo v1.2\\n• Medição Dielétrica via Oscilador TLC555 (Sem Oxidação)\\n• Pino VCC: +3.3V | Pino GND: 0V\\n• Pino AOUT: 3.0V (Ar Seco = 0%) a 1.2V (Imerso = 100%)\\n• Filtro Passa-Baixa RC (1 kΩ + 100 nF) contra Ripple", fillcolor="#dbeafe", color="#2563eb", fontcolor="#1e40af"];
    }

    // 3. ESP32 Controller Cluster
    subgraph cluster_controller {
        label="3. Controlador Lógico Programável — ESP32-WROOM-32 (Gateway Híbrido)";
        style="filled,rounded";
        fillcolor="#f0fdf4";
        color="#22c55e";
        fontcolor="#14532d";
        fontsize=12.5;

        esp_vin [label="Alimentação da Placa (Pino VIN 5V + GND)\\nRegulador LDO AMS1117-3.3 Onboard Estabilizado", fillcolor="#e2e8f0", color="#64748b"];

        di_pins [label="Barramento de Entradas Digitais (DI — 3.3V CMOS)\\n• I0.0 = GPIO 16 | I0.1 = GPIO 17\\n• I0.2 = GPIO 18 | I0.3 = GPIO 19\\n• I0.4 = GPIO 27 | I0.5 = GPIO 13", fillcolor="#fef9c3", color="#ca8a04", fontcolor="#854d0e"];

        ai_pins [label="Barramento de Entradas Analógicas (AI — SAR ADC1 12 bits)\\n• AI0.0 = GPIO 34 (ADC1_CH6) / GPIO 35 (ADC1_CH7)\\n• AI0.1 = GPIO 35 | AI0.2 = GPIO 36 (VP) | AI0.3 = GPIO 39 (VN)\\n• Saídas Analógicas DAC: AO0.0 = GPIO 25 | AO0.1 = GPIO 26", fillcolor="#dbeafe", color="#2563eb", fontcolor="#1e40af"];

        esp_mcu [label="SoC ESP32 Dual-Core Xtensa LX6 @ 240 MHz\\n• Core 1: Laço Determinístico 1 ms + VM Ladder (IEC 61131-3)\\n• Core 0: Pilha Wi-Fi TCP/IP + Servidor HTTP REST & PVE", fillcolor="#dcfce7", color="#16a34a", fontcolor="#14532d", shape=component];

        do_pins [label="Barramento de Saídas Digitais (DO — Acionamento de Relés)\\n• Q0.0 = GPIO 4   | Q0.1 = GPIO 21\\n• Q0.2 = GPIO 22  | Q0.3 = GPIO 33\\n• Expansão: Q0.4 = GPIO 23 | Q0.5 = GPIO 32 | Q0.6 = GPIO 14", fillcolor="#fee2e2", color="#dc2626", fontcolor="#991b1b"];

        esp_vin -> esp_mcu [label="3.3V Interno"];
        di_pins -> esp_mcu [label="Bits I0.0..I0.5"];
        ai_pins -> esp_mcu [label="Counts 0..4095"];
        esp_mcu -> do_pins [label="Bits Q0.0..Q0.7"];
    }

    // 4. Actuator / Relay Cluster
    subgraph cluster_relay {
        label="4. Estágio de Potência e Saídas — Módulo de Relés e Cargas";
        style="filled,rounded";
        fillcolor="#fff1f2";
        color="#fb7185";
        fontcolor="#881337";
        fontsize=12.5;

        relay_mod [label="Módulo de 4 Relés Optoacoplados (5V DC)\\n• Entradas IN1..IN4 Conectadas a Q0.0..Q0.3 (GPIO 4, 21, 22, 33)\\n• Isolamento Galvânico por Fotoacoplador (PC817) + Diodo Flyback\\n• LEDs Indicadores de Estado de Cada Canal de Saída", fillcolor="#ffe4e6", color="#f43f5e", fontcolor="#9f1239"];

        loads [label="Cargas Chaveadas pelos Contatos Secos (COM -> NA)\\n• Canal Q0.0: Bomba de Irrigação / Atuador Principal (+12V)\\n• Canal Q0.1: Válvula Solenoide / VentilaçãoAuxiliar (+12V)\\n• Canais Q0.2..Q0.3: Sinalizadores Luminosos / Alarme de Bancada", fillcolor="#ffffff", color="#e11d48", fontcolor="#9f1239"];

        relay_mod -> loads [label="Fechamento dos Contatos NA\\nComuta Linha +12V DC"];
    }

    // Power Wiring
    rail_5v  -> esp_vin      [label="+5V DC (Fio Vermelho)", color="#ef4444", penwidth=2.0];
    rail_5v  -> relay_mod    [label="+5V DC (VCC Relés)", color="#ef4444", penwidth=1.8];
    rail_3v3 -> push_buttons [label="+3.3V DC (Fio Laranja)", color="#f97316", penwidth=1.8];
    rail_3v3 -> cap_sensor   [label="+3.3V DC (VCC Sensor)", color="#f97316", penwidth=1.8];
    rail_12v -> relay_mod    [label="+12V DC nos Borne COM", color="#eab308", penwidth=2.0];

    rail_gnd -> esp_mcu      [label="GND Comum", color="#475569", penwidth=1.8];
    rail_gnd -> cap_sensor   [label="GND", color="#475569", penwidth=1.4];
    rail_gnd -> relay_mod    [label="GND", color="#475569", penwidth=1.4];
    rail_gnd -> loads        [label="Retorno GND Cargas", color="#475569", penwidth=1.4];

    // Signal Wiring
    push_buttons -> di_pins  [label="Sinais de Pulso 0V / 3.3V\\n(I0.0..I0.4)", color="#ca8a04", penwidth=2.0];
    cap_sensor   -> ai_pins  [label="Sinal Analógico Contínuo 1.2V..3.0V\\n(AI0.0 -> GPIO 35 / GPIO 34)", color="#2563eb", penwidth=2.0];
    do_pins      -> relay_mod [label="Comandos Digitais Q0.0..Q0.3\\n(GPIO 4, 21, 22, 33)", color="#dc2626", penwidth=2.0];
}
"""

def generate():
    for name, dot_content in [
        ("diagrama_software_endap", SOFTWARE_DOT),
        ("diagrama_eletrico_endap", ELECTRICAL_DOT)
    ]:
        dot_file = f"/tmp/{name}.dot"
        with open(dot_file, "w") as f:
            f.write(dot_content)

        for out_dir in OUTPUT_DIRS:
            png_out = os.path.join(out_dir, f"{name}.png")
            svg_out = os.path.join(out_dir, f"{name}.svg")

            # Generate PNG (300 DPI high res)
            cmd_png = ["dot", "-Tpng", "-Gdpi=300", dot_file, "-o", png_out]
            subprocess.run(cmd_png, check=True)
            print(f"Generated: {png_out}")

            # Generate SVG (crisp vector)
            cmd_svg = ["dot", "-Tsvg", dot_file, "-o", svg_out]
            subprocess.run(cmd_svg, check=True)
            print(f"Generated: {svg_out}")

if __name__ == "__main__":
    generate()
