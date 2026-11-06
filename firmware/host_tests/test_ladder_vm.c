#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "host_test_env.h"
#include "state.h"
#include "event_bus.h"
#include "snapshot.h"
#include "io_map.h"
#include "ladder_engine.h"
#include "ladder_pid.h"

#define OP_LD             0x01
#define OP_LDN            0x02
#define OP_AND            0x03
#define OP_ANDN           0x04
#define OP_OR             0x05
#define OP_ORN            0x06
#define OP_ST             0x10
#define OP_SET            0x11
#define OP_RST            0x12
#define OP_OR_BLOCK_START 0x20
#define OP_OR_BLOCK_NEXT  0x21
#define OP_OR_BLOCK_END   0x22
#define OP_TON            0x30
#define OP_TOF            0x31
#define OP_CTU            0x32
#define OP_CTD            0x33
#define OP_EQU            0x40
#define OP_GRT            0x41
#define OP_LES            0x42
#define OP_ADD            0x50
#define OP_SUB            0x51
#define OP_MUL            0x52
#define OP_DIV            0x53
#define OP_PIDX           0x61
#define OP_END            0xFF

#define U16BE(v) (uint8_t)(((uint16_t)(v) >> 8) & 0xFF), (uint8_t)((uint16_t)(v) & 0xFF)

static int g_failures = 0;
static int g_checks = 0;

#define EXPECT(cond, msg) \
    do { \
        g_checks++; \
        if (!(cond)) { \
            printf("  [FAIL] %s:%d -> %s\n", __FILE__, __LINE__, (msg)); \
            g_failures++; \
        } \
    } while (0)

static int32_t rd_state(uint16_t id)
{
    int32_t v = 0;
    state_get_int(id, &v);
    return v;
}

static void reset_vm(void)
{
    host_test_reset_env();
    event_bus_init();
    state_init();
    snapshot_init();
    ladder_engine_init();
}

/* 1. Validacao de header, opcodes invalidos, limites de tamanho e protecao de MV do PID */
static void test_validation_and_safety(void)
{
    reset_vm();

    const uint8_t bad_magic[] = { 'B', 'A', 'D', '!', 0x01, OP_END };
    EXPECT(ladder_engine_load_program(bad_magic, sizeof(bad_magic)) == ESP_ERR_INVALID_ARG,
           "rejeita header diferente de ENDP");

    const uint8_t too_short[] = { 'E', 'N', 'D', 'P' };
    EXPECT(ladder_engine_load_program(too_short, sizeof(too_short)) == ESP_ERR_INVALID_ARG,
           "rejeita bytecode menor que 5 bytes");

    const uint8_t bad_op[] = { 'E', 'N', 'D', 'P', 0x01, 0x99, OP_END };
    EXPECT(ladder_engine_load_program(bad_op, sizeof(bad_op)) == ESP_ERR_INVALID_ARG,
           "rejeita opcode desconhecido");

    const uint8_t trunc_ld[] = { 'E', 'N', 'D', 'P', 0x01, OP_LD, 0x00 };
    EXPECT(ladder_engine_load_program(trunc_ld, sizeof(trunc_ld)) == ESP_ERR_INVALID_ARG,
           "rejeita operando truncado em OP_LD");

    const uint8_t bad_math_flag[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_ADD, U16BE(72), 0x02 /* flag invalida */, U16BE(10), U16BE(80),
        OP_END
    };
    EXPECT(ladder_engine_load_program(bad_math_flag, sizeof(bad_math_flag)) == ESP_ERR_INVALID_ARG,
           "rejeita flags_b invalida em bloco matematico");

    /* PID tentando escrever MV em entrada fisica I0.0 (ID 10) ou AI0.0 escalada (ID 72) */
    uint8_t pid_bad_mv[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_PIDX,
        U16BE(72),          /* PV = AI0.0 escalado */
        U16BE(0x8000 | 50), /* SP literal = 50% */
        U16BE(10),          /* MV = I0.0 (PROIBIDO!) */
        U16BE(200), U16BE(50), U16BE(0),
        0, 0, 100, 0, 20, 5, 0,
        U16BE(0), U16BE(0),
        OP_END
    };
    EXPECT(ladder_engine_load_program(pid_bad_mv, sizeof(pid_bad_mv)) == ESP_ERR_INVALID_ARG,
           "PID rejeita MV apontando para entrada digital fisica (ID 10)");

    pid_bad_mv[10] = 0x00;
    pid_bad_mv[11] = 72; /* AI0.0 escalado */
    EXPECT(ladder_engine_load_program(pid_bad_mv, sizeof(pid_bad_mv)) == ESP_ERR_INVALID_ARG,
           "PID rejeita MV apontando para entrada analogica fisica (ID 72)");

    printf("  [PASS] Validacao estatica de bytecode e protecao de entradas fisicas\n");
}

/* 2. Logica booleana, selo (auto-retencao) com OR_BLOCK e ramos paralelos aninhados */
static void test_boolean_and_seal_in_branches(void)
{
    reset_vm();

    /* Rung 0 (Partida Direta com Selo):
     *   (I0.0 OR Q0.0) ANDN I0.1 (Emergencia NF) -> Q0.0
     * Rung 1:
     *   LDN Q0.0 -> Q0.1 (Lampada Parado)
     */
    const uint8_t prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_OR_BLOCK_START,
            OP_AND, U16BE(10),   /* ramo 1: I0.0 (Start) */
        OP_OR_BLOCK_NEXT,
            OP_AND, U16BE(100),  /* ramo 2: Q0.0 (Selo) */
        OP_OR_BLOCK_END,
        OP_ANDN, U16BE(11),      /* I0.1 (Stop / Emergencia) */
        OP_ST, U16BE(100),       /* Q0.0 (Motor) */

        OP_LDN, U16BE(100),
        OP_ST, U16BE(101),       /* Q0.1 (Lampada Parado) */
        OP_END
    };
    EXPECT(ladder_engine_load_program(prog, sizeof(prog)) == ESP_OK, "carrega partida com selo");

    /* Repouso: Q0.0=0, Q0.1=1 */
    ladder_engine_run();
    EXPECT(rd_state(100) == 0 && rd_state(101) == 1, "repouso inicial Q0.0=0, Q0.1=1");

    /* Pulso em Start (I0.0=1): liga Q0.0 */
    state_set_int(10, 1);
    ladder_engine_run();
    EXPECT(rd_state(100) == 1 && rd_state(101) == 0, "pulso em I0.0 atraca Q0.0");

    /* Solta Start (I0.0=0): selo mantem Q0.0=1! */
    state_set_int(10, 0);
    ladder_engine_run();
    EXPECT(rd_state(100) == 1 && rd_state(101) == 0, "selo mantem Q0.0=1 apos soltar I0.0");

    /* Aciona Stop (I0.1=1): derruba selo Q0.0=0 */
    state_set_int(11, 1);
    ladder_engine_run();
    EXPECT(rd_state(100) == 0 && rd_state(101) == 1, "I0.1 corta o selo e desliga Q0.0");

    /* Solta Stop (I0.1=0): permanece desligado */
    state_set_int(11, 0);
    ladder_engine_run();
    EXPECT(rd_state(100) == 0, "motor permanece desligado apos liberar I0.1");

    printf("  [PASS] Contatos NO/NC, bobinas e selo (OR_BLOCK_START/NEXT/END)\n");
}

/* 3. Temporizadores TON e TOF com relogio deterministico simulado */
static void test_timers_ton_and_tof(void)
{
    reset_vm();

    /* Rung 0: I0.0 -> TON(T0=40, 1000ms) -> Q0.0(100)
     * Rung 1: I0.1 -> TOF(T1=41, 500ms)  -> Q0.1(101) */
    const uint8_t prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_LD,  U16BE(10),
        OP_TON, U16BE(40), U16BE(1000),
        OP_ST,  U16BE(100),

        OP_LD,  U16BE(11),
        OP_TOF, U16BE(41), U16BE(500),
        OP_ST,  U16BE(101),
        OP_END
    };
    EXPECT(ladder_engine_load_program(prog, sizeof(prog)) == ESP_OK, "carrega TON/TOF");

    /* TON: energiza I0.0 em t=1000ms */
    state_set_int(10, 1);
    ladder_engine_run();
    EXPECT(rd_state(100) == 0 && rd_state(40) == 0, "TON em t+0ms ainda nao disparou");

    bool t0_active = false;
    int64_t t0_elapsed = -1;
    host_test_advance_ms(999);
    ladder_engine_run();
    EXPECT(rd_state(100) == 0, "TON em t+999ms ainda em 0");
    EXPECT(ladder_engine_get_timer_state(40, &t0_active, &t0_elapsed) && t0_active && t0_elapsed == 999,
           "ladder_engine_get_timer_state reporta 999ms decorridos");

    host_test_advance_ms(1); /* exatos 1000ms */
    ladder_engine_run();
    EXPECT(rd_state(100) == 1 && rd_state(40) == 1, "TON em t+1000ms atraca Q0.0 e T0");

    /* Queda de I0.0 reseta TON imediatamente */
    state_set_int(10, 0);
    ladder_engine_run();
    EXPECT(rd_state(100) == 0 && rd_state(40) == 0, "TON reseta imediatamente quando entrada cai");

    /* TOF: energiza I0.1 -> Q0.1 sobe na hora */
    state_set_int(11, 1);
    ladder_engine_run();
    EXPECT(rd_state(101) == 1 && rd_state(41) == 1, "TOF liga Q0.1 imediatamente com entrada=1");

    /* Queda de I0.1 -> inicia contagem regressiva de 500ms mantendo Q0.1=1 */
    state_set_int(11, 0);
    ladder_engine_run();
    EXPECT(rd_state(101) == 1, "TOF segura Q0.1=1 na borda de descida");

    host_test_advance_ms(499);
    ladder_engine_run();
    EXPECT(rd_state(101) == 1, "TOF segura Q0.1=1 em 499ms");

    host_test_advance_ms(1); /* 500ms */
    ladder_engine_run();
    EXPECT(rd_state(101) == 0 && rd_state(41) == 0, "TOF desliga Q0.1 exatamente em 500ms");

    printf("  [PASS] Temporizadores TON e TOF (precisao de 1ms + telemetria de elapsed_ms)\n");
}

/* 4. Contadores CTU, CTD, bobinas SET/RST e reset de contador */
static void test_counters_and_latch_coils(void)
{
    reset_vm();

    /* Rung 0: I0.0 -> CTU(C0=56, preset=3) -> SET Q0.0(100)
     * Rung 1: I0.1 -> RST C0(56), RST Q0.0(100)
     * Rung 2: I0.2 -> CTD(C1=57, preset=2) -> ST Q0.1(101) */
    const uint8_t prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_LD,  U16BE(10),
        OP_CTU, U16BE(56), U16BE(3),
        OP_SET, U16BE(100),

        OP_LD,  U16BE(11),
        OP_RST, U16BE(56),
        OP_RST, U16BE(100),

        OP_LD,  U16BE(12),
        OP_CTD, U16BE(57), U16BE(2),
        OP_ST,  U16BE(101),
        OP_END
    };
    EXPECT(ladder_engine_load_program(prog, sizeof(prog)) == ESP_OK, "carrega CTU/CTD/SET/RST");

    /* 2 pulsos em I0.0 (incluindo multiplos scans em nivel alto para provar deteccao de borda) */
    for (int p = 0; p < 2; p++) {
        state_set_int(10, 1);
        ladder_engine_run();
        ladder_engine_run(); /* nivel mantido nao deve contar dobrado */
        state_set_int(10, 0);
        ladder_engine_run();
    }
    EXPECT(rd_state(56) == 0 && rd_state(100) == 0, "CTU com 2 pulsos < preset 3 permanece 0");

    /* 3o pulso atinge preset=3 e trava SET Q0.0 */
    state_set_int(10, 1);
    ladder_engine_run();
    state_set_int(10, 0);
    ladder_engine_run();
    EXPECT(rd_state(56) == 1 && rd_state(100) == 1, "CTU no 3o pulso atinge preset e faz SET em Q0.0");

    /* Pulso em I0.1 reseta tanto C0 quanto o latch Q0.0 */
    state_set_int(11, 1);
    ladder_engine_run();
    state_set_int(11, 0);
    ladder_engine_run();
    EXPECT(rd_state(56) == 0 && rd_state(100) == 0, "OP_RST zera acumulador de C0 e destrava Q0.0");

    /* Apos reset, 1 pulso novo em I0.0 nao dispara (prova que current_count voltou a 0!) */
    state_set_int(10, 1);
    ladder_engine_run();
    state_set_int(10, 0);
    ladder_engine_run();
    EXPECT(rd_state(56) == 0 && rd_state(100) == 0, "CTU exige 3 novos pulsos apos OP_RST");

    /* CTD inicializa em preset=2; apos 2 bordas de subida em I0.2 chega a 0 e liga Q0.1 */
    EXPECT(rd_state(101) == 0, "CTD inicia com count=2 (done=0)");
    for (int p = 0; p < 2; p++) {
        state_set_int(12, 1);
        ladder_engine_run();
        state_set_int(12, 0);
        ladder_engine_run();
    }
    EXPECT(rd_state(57) == 1 && rd_state(101) == 1, "CTD chega a 0 apos 2 pulsos e ativa Q0.1");

    printf("  [PASS] Contadores CTU/CTD (borda de subida) e bobinas SET/RST\n");
}

/* 5. Comparadores (EQU, GRT, LES com negativos) e blocos matematicos (ADD, SUB, MUL, DIV) */
static void test_comparators_and_math(void)
{
    reset_vm();

    /* Rung 0: I0.0 -> ADD(reg 90, imm 25 -> reg 91), MUL(reg 91, reg 92 -> reg 93), DIV(reg 93, reg 94 -> reg 95) -> ST M0.0(26)
     * Rung 1: GRT(reg 93 > 100) -> ST Q0.0(100)
     * Rung 2: LES(reg 96 < 0)   -> ST Q0.1(101)
     * Rung 3: EQU(reg 91 == 40) -> ST Q0.2(102) */
    const uint8_t prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_LD,  U16BE(10),
        OP_ADD, U16BE(90), 0x01, U16BE(25), U16BE(91),
        OP_MUL, U16BE(91), 0x00, U16BE(92), U16BE(93),
        OP_DIV, U16BE(93), 0x00, U16BE(94), U16BE(95),
        OP_ST,  U16BE(26),

        OP_LD,  U16BE(26),
        OP_GRT, U16BE(93), U16BE(100),
        OP_ST,  U16BE(100),

        OP_LD,  U16BE(26),
        OP_LES, U16BE(96), U16BE(0),
        OP_ST,  U16BE(101),

        OP_LD,  U16BE(26),
        OP_EQU, U16BE(91), U16BE(40),
        OP_ST,  U16BE(102),
        OP_END
    };
    EXPECT(ladder_engine_load_program(prog, sizeof(prog)) == ESP_OK, "carrega comparadores e matematica");

    state_set_int(90, 15);
    state_set_int(92, 3);
    state_set_int(94, 0);   /* testa protecao contra divisao por zero! */
    state_set_int(96, -12); /* valor negativo */

    /* Com I0.0=0, blocos matematicos nao executam */
    state_set_int(10, 0);
    ladder_engine_run();
    EXPECT(rd_state(91) == 0 && rd_state(93) == 0, "blocos matematicos respeitam EN=0");

    /* Com I0.0=1: reg91 = 15+25 = 40; reg93 = 40*3 = 120; reg95 = 120/0 -> 0 seguro */
    state_set_int(10, 1);
    ladder_engine_run();
    EXPECT(rd_state(91) == 40, "OP_ADD imediato: 15 + 25 = 40");
    EXPECT(rd_state(93) == 120, "OP_MUL por tag: 40 * 3 = 120");
    EXPECT(rd_state(95) == 0, "OP_DIV por zero retorna 0 sem crash");
    EXPECT(rd_state(100) == 1, "OP_GRT: 120 > 100 = true");
    EXPECT(rd_state(101) == 1, "OP_LES signed: -12 < 0 = true");
    EXPECT(rd_state(102) == 1, "OP_EQU: 40 == 40 = true");

    /* Agora divide por 8: 120 / 8 = 15 */
    state_set_int(94, 8);
    ladder_engine_run();
    EXPECT(rd_state(95) == 15, "OP_DIV: 120 / 8 = 15");

    printf("  [PASS] Comparadores signed 16-bit (EQU/GRT/LES) e matematica (ADD/SUB/MUL/DIV)\n");
}

/* 6. PIDX integrado ao ladder_engine_run + persistencia NVS pos-reboot */
static void test_pidx_integration_and_nvs_persistence(void)
{
    reset_vm();

    /* Rung: I0.0 -> PIDX(PV=AI0.0 bruto ID 22 -> mapeia p/ ID 72, SP=60%, MV=AO0 ID 80,
     *                    Kp=2.00, Ki=0.50, Kd=0, ENO>25% hyst 5%, safe=10%,
     *                    man_sel=M0.0(26), man_out=45%) -> ST Q0.0(100) */
    const uint8_t prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_LD, U16BE(10),
        OP_PIDX,
        U16BE(22),          /* PV = canal fisico bruto 22 -> engine le ID 72 escalado! */
        U16BE(0x8000 | 60), /* SP literal = 60% */
        U16BE(80),          /* MV = AQ0.0 (ID 80) */
        U16BE(200),         /* Kp = 2.00 */
        U16BE(50),          /* Ki = 0.50 */
        U16BE(0),           /* Kd = 0.00 */
        LADDER_PID_FLAG_MANUAL_ENABLE,
        0, 100,             /* out_min=0, out_max=100 */
        0,                  /* deadband=0 */
        25, 5,              /* eno_threshold=25%, hysteresis=5% */
        10,                 /* safe_out=10% */
        U16BE(26),          /* man_sel_tag = M0.0 */
        U16BE(0x8000 | 45), /* man_out literal = 45% */
        OP_ST, U16BE(100),  /* Q0.0 segue ENO do PID! */
        OP_END
    };
    EXPECT(ladder_engine_load_program(prog, sizeof(prog)) == ESP_OK, "carrega programa PIDX e salva na NVS");

    /* EN=0 -> aplica safe_out=10% e ENO=0 */
    state_set_int(10, 0);
    state_set_int(72, 20); /* PV escalonado = 20% */
    ladder_engine_run();
    EXPECT(rd_state(80) == 10 && rd_state(100) == 0, "PIDX com EN=0 aplica safe_out=10% e ENO=0");

    /* EN=1, PV=20%, SP=60% -> erro=40 -> P=80% + I=2% = 82%, ENO=1 -> Q0.0=1 */
    state_set_int(10, 1);
    host_test_advance_ms(100);
    ladder_engine_run();
    EXPECT(rd_state(80) >= 80 && rd_state(100) == 1, "PIDX em AUTO calcula MV ~82% e aciona Q0.0 via ENO");

    /* Chave Manual M0.0=1 -> MV assume 45% */
    state_set_int(26, 1);
    host_test_advance_ms(100);
    ladder_engine_run();
    EXPECT(rd_state(80) == 45 && rd_state(100) == 1, "PIDX em MANUAL crava MV=45%");

    /* Simula REBOOT do ESP32 (zera RAM do estado, mas mantem NVS intacta!) */
    state_init();
    EXPECT(ladder_engine_init() == ESP_OK, "ladder_engine_init() apos reboot");

    uint8_t restored[128];
    size_t restored_len = ladder_engine_get_program(restored, sizeof(restored));
    EXPECT(restored_len == sizeof(prog) && memcmp(restored, prog, sizeof(prog)) == 0,
           "programa Ladder completo restaurado byte-a-byte da NVS apos reboot");

    state_set_int(10, 1);
    state_set_int(72, 20);
    host_test_advance_ms(100);
    ladder_engine_run();
    EXPECT(rd_state(80) >= 80 && rd_state(100) == 1,
           "programa restaurado da NVS executa imediatamente apos boot");

    printf("  [PASS] Bloco industrial OP_PIDX + persistencia e boot recovery em NVS\n");
}

int main(void)
{
    printf("=== [3/4] Ladder Bytecode VM Comprehensive Host Suite ===\n");
    test_validation_and_safety();
    test_boolean_and_seal_in_branches();
    test_timers_ton_and_tof();
    test_counters_and_latch_coils();
    test_comparators_and_math();
    test_pidx_integration_and_nvs_persistence();

    if (g_failures > 0) {
        printf("LADDER VM SUITE FAILED (%d/%d checks failed)\n", g_failures, g_checks);
        return 1;
    }
    printf("LADDER VM SUITE OK (%d assertions passed)\n", g_checks);
    return 0;
}
