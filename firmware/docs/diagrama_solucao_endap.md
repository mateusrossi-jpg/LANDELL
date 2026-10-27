# Estrutura e Arquitetura da Solução ENDAP — Bancada de Demonstração do TCC

> **Documento de Especificação Técnica e Projeto de Engenharia**  
> **Produto:** ENDAP (*Edge-Native Distributed Automation Platform*)  
> **Escopo da Bancada:** 1x ESP32 (Controlador / Gateway Híbrido), Wi-Fi padrão, Botoeira de Pulso nas Entradas Digitais (`DI`), Sensor Capacitivo Analógico de Umidade (`AI`), Módulo de Relés nas Saídas Digitais (`DO`) e Alimentação por Fonte ATX  
> **Finalidade:** Composição do Relatório Final de Conclusão de Curso (TCC) / Documentação de Engenharia do Produto  

---

## 1. Introdução e Contextualização da Bancada Experimental

Para a validação experimental e demonstração perante a banca examinadora do Trabalho de Conclusão de Curso (TCC), o **ENDAP** (*Edge-Native Distributed Automation Platform*) foi estruturado em uma bancada eletroeletrônica industrial compacta e auto-suficiente. O propósito é comprovar na prática o **determinismo temporal rígido do Kernel de 1 ms**, a **execução da Máquina Virtual de Bytecode Ladder (IEC 61131-3)** e a **supervisão em tempo real via Wi-Fi**, operando sobre entradas digitais a pulso, transdução analógica capacitiva e estágio de potência a relé.

### Componentes Principais da Montagem Atual:
1. **Unidade Controladora Central (ESP32 Gateway Híbrido):**
   - **Core 1 (Tempo Real Estrito — 1 ms):** Dedicado exclusivamente ao ciclo determinístico disparado por interrupção de hardware (`GPTimer` a 1.000 µs), realizando a leitura com *debounce* dos botões de pulso, a amostragem e interpolação do sensor de umidade, a avaliação das redes (*rungs*) de lógica Ladder e o chaveamento imediato dos relés.
   - **Core 0 (Comunicação e Supervisão Assíncrona):** Gerencia a pilha Wi-Fi TCP/IP, o servidor HTTP REST (`/api/telemetry`, `/api/pve`, `/api/io/map`, `/api/plc/bytecode`), a recepção a quente (*Hot-Reload*) de programas compilados pelo **ENDAP Studio** e a interface web embarcada (`/dash`).
2. **Botões de Pulso (Push-Buttons NA) nas Entradas Digitais (`DI`):**
   - Botoeiras normalmente abertas (NA) conectadas às entradas digitais `I0.0..I0.4` (`GPIO 16, 17, 18, 19, 27`), permitindo simular comandos industriais clássicos de painel: **Partida Manual (Start)**, **Parada/Emergência (Stop)**, **Selo Lógico** e **Reset de Contadores/Alarmes**.
   - Cada pino passa por um filtro digital determinístico de *debounce* de 8 amostras consecutivas (8 ms) dentro do `io_driver.c`, eliminando repiques mecânicos de contato.
3. **Sensor Capacitivo Analógico de Umidade (`AI`):**
   - Transdutor capacitivo de umidade do solo (v1.2) imune à corrosão galvânica, conectado à entrada analógica `AI0.0` (`ADC1` nos pinos `GPIO 35` / `GPIO 34`).
   - O sinal analógico contínuo (de ~3.0 V no ar seco até ~1.2 V imerso em água) é convertido em contagens de 12 bits (`0..4095`) e interpolado linearmente pelo firmware (`3800 counts -> 0%` a `1500 counts -> 100%`), alimentando tanto a variável `AI0.0` (`%IW0.0`) do Ladder quanto o *Process Variable Engine* (`PVE`).
4. **Módulo de Relés Optoacoplados nas Saídas Digitais (`DO`):**
   - As saídas digitais `Q0.0..Q0.3` (`GPIO 4, 21, 22, 33`) e canais de expansão `Q0.4..Q0.7` (`GPIO 23, 32, 14, 13`) acionam relés eletromecânicos com isolamento óptico (`PC817`) e diodo de roda-livre (*flyback*), comutando cargas em +12V DC (bomba de irrigação, válvula solenoide e sinalizadores luminosos).
5. **Fonte Chaveada ATX de Bancada:**
   - Fornece todos os barramentos regulados de corrente contínua necessários para a planta: **+3.3 VDC** (fios laranjas — sensor capacitivo e linha de pulso dos botões), **+5.0 VDC** (fios vermelhos — alimentação `VIN` do ESP32 e bobinas dos relés), **+12.0 VDC** (fios amarelos — cargas de potência chaveadas pelos contatos NA dos relés) e **GND Comum** (fios pretos), ativada por jumper no pino 16 (`PS_ON#`).

---

## 2. Diagrama 1: Arquitetura de Software e Fluxo de Execução

O diagrama abaixo representa a arquitetura completa de software do ENDAP, detalhando a separação entre os núcleos do ESP32 (`Core 0` vs. `Core 1`), o ciclo determinístico de 1 ms e a integração com os botões de pulso, sensor capacitivo e relés.

### 2.1. Imagem de Alta Resolução (300 DPI)
![Arquitetura de Software ENDAP](./assets/diagrama_software_endap.png)

*(Versão vetorial SVG disponível em: [`./assets/diagrama_software_endap.svg`](./assets/diagrama_software_endap.svg))*

---

### 2.2. Diagrama Estrutural de Software (Mermaid)

```mermaid
flowchart TD
    subgraph PERSONAS["1. Atores e Interação na Bancada do TCC"]
        direction LR
        ENG["Engenheiro / Apresentador\n(Edita Lógica Ladder, Compila Bytecode, Faz Hot-Swap)"]
        OP["Operador / Banca Avaliadora\n(Aciona Botões de Pulso, Submerge Sensor, Monitora Web)"]
    end

    subgraph UI_LAYER["2. Camada de Engenharia e Supervisão"]
        direction LR
        STUDIO["ENDAP Studio (Flutter Desktop / Web)\n• Editor Ladder IEC 61131-3 (NO/NC, TON, CTU, CMP, PID)\n• Matriz de Pinos e Tags (I0.x, Q0.x, AI0.x, AO0.x)\n• Compilador Bytecode + Power-Flow em Tempo Real"]
        DASH["IHM Web Embarcada (/dash & /api/pve)\n• Servida da Flash do ESP32\n• Status de Botões (DI), Gauge de Umidade (%) e Relés (DO)\n• Comando Manual / Override de Saídas"]
    end

    WIFI{"Barramento Wi-Fi 802.11 b/g/n (2.4 GHz)\nDescoberta Prioritária: Gateway IP / endap.local\nTransporte HTTP REST JSON + Bytecode Binário"}

    subgraph ESP32_FW["3. Firmware ENDAP Controller — ESP32 Dual-Core (ESP-IDF 5.5)"]
        direction TB

        subgraph CORE0["Core 0 — Serviços Assíncronos de Rede e Persistência"]
            HTTP["Servidor HTTP REST (http_server.c)\n/api/telemetry, /api/pve, /api/io/map, /api/plc/bytecode"]
            PVE["Process Variable Engine (pve.c)\nEscala 3800..1500 -> 0.0..100.0% + Alarmes LOLO..HIHI"]
            NVS["Persistência NVS Flash\nBytecode Ladder + Perfil de Pinos"]
        end

        subgraph CORE1["Core 1 — Kernel Determinístico de Tempo Real (1 ms GPTimer)"]
            GPT["GPTimer Hardware ISR (1.000 µs)"]

            subgraph SCAN["Ciclo de Varredura Determinístico (control_loop.c)"]
                direction LR
                P1["Fase 1: IO Scan (io_driver.c)\n• Botões DI (Debounce 8 ms)\n• ADC1 Sensor Umidade (0..100%)"]
                P2["Fase 2: VM Bytecode (ladder_engine.c)\n• Contatos NO/NC (I0.0..I0.5)\n• Comparadores (AI0.0 < Setpoint)\n• Timers TON/TOF, CTU e PID"]
                P3["Fase 3: Output Flush\n• Comuta Relés (Q0.0..Q0.7)\n• Aplica Overrides / Failsafe"]
                P1 --> P2 --> P3
            end

            STATE["Tabela Atômica de Estado (state_manager)\nBits 0..15 (I0.x) | Bits 16..31 (Q0.x) | Ints 72..75 (AI0.x)"]
            FAILSAFE["Supervisor Failsafe & Watchdog\nCorte Seguro dos Relés em Falha"]
        end
    end

    subgraph HW_BENCH["4. Planta Física de Bancada"]
        direction LR
        BTN["Botões de Pulso NA (DI)\nI0.0..I0.4 (GPIO 16, 17, 18, 19, 27)"]
        SENS["Sensor Capacitivo de Umidade (AI)\nAI0.0 (GPIO 35 / GPIO 34 ADC1)"]
        RELAYS["Módulo de Relés Optoacoplados (DO)\nQ0.0..Q0.3 (GPIO 4, 21, 22, 33)"]
        ATX["Fonte ATX Chaveada\n(+12V, +5V, +3.3V, GND, PS_ON#)"]
    end

    ENG --> STUDIO
    OP --> DASH
    OP -.->|"Pulso Manual"| BTN
    OP -.->|"Copo d'Água"| SENS

    STUDIO --> WIFI
    DASH --> WIFI
    WIFI --> HTTP

    HTTP --> NVS
    HTTP --> PVE
    HTTP --> STATE
    HTTP -.->|"Hot-Swap VM"| P2

    GPT --> P1
    P1 --> STATE
    P1 --> PVE
    STATE --> P2
    P2 --> STATE
    P3 --> STATE
    FAILSAFE -.-> P3

    BTN -->|"Pulsos 3.3V"| P1
    SENS -->|"1.2V..3.0V"| P1
    P3 -->|"3.3V CMOS"| RELAYS
    ATX -.-> HW_BENCH
```

---

## 3. Diagrama 2: Arquitetura Elétrica e Pinagem Completa da Bancada

O diagrama elétrico abaixo detalha as ligações físicas entre a **Fonte ATX**, a **Botoeira de Pulso (Entradas Digitais)**, o **Sensor Capacitivo de Umidade (Entrada Analógica)**, o **ESP32-WROOM-32** e o **Módulo de Relés (Saídas Digitais)**.

### 3.1. Imagem de Alta Resolução (300 DPI)
![Arquitetura Elétrica ENDAP](./assets/diagrama_eletrico_endap.png)

*(Versão vetorial SVG disponível em: [`./assets/diagrama_eletrico_endap.svg`](./assets/diagrama_eletrico_endap.svg))*

---

### 3.2. Diagrama Elétrico de Ligações (Mermaid)

```mermaid
flowchart TB
    subgraph ATX_SEC["1. Fonte Chaveada ATX de Bancada (Conector 24 Pinos)"]
        ATX_BOX["Fonte Chaveada ATX (Proteção SCP / OVP)"]
        ATX_JMP["Jumper de Partida: Pino 16 (Fio Verde PS_ON#) -> Fio Preto (GND)"]
        R33["Barramento +3.3 VDC (Fio Laranja)"]
        R50["Barramento +5.0 VDC (Fio Vermelho)"]
        R12["Barramento +12.0 VDC (Fio Amarelo)"]
        RGND["Barramento Comum GND (Fios Pretos)"]

        ATX_BOX --> ATX_JMP
        ATX_BOX --> R33
        ATX_BOX --> R50
        ATX_BOX --> R12
        ATX_BOX --> RGND
    end

    subgraph INPUT_SEC["2. Estágio de Entradas de Campo (Botões DI + Sensor AI)"]
        BTNS["Botoeira de Pulso (Push-Buttons NA)\n• B0 (Partida) -> I0.0 (GPIO 16)\n• B1 (Parada) -> I0.1 (GPIO 17)\n• B2..B4 (Modo/Reset) -> I0.2..I0.4 (GPIO 18, 19, 27)"]
        CAP_SENS["Sensor Capacitivo de Umidade v1.2\n• VCC: +3.3V | GND: 0V\n• AOUT: 3.0V (Seco = 0%) a 1.2V (Água = 100%)\n• Filtro RC Passa-Baixa (1 kΩ + 100 nF)"]
    end

    subgraph ESP_SEC["3. Controlador Lógico Programável — ESP32-WROOM-32"]
        VIN["Regulador LDO Onboard (Entrada VIN 5V -> 3.3V)"]
        DI_BUS["Entradas Digitais (DI — Debounce 8 ms)\nI0.0=GPIO 16 | I0.1=GPIO 17 | I0.2=GPIO 18 | I0.3=GPIO 19 | I0.4=GPIO 27 | I0.5=GPIO 13"]
        AI_BUS["Entradas Analógicas (AI — ADC1 12 bits)\nAI0.0=GPIO 34/35 | AI0.1=GPIO 35 | AI0.2=GPIO 36 | AI0.3=GPIO 39\nSaídas Analógicas DAC: AO0.0=GPIO 25 | AO0.1=GPIO 26"]
        MCU["SoC ESP32 Dual-Core 240 MHz\nCore 1: Ciclo 1 ms + VM Ladder | Core 0: Wi-Fi + HTTP REST"]
        DO_BUS["Saídas Digitais (DO — Comando de Relés)\nQ0.0=GPIO 4 | Q0.1=GPIO 21 | Q0.2=GPIO 22 | Q0.3=GPIO 33\nExpansão: Q0.4=GPIO 23 | Q0.5=GPIO 32 | Q0.6=GPIO 14"]

        VIN --> MCU
        DI_BUS --> MCU
        AI_BUS --> MCU
        MCU --> DO_BUS
    end

    subgraph RELAY_SEC["4. Estágio de Potência e Saídas — Módulo de Relés"]
        REL_MOD["Módulo de 4 Relés Optoacoplados (5V DC)\n• Entradas IN1..IN4 <- Q0.0..Q0.3 (GPIO 4, 21, 22, 33)\n• Fotoacoplador PC817 + Transistor Driver + Diodo Flyback"]
        LOADS["Cargas de Bancada (+12V DC via Contatos Secos NA)\n• Q0.0: Bomba de Irrigação\n• Q0.1: Válvula Solenoide\n• Q0.2..Q0.3: Sinalizadores Luminosos"]
        REL_MOD --> LOADS
    end

    R50 ==>|"Fio Vermelho (+5V)"| VIN
    R50 ==>|"Fio Vermelho (+5V)"| REL_MOD
    R33 ==>|"Fio Laranja (+3.3V)"| BTNS
    R33 ==>|"Fio Laranja (+3.3V)"| CAP_SENS
    R12 ==>|"Fio Amarelo (+12V COM)"| REL_MOD
    RGND ==>|"Fio Preto (GND Comum)"| ESP_SEC
    RGND ==>|"Fio Preto (GND)"| CAP_SENS
    RGND ==>|"Fio Preto (GND)"| REL_MOD
    RGND ==>|"Fio Preto (GND)"| LOADS

    BTNS -->|"Pulsos 0V / 3.3V"| DI_BUS
    CAP_SENS -->|"Sinal Analógico 1.2V..3.0V"| AI_BUS
    DO_BUS -->|"Sinais Digitais 3.3V"| REL_MOD
```

---

## 4. Tabela Consolidada de Mapeamento de Hardware da Bancada

| Tipo | Tag CLP | Endereço IEC | Pino ESP32 | Função Elétrica na Bancada | Condicionamento / Tratamento no Firmware |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DI** | `I0.0` | `%IX0.0` | `GPIO 16` | Botão de Pulso NA 1 (Partida / Limiar Digital) | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **DI** | `I0.1` | `%IX0.1` | `GPIO 17` | Botão de Pulso NA 2 (Parada / Emergência) | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **DI** | `I0.2` | `%IX0.2` | `GPIO 18` | Botão de Pulso NA 3 (Seleção Automático/Manual) | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **DI** | `I0.3` | `%IX0.3` | `GPIO 19` | Botão de Pulso NA 4 (Reset de Alarmes/Contadores) | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **DI** | `I0.4` | `%IX0.4` | `GPIO 27` | Botão de Pulso NA 5 (Pulso de Contagem `CTU`) | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **DI** | `I0.5` | `%IX0.5` | `GPIO 13` | Entrada Digital Auxiliar 6 | Filtro de *debounce* determinístico de 8 ms (`io_driver.c`) |
| **AI** | `AI0.0` | `%IW0.0` | `GPIO 34` / `35` | Sensor Capacitivo de Umidade (`AOUT`) | `ADC1` 12 bits (`3800..1500` counts $\rightarrow$ `0..100%`) |
| **AI** | `AI0.1` | `%IW0.1` | `GPIO 35` | Entrada Analógica 2 (`ADC1_CH7`) | `ADC1` 12 bits + Escalonamento `PVE` (`AIN2`) |
| **AI** | `AI0.2` | `%IW0.2` | `GPIO 36` (`VP`) | Entrada Analógica 3 (`ADC1_CH0`) | `ADC1` 12 bits (`0..4095`) |
| **AI** | `AI0.3` | `%IW0.3` | `GPIO 39` (`VN`) | Entrada Analógica 4 (`ADC1_CH3`) | `ADC1` 12 bits (`0..4095`) |
| **DO** | `Q0.0` | `%QX0.0` | `GPIO 4` | Relé 1 (Bomba Principal de Irrigação) | Isolamento Óptico + Escrita Atômica Fase 3 (`1 ms`) |
| **DO** | `Q0.1` | `%QX0.1` | `GPIO 21` | Relé 2 (Válvula Solenoide / Auxiliar) | Isolamento Óptico + Escrita Atômica Fase 3 (`1 ms`) |
| **DO** | `Q0.2` | `%QX0.2` | `GPIO 22` | Relé 3 (Sinalizador de Operação) | Isolamento Óptico + Escrita Atômica Fase 3 (`1 ms`) |
| **DO** | `Q0.3` | `%QX0.3` | `GPIO 33` | Relé 4 (Alarme Luminoso / Sonoro) | Isolamento Óptico + Escrita Atômica Fase 3 (`1 ms`) |
| **DO** | `Q0.4..Q0.6`| `%QX0.4..0.6` | `GPIO 23, 32, 14` | Saídas Digitais de Expansão | Escrita Atômica Fase 3 (`1 ms`) |
| **AO** | `AO0.0..0.1`| `%QW0.0..0.1` | `GPIO 25, 26` | Saídas Analógicas DAC 8 bits (`0..3.3V`) | Conversor Digital-Analógico Nativo (`DAC1` / `DAC2`) |
