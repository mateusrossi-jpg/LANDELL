#pragma once

/*
 * ENDAP - Bloco PID industrial (aritmetica inteira, sem FPU, deterministica).
 *
 * Forma ISA "paralela":  u = Kp*e + Ki*Integral(e dt) + Kd*d(PV)/dt
 *   - Unidades: PV, SP e MV em PORCENTAGEM (0..100 %); tempo em segundos.
 *   - Resolucao interna: milesimos de porcento (1 unidade = 0,001 %).
 *   - Ganhos recebidos x100 (ex.: Kp = 2,50  ->  kp_x100 = 250).
 *
 * Recursos industriais:
 *   - Acao reversa (padrao: MV sobe quando PV cai) ou direta (MV sobe quando PV sobe).
 *   - Derivada sobre o PV (sem "derivative kick") com filtro passa-baixa de 1a ordem.
 *   - Anti-windup por integracao condicional + limite do integrador.
 *   - Limites de saida configuraveis (out_min / out_max).
 *   - Banda morta (deadband) sobre o erro.
 *   - Modo MANUAL com rastreamento do integrador (transferencia sem solavanco / bumpless).
 *   - Transferencia sem solavanco tambem na habilitacao (EN) a partir da saida segura.
 *   - Saida segura (safe_out) aplicada quando o bloco e desabilitado (EN = 0).
 *   - Pino ENO com limiar e histerese (evita trepidar rele quando usado como liga/desliga).
 *
 * Este arquivo nao depende do ESP-IDF para poder ser testado no PC (gcc).
 */

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LADDER_PID_FLAG_DIRECT        0x01 /* 0 = acao reversa, 1 = acao direta   */
#define LADDER_PID_FLAG_D_ON_ERROR    0x02 /* 0 = derivada sobre PV, 1 = sobre erro */
#define LADDER_PID_FLAG_MANUAL_ENABLE 0x04 /* bloco possui chave Auto/Manual        */

#define LADDER_PID_SAMPLE_MS 100u

typedef struct {
    uint16_t kp_x100;
    uint16_t ki_x100;
    uint16_t kd_x100;
    uint8_t flags;
    uint8_t out_min;       /* 0..100 % */
    uint8_t out_max;       /* 0..100 % */
    uint8_t deadband_x10;  /* 0..250  -> 0,0..25,0 % */
    uint8_t eno_threshold; /* 0..100 % */
    uint8_t eno_hysteresis;/* 0..100 % */
    uint8_t safe_out;      /* 0..100 % */
} ladder_pid_params_t;

typedef struct {
    bool initialized;
    bool eno;
    int32_t integ_m;    /* termo integral em milesimos de % de saida */
    int32_t prev_pv_m;
    int32_t prev_err_m;
    int32_t d_filt;     /* derivada filtrada (milesimos de %/s) */
    int32_t mv_m;       /* ultima saida (milesimos de %) */
} ladder_pid_state_t;

/* Retorna true se os parametros sao coerentes (usado na validacao do bytecode). */
bool ladder_pid_params_valid(const ladder_pid_params_t *p);

/* Bloco desabilitado (EN = 0): saida vai para safe_out e o estado e rearmado. */
void ladder_pid_disable(const ladder_pid_params_t *p, ladder_pid_state_t *s);

/*
 * Executa uma amostra do PID.
 *   pv_pct, sp_pct : PV e SP em % inteiros (0..100)
 *   manual         : true = modo manual
 *   man_pct        : saida manual em % (usada se manual = true)
 *   dt_ms          : tempo desde a ultima amostra (ms), > 0
 * Resultado em s->mv_m (milesimos de %) e s->eno.
 */
void ladder_pid_step(const ladder_pid_params_t *p,
                     ladder_pid_state_t *s,
                     int32_t pv_pct,
                     int32_t sp_pct,
                     bool manual,
                     int32_t man_pct,
                     uint32_t dt_ms);

/* MV arredondado para % inteiro (0..100). */
int32_t ladder_pid_mv_percent(const ladder_pid_state_t *s);

#ifdef __cplusplus
}
#endif
