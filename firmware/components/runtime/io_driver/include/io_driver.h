#pragma once

#include <stdint.h>
#include <stdbool.h>

typedef struct
{
    uint16_t id;
    uint8_t level;
    uint32_t raw_edges;
    uint32_t stable_edges;
    uint32_t noise_edges;
    uint32_t recent_raw_edges;
    uint32_t recent_stable_edges;
    uint32_t recent_noise_edges;
} io_driver_input_diag_t;

void io_driver_init(void);
void io_driver_scan_inputs(void);
void io_driver_update(void);
void io_driver_process(void);
int io_driver_get_input_diag(io_driver_input_diag_t *out, int max_inputs);
bool io_driver_get_output_physical_level(uint16_t id, int32_t *out_physical_val);

/* ============================================================
   FORCE (forçamento real de E/S digitais)
   - Saídas: o GPIO segue o valor forçado, ignorando a lógica.
   - Entradas digitais: a lógica enxerga o valor forçado.
   - Fail-safe ativo bloqueia/libera forçamentos de saída.
   - Apenas RAM: tudo é liberado no reboot.
============================================================ */

#define IO_DRIVER_FORCE_MAX_ENTRIES 32

typedef enum
{
    IO_DRIVER_FORCE_OK = 0,
    IO_DRIVER_FORCE_NOT_FOUND,
    IO_DRIVER_FORCE_BLOCKED_FAILSAFE,
} io_driver_force_result_t;

typedef struct
{
    uint16_t id;
    int32_t value;
    bool is_output;
} io_driver_force_entry_t;

io_driver_force_result_t io_driver_force_set(uint16_t id, int32_t value);
io_driver_force_result_t io_driver_force_release(uint16_t id);
int io_driver_force_release_all(void);
bool io_driver_force_get(uint16_t id, int32_t *out_value);
int io_driver_force_export(io_driver_force_entry_t *out, int max_entries);

