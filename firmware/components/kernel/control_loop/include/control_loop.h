#ifndef ENDAP_CONTROL_LOOP_H
#define ENDAP_CONTROL_LOOP_H

#include <stdint.h>
#include <stdbool.h>
#include "control_loop_metrics.h"

/* start deterministic control loop */
void control_loop_start(void);

/* runtime metrics */
void control_loop_get_metrics(control_loop_metrics_t *m);

/**
 * @brief Run unit self-tests for control loop initialization, safe_time_diff, and metrics.
 * @return true if all test assertions pass, false otherwise.
 */
bool control_loop_run_self_test(void);

#endif
