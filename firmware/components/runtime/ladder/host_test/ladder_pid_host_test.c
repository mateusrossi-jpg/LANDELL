/* Teste de mesa (PC) do bloco PID industrial.
 *   gcc -Wall -Wextra -O2 -I.. -o /tmp/pid_host_test ladder_pid_host_test.c ../ladder_pid.c && /tmp/pid_host_test
 * Imprime vetores dourados ("GOLDEN") que o teste Dart (pid_industrial_test.dart) reproduz
 * byte a byte, garantindo que o simulador do Studio == firmware. */
#include <stdio.h>
#include <stdlib.h>
#include "ladder_pid.h"

static int g_fail = 0;
#define CHECK(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); g_fail++; } } while (0)

static ladder_pid_params_t base_params(void)
{
    ladder_pid_params_t p = {
        .kp_x100 = 250, .ki_x100 = 50, .kd_x100 = 10,
        .flags = LADDER_PID_FLAG_MANUAL_ENABLE,
        .out_min = 0, .out_max = 100, .deadband_x10 = 0,
        .eno_threshold = 20, .eno_hysteresis = 5, .safe_out = 0,
    };
    return p;
}

int main(void)
{
    ladder_pid_params_t p = base_params();
    ladder_pid_state_t s = {0};

    /* Cenario A: solo seco (PV sobe de 20 a 60), SP = 50, acao reversa. */
    ladder_pid_disable(&p, &s);
    int pv_seq[] = {20, 20, 22, 25, 30, 35, 40, 44, 47, 49, 50, 51, 52, 52, 50, 48};
    printf("GOLDEN_A");
    for (size_t i = 0; i < sizeof(pv_seq) / sizeof(pv_seq[0]); i++) {
        ladder_pid_step(&p, &s, pv_seq[i], 50, false, 0, 100);
        printf(" %d:%d", (int)s.mv_m, s.eno ? 1 : 0);
    }
    printf("\n");

    /* Cenario B: anti-windup. PV preso em 0 por 200 amostras (saturado em 100%),
     * depois PV = 100 > SP. A saida deve cair logo (sem windup). */
    ladder_pid_disable(&p, &s);
    for (int i = 0; i < 200; i++) ladder_pid_step(&p, &s, 0, 50, false, 0, 100);
    CHECK(s.mv_m == 100000, "B: satura em 100%");
    CHECK(s.integ_m <= 100000, "B: integrador limitado ao teto");
    ladder_pid_step(&p, &s, 100, 50, false, 0, 100);
    printf("GOLDEN_B %d:%d:%d\n", (int)s.mv_m, s.eno ? 1 : 0, (int)s.integ_m);
    CHECK(s.mv_m < 100000, "B: sai da saturacao imediatamente (sem windup)");

    /* Cenario C: banda morta de 2% -> erro dentro da banda nao mexe na saida. */
    p = base_params();
    p.deadband_x10 = 20;
    p.ki_x100 = 0;
    p.kd_x100 = 0;
    ladder_pid_disable(&p, &s);
    ladder_pid_step(&p, &s, 49, 50, false, 0, 100);
    CHECK(s.mv_m == 0, "C: dentro da banda morta, P = 0");
    ladder_pid_step(&p, &s, 40, 50, false, 0, 100);
    CHECK(s.mv_m == 25000, "C: fora da banda, P = 2,5 * 10 = 25%");
    printf("GOLDEN_C %d\n", (int)s.mv_m);

    /* Cenario D: MANUAL com transferencia sem solavanco para AUTO. */
    p = base_params();
    p.kd_x100 = 0;
    ladder_pid_disable(&p, &s);
    for (int i = 0; i < 5; i++) ladder_pid_step(&p, &s, 30, 50, true, 70, 100);
    CHECK(s.mv_m == 70000, "D: manual segue a saida manual");
    ladder_pid_step(&p, &s, 30, 50, false, 70, 100);
    printf("GOLDEN_D %d\n", (int)s.mv_m);
    CHECK(s.mv_m >= 69000 && s.mv_m <= 71000, "D: AUTO assume 70% sem solavanco");

    /* Cenario E: histerese do ENO (liga > 20%, desliga <= 15%). */
    p = base_params();
    p.kp_x100 = 100; p.ki_x100 = 0; p.kd_x100 = 0;
    ladder_pid_disable(&p, &s);
    int pv_e[] = {50, 35, 25, 31, 33, 34, 35, 36, 40, 50};
    printf("GOLDEN_E");
    for (size_t i = 0; i < sizeof(pv_e) / sizeof(pv_e[0]); i++) {
        ladder_pid_step(&p, &s, pv_e[i], 50, false, 0, 100);
        printf(" %d:%d", (int)s.mv_m, s.eno ? 1 : 0);
    }
    printf("\n");

    /* Cenario F: acao direta (resfriamento): PV acima do SP -> MV sobe. */
    p = base_params();
    p.flags |= LADDER_PID_FLAG_DIRECT;
    p.ki_x100 = 0; p.kd_x100 = 0;
    ladder_pid_disable(&p, &s);
    ladder_pid_step(&p, &s, 60, 50, false, 0, 100);
    CHECK(s.mv_m == 25000, "F: direta, PV 60 > SP 50 -> 25%");
    ladder_pid_step(&p, &s, 40, 50, false, 0, 100);
    CHECK(s.mv_m == 0, "F: direta, PV abaixo do SP -> 0%");
    printf("GOLDEN_F ok\n");

    /* Cenario G: desabilitar -> saida segura e ENO desligado. */
    p = base_params();
    p.safe_out = 30;
    ladder_pid_disable(&p, &s);
    CHECK(s.mv_m == 30000 && !s.eno, "G: EN=0 -> safe_out");

    /* Cenario H: limites de saida. */
    p = base_params();
    p.out_min = 10; p.out_max = 80; p.ki_x100 = 0; p.kd_x100 = 0;
    ladder_pid_disable(&p, &s);
    ladder_pid_step(&p, &s, 0, 100, false, 0, 100);
    CHECK(s.mv_m == 80000, "H: teto 80%");
    ladder_pid_step(&p, &s, 100, 0, false, 0, 100);
    CHECK(s.mv_m == 10000, "H: piso 10%");

    /* Validacao de parametros. */
    p = base_params();
    CHECK(ladder_pid_params_valid(&p), "params validos");
    p.out_min = 90; p.out_max = 80;
    CHECK(!ladder_pid_params_valid(&p), "out_min >= out_max invalido");

    if (g_fail) { printf("%d FALHA(S)\n", g_fail); return 1; }
    printf("PID HOST TEST OK\n");
    return 0;
}
