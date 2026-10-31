#include "ladder_pid.h"

static int64_t clamp64(int64_t v, int64_t lo, int64_t hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

bool ladder_pid_params_valid(const ladder_pid_params_t *p)
{
    if (!p) return false;
    if (p->out_max > 100 || p->out_min >= p->out_max) return false;
    if (p->deadband_x10 > 250) return false;
    if (p->eno_threshold > 100 || p->eno_hysteresis > 100) return false;
    if (p->safe_out > 100) return false;
    return true;
}

static int32_t safe_m(const ladder_pid_params_t *p)
{
    int64_t v = (int64_t)p->safe_out * 1000;
    return (int32_t)clamp64(v, (int64_t)p->out_min * 1000, (int64_t)p->out_max * 1000);
}

void ladder_pid_disable(const ladder_pid_params_t *p, ladder_pid_state_t *s)
{
    s->initialized = false;
    s->eno = false;
    s->integ_m = 0;
    s->prev_pv_m = 0;
    s->prev_err_m = 0;
    s->d_filt = 0;
    s->mv_m = safe_m(p);
}

static void update_eno(const ladder_pid_params_t *p, ladder_pid_state_t *s)
{
    int64_t on_m = (int64_t)p->eno_threshold * 1000;
    int64_t off_m = ((int64_t)p->eno_threshold - (int64_t)p->eno_hysteresis) * 1000;
    if (off_m < 0) off_m = 0;

    if (!s->eno) {
        if (s->mv_m > on_m) s->eno = true;
    } else {
        if (s->mv_m <= off_m) s->eno = false;
    }
}

void ladder_pid_step(const ladder_pid_params_t *p,
                     ladder_pid_state_t *s,
                     int32_t pv_pct,
                     int32_t sp_pct,
                     bool manual,
                     int32_t man_pct,
                     uint32_t dt_ms)
{
    if (dt_ms == 0) dt_ms = LADDER_PID_SAMPLE_MS;

    const int64_t out_min_m = (int64_t)p->out_min * 1000;
    const int64_t out_max_m = (int64_t)p->out_max * 1000;
    const bool direct = (p->flags & LADDER_PID_FLAG_DIRECT) != 0;
    const bool d_on_error = (p->flags & LADDER_PID_FLAG_D_ON_ERROR) != 0;

    const int64_t pv_m = clamp64(pv_pct, 0, 100) * 1000;
    const int64_t sp_m = clamp64(sp_pct, 0, 100) * 1000;

    int64_t e_m = direct ? (pv_m - sp_m) : (sp_m - pv_m);
    const int64_t db_m = (int64_t)p->deadband_x10 * 100;
    if (e_m <= db_m && e_m >= -db_m) e_m = 0;

    const int64_t p_term = ((int64_t)p->kp_x100 * e_m) / 100;

    if (!s->initialized) {
        /* Transferencia sem solavanco: o integrador assume o valor que faz a
         * saida partir da saida segura (valor anterior da MV). */
        s->prev_pv_m = (int32_t)pv_m;
        s->prev_err_m = (int32_t)e_m;
        s->d_filt = 0;
        s->integ_m = (int32_t)clamp64((int64_t)safe_m(p) - p_term, out_min_m, out_max_m);
        s->mv_m = safe_m(p);
        s->initialized = true;
    }

    /* Derivada (sobre PV por padrao) com filtro de 1a ordem: alpha = 5/6 (Tf = 5*Ts). */
    int64_t d_raw;
    if (d_on_error) {
        d_raw = ((e_m - (int64_t)s->prev_err_m) * 1000) / (int64_t)dt_ms;
    } else {
        int64_t dpv = pv_m - (int64_t)s->prev_pv_m;
        if (!direct) dpv = -dpv;
        d_raw = (dpv * 1000) / (int64_t)dt_ms;
    }
    int64_t d_f = (5 * (int64_t)s->d_filt + d_raw) / 6;
    s->d_filt = (int32_t)d_f;
    s->prev_pv_m = (int32_t)pv_m;
    s->prev_err_m = (int32_t)e_m;
    const int64_t d_term = ((int64_t)p->kd_x100 * d_f) / 100;

    int64_t mv_m;
    const bool manual_active = manual && (p->flags & LADDER_PID_FLAG_MANUAL_ENABLE) != 0;
    if (manual_active) {
        mv_m = clamp64(clamp64(man_pct, 0, 100) * 1000, out_min_m, out_max_m);
        /* Rastreamento: ao voltar para AUTO a saida continua em mv_m (bumpless). */
        s->integ_m = (int32_t)clamp64(mv_m - p_term - d_term, out_min_m, out_max_m);
    } else {
        int64_t inc = ((int64_t)p->ki_x100 * e_m * (int64_t)dt_ms) / (100 * 1000);
        int64_t cand = clamp64((int64_t)s->integ_m + inc, out_min_m, out_max_m);
        int64_t u_unsat = p_term + cand + d_term;
        /* Anti-windup: integracao condicional (nao integra contra a saturacao). */
        if (!((u_unsat > out_max_m && e_m > 0) || (u_unsat < out_min_m && e_m < 0))) {
            s->integ_m = (int32_t)cand;
        }
        mv_m = clamp64(p_term + (int64_t)s->integ_m + d_term, out_min_m, out_max_m);
    }

    s->mv_m = (int32_t)mv_m;
    update_eno(p, s);
}

int32_t ladder_pid_mv_percent(const ladder_pid_state_t *s)
{
    return (s->mv_m + 500) / 1000;
}
