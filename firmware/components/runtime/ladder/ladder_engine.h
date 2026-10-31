#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t ladder_engine_init(void);

esp_err_t ladder_engine_load_program(const uint8_t *buffer, size_t length);

esp_err_t ladder_engine_clear(void);

void ladder_engine_run(void);

bool ladder_engine_run_self_test(void);

size_t ladder_engine_get_program(uint8_t *out_buf, size_t max_len);

bool ladder_engine_get_timer_state(uint16_t tag_id, bool *out_active, int64_t *out_elapsed_ms);

#ifdef __cplusplus
}
#endif
