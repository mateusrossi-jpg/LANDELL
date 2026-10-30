#include "scheduler_self_test.h"
#include "scheduler.h"
#include "io_command.h"
#include "io_image.h"
#include "io_driver.h"
#include "state.h"
#include "esp_log.h"

#define TAG "SCHEDULER_TEST"

#define TEST_ASSERT(cond, msg) \
    do { \
        if (!(cond)) { \
            ESP_LOGE(TAG, "Test failed at %s:%d: %s", __FILE__, __LINE__, msg); \
            return false; \
        } \
    } while (0)

bool scheduler_run_self_tests(void)
{
    ESP_LOGI(TAG, "Iniciando testes unitários do Scheduler IO Tasks...");

    /* Inicializar subsistemas necessários */
    state_init();
    io_command_init();
    io_image_init();

    /* ============================================================
       TEST 1: io_image_scan_inputs() execution during scheduler_run_io()
       ============================================================ */
    uint16_t test_input_id = 5;
    int32_t expected_val = 1234;

    /* Define input no write-buffer do io_image */
    io_image_set_input(test_input_id, expected_val);
    /* No read-buffer atual, o valor ainda deve ser 0 */
    TEST_ASSERT(io_image_get_input(test_input_id) == 0,
                "Test 1 failed: io_image input read buffer deve estar zerado antes de scan");

    /* Executa scheduler_run_io(), que chama io_driver_scan_inputs(), io_image_scan_inputs() e drena io_command */
    scheduler_run_io();

    /* Após o swap no io_image_scan_inputs(), o read-buffer deve ter recebido expected_val */
    TEST_ASSERT(io_image_get_input(test_input_id) == expected_val,
                "Test 1 failed: io_image input nao foi rotacionado por scheduler_run_io()");

    /* ============================================================
       TEST 2: io_command_pop() and state_set_int() within budget = 1
       ============================================================ */
    uint16_t cmd1_id = 10;
    int32_t cmd1_val = 100;
    uint16_t cmd2_id = 11;
    int32_t cmd2_val = 200;

    /* Enfileira 2 comandos de IO na fila de comandos */
    TEST_ASSERT(io_command_push(cmd1_id, cmd1_val), "Test 2 failed: io_command_push cmd1");
    TEST_ASSERT(io_command_push(cmd2_id, cmd2_val), "Test 2 failed: io_command_push cmd2");

    /* Primeira execução: orçamentada para 1 comando (IO_CMD_BUDGET = 1) */
    scheduler_run_io();

    int32_t state_val1 = 0;
    int32_t state_val2 = 0;
    TEST_ASSERT(state_get_int(cmd1_id, &state_val1) && state_val1 == cmd1_val,
                "Test 2 failed: cmd1 nao foi processado e aplicado ao state no primeiro tick");
    TEST_ASSERT(!state_get_int(cmd2_id, &state_val2) || state_val2 == 0,
                "Test 2 failed: cmd2 excedeu o budget e nao deveria ter sido processado no primeiro tick");

    /* Segunda execução: processa o segundo comando da fila */
    scheduler_run_io();

    TEST_ASSERT(state_get_int(cmd2_id, &state_val2) && state_val2 == cmd2_val,
                "Test 2 failed: cmd2 nao foi processado no segundo tick");

    /* ============================================================
       TEST 3: scheduler_run_io_apply() execution
       ============================================================ */
    /* Executa a fase de atuação para garantir chamada sem crash ou deadlock */
    scheduler_run_io_apply();

    ESP_LOGI(TAG, "Todos os testes unitários do Scheduler IO Tasks passaram com sucesso!");
    return true;
}
