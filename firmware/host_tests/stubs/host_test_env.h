#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_system.h"

void host_test_reset_env(void);
void host_nvs_reset(void);
bool host_nvs_corrupt_byte(const char *ns, const char *key, size_t offset);

void host_test_set_time_us(int64_t us);
void host_test_set_time_ms(int64_t ms);
void host_test_advance_ms(int64_t delta_ms);

void host_test_set_reset_reason(esp_reset_reason_t reason);

extern uint32_t g_host_io_scan_calls;
extern uint32_t g_host_io_update_calls;
extern uint32_t g_host_fieldbus_calls;
extern uint32_t g_host_automation_tick_calls;
extern uint32_t g_host_control_kernel_calls;
