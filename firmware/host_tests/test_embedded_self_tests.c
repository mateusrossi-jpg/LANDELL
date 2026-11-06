#include <stdio.h>
#include <stdlib.h>

#include "host_test_env.h"
#include "state.h"
#include "event_bus.h"
#include "snapshot.h"
#include "ladder_engine.h"
#include "pve.h"
#include "pve_self_test.h"
#include "scheduler_self_test.h"

int main(void)
{
    int failures = 0;

    printf("=== [1/4] Firmware Embedded Self-Tests (Host Execution) ===\n");

    /* 1. Ladder Engine Self-Test */
    host_test_reset_env();
    event_bus_init();
    state_init();
    snapshot_init();
    ladder_engine_init();

    if (ladder_engine_run_self_test()) {
        printf("  [PASS] ladder_engine_run_self_test() (Contrato X0 -> Y0 + NVS restore)\n");
    } else {
        printf("  [FAIL] ladder_engine_run_self_test()\n");
        failures++;
    }

    /* 2. PVE Industrial Scaling, NVS CRC & Alarm Hysteresis Self-Tests (11 tests + 2 audits) */
    host_test_reset_env();
    event_bus_init();
    state_init();
    pve_init_variables();

    if (pve_run_self_tests()) {
        printf("  [PASS] pve_run_self_tests() (11 testes de escala 4-20mA/capacitivo + NVS CRC + 2 auditorias de alarme)\n");
    } else {
        printf("  [FAIL] pve_run_self_tests()\n");
        failures++;
    }

    /* 3. Kernel Scheduler IO Phase & Budgeted Command Queue Self-Tests */
    host_test_reset_env();
    event_bus_init();

    if (scheduler_run_self_tests()) {
        printf("  [PASS] scheduler_run_self_tests() (io_image swap + IO_CMD_BUDGET=1 + io_apply)\n");
    } else {
        printf("  [FAIL] scheduler_run_self_tests()\n");
        failures++;
    }

    if (failures > 0) {
        printf("EMBEDDED SELF-TESTS FAILED (%d)\n", failures);
        return 1;
    }
    printf("EMBEDDED SELF-TESTS OK (3/3 suites)\n");
    return 0;
}
