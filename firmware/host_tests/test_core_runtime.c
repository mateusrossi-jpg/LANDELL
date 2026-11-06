#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "host_test_env.h"
#include "io_image.h"
#include "io_map.h"
#include "state.h"
#include "event_bus.h"
#include "snapshot.h"
#include "failsafe.h"
#include "parser.h"
#include "protocol.h"

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

static int s_state_events = 0;
static uint16_t s_last_event_src = 0;
static int32_t s_last_event_data = 0;

static void on_state_event(const endap_event_t *ev)
{
    if (ev) {
        s_state_events++;
        s_last_event_src = ev->source;
        s_last_event_data = ev->data;
    }
}

/* 1. io_image.c: Isolamento deterministico de double-buffer */
static void test_io_image_double_buffer(void)
{
    io_image_init();

    io_image_set_input(10, 1);
    io_image_set_input(22, 2750);
    EXPECT(io_image_get_input(10) == 0 && io_image_get_input(22) == 0,
           "input_read isolado antes de io_image_scan_inputs()");

    io_image_scan_inputs();
    EXPECT(io_image_get_input(10) == 1 && io_image_get_input(22) == 2750,
           "io_image_scan_inputs() publica valores no read buffer");

    io_image_set_output(0, 1);
    EXPECT(io_image_get_output(0) == 0,
           "output_read isolado antes de io_image_apply_outputs()");

    io_image_apply_outputs();
    EXPECT(io_image_get_output(0) == 1,
           "io_image_apply_outputs() publica saida e limpa proximo write buffer");

    /* Novo apply sem escrever deve zerar (limpeza de ciclo deterministico) */
    io_image_apply_outputs();
    EXPECT(io_image_get_output(0) == 0,
           "write buffer limpo automaticamente para o proximo ciclo");

    /* Out-of-bounds seguro */
    io_image_set_input(999, 123);
    EXPECT(io_image_get_input(999) == 0 && io_image_get_output(999) == 0,
           "acesso fora de IO_MAX protegido");

    printf("  [PASS] io_image.c: isolamento de double-buffer de entradas e saidas\n");
}

/* 2. state.c + event_bus.c + snapshot.c (debounce, NVS restore e CRC tamper) */
static void test_state_event_bus_and_snapshot(void)
{
    host_test_reset_env();
    event_bus_init();
    state_init();
    snapshot_init();

    s_state_events = 0;
    event_bus_subscribe(EVENT_STATE_CHANGE, on_state_event);

    EXPECT(state_set_int(100, 1), "state_set_int(100, 1)");
    EXPECT(state_set_int(72, 65), "state_set_int(72, 65)");
    EXPECT(state_is_dirty(100) && state_is_dirty(72), "dirty flags marcados");

    /* Dispatch orcado: 1 evento por chamada */
    event_bus_dispatch_budgeted(1);
    EXPECT(s_state_events == 1 && s_last_event_src == 100 && s_last_event_data == 1,
           "event_bus_dispatch_budgeted(1) entrega exatamente 1 evento");

    event_bus_dispatch_budgeted(1);
    EXPECT(s_state_events == 2 && s_last_event_src == 72 && s_last_event_data == 65,
           "segundo tick drena o segundo evento");

    /* Snapshot debounce de 5000ms */
    host_test_advance_ms(4999);
    snapshot_process();
    EXPECT(state_is_dirty(100), "snapshot_process respeita debounce antes de 5000ms");

    host_test_advance_ms(1); /* 5000ms completos */
    snapshot_process();
    EXPECT(!state_is_dirty(100) && !state_is_dirty(72),
           "snapshot salvo na NVS apos 5000ms limpa dirty flags");

    /* Simula reboot e restaura snapshot da NVS */
    state_init();
    int32_t v100 = 0, v72 = 0;
    snapshot_init();
    state_get_int(100, &v100);
    state_get_int(72, &v72);
    EXPECT(v100 == 1 && v72 == 65, "snapshot_init() restaura estados persistidos na NVS");

    /* Corrupcao de 1 byte na NVS -> CRC32 deve rejeitar o snapshot corrompido! */
    EXPECT(host_nvs_corrupt_byte("snapshot", "state_v1", 14), "injeta falha de bit na NVS");
    state_init();
    snapshot_init();
    v100 = 0;
    state_get_int(100, &v100);
    EXPECT(v100 == 0, "snapshot_restore rejeita payload com CRC32 invalido");

    /* state_import_snapshot silencioso (sem eventos nem dirty) */
    event_bus_dispatch(); /* drena eventos anteriores do snapshot_restore */
    s_state_events = 0;
    int32_t raw_snap[4] = { 0, 0, 0, 777 };
    state_import_snapshot(raw_snap, 4);
    event_bus_dispatch();
    int32_t v3 = 0;
    state_get_int(3, &v3);
    EXPECT(v3 == 777 && !state_is_dirty(3) && s_state_events == 0,
           "state_import_snapshot restaura silenciosamente sem eventos nem dirty");

    printf("  [PASS] state.c + event_bus.c + snapshot.c (debounce 5s, NVS e CRC32)\n");
}

/* 3. failsafe.c: Politicas industriais, bloqueio manual, watchdog boot e CRC NVS */
static void test_failsafe_policies_and_persistence(void)
{
    host_test_reset_env();
    event_bus_init();
    state_init();

    /* Boot por Watchdog! */
    host_test_set_reset_reason(ESP_RST_TASK_WDT);
    failsafe_init();

    /* Configura Q0.0 (100): comm_loss -> SAFE_VALUE(1), runtime_fault/watchdog -> FORCE_OFF, recovery MANUAL */
    EXPECT(failsafe_set_output_policy(100,
                                      true,
                                      FAILSAFE_ACTION_FORCE_OFF,
                                      FAILSAFE_ACTION_SAFE_VALUE,
                                      FAILSAFE_ACTION_FORCE_OFF,
                                      1,
                                      FAILSAFE_RECOVERY_MANUAL),
           "configura politica fail-safe em Q0.0 com rearme manual");

    /* Dispara perda de comunicacao com Q0.0 inicialmente desligado -> vai p/ safe_value=1 e trava em MANUAL */
    state_set_int(100, 0);
    int applied = failsafe_apply_for_reason_all(FAILSAFE_REASON_COMM_LOSS);
    int32_t q0 = -1;
    state_get_int(100, &q0);
    EXPECT(applied == 6 && q0 == 1 && failsafe_is_active(100),
           "COMM_LOSS aplica safe_value=1 em Q0.0 e ativa bloqueio manual");

    /* Tentativa de comando remoto/automacao com bloqueio manual ativo -> NEGADO! */
    int32_t eff = -1;
    const char *reason = NULL;
    EXPECT(!failsafe_guard_command(100, 0, FAILSAFE_COMMAND_REMOTE, &eff, &reason),
           "failsafe_guard_command bloqueia escrita enquanto rearme manual pendente");
    EXPECT(reason && strcmp(reason, "comm_loss") == 0, "motivo reportado = comm_loss");

    /* Rearme manual libera comandos novamente */
    EXPECT(failsafe_rearm(100) && !failsafe_is_active(100), "failsafe_rearm limpa bloqueio manual");
    EXPECT(failsafe_guard_command(100, 0, FAILSAFE_COMMAND_REMOTE, &eff, &reason) && eff == 0,
           "comando permitido apos rearme manual");

    /* Verifica persistencia em NVS + rejeicao de CRC adulterado */
    failsafe_output_status_t st;
    failsafe_init(); /* recarrega da NVS */
    EXPECT(failsafe_get_output_policy(100, &st) &&
           st.comm_loss_action == FAILSAFE_ACTION_SAFE_VALUE &&
           st.safe_value == 1 &&
           st.recovery_mode == FAILSAFE_RECOVERY_MANUAL,
           "politica fail-safe restaurada da NVS com sucesso");

    EXPECT(host_nvs_corrupt_byte("failsafe", "policies", 10), "corrompe blob failsafe na NVS");
    failsafe_init();
    EXPECT(failsafe_get_output_policy(100, &st) &&
           st.comm_loss_action == FAILSAFE_ACTION_FORCE_OFF &&
           st.recovery_mode == FAILSAFE_RECOVERY_AUTO,
           "failsafe volta ao default seguro FORCE_OFF se CRC da NVS falhar");

    printf("  [PASS] failsafe.c: politicas, bloqueio manual, rearme e protecao CRC32\n");
}

/* 4. parser.c + protocol.c: Framing serial RS-485 e despacho binario */
static int s_cmd_cb_count = 0;
static protocol_output_command_t s_last_cmd;

static void on_proto_cmd(const protocol_output_command_t *msg)
{
    if (msg) {
        s_cmd_cb_count++;
        s_last_cmd = *msg;
    }
}

static void test_parser_and_protocol(void)
{
    parser_init();
    const char *stream = "lixo_antes<FRAME_1>ruido<NOVO_inicio<FRAME_2>";
    char out[32];
    int frames_found = 0;

    for (size_t i = 0; stream[i] != '\0'; i++) {
        if (parser_process_byte((uint8_t)stream[i])) {
            int len = parser_get_frame((uint8_t *)out, sizeof(out) - 1);
            out[len] = '\0';
            frames_found++;
            if (frames_found == 1) {
                EXPECT(strcmp(out, "FRAME_1") == 0, "parser extrai primeiro quadro limpo");
            } else if (frames_found == 2) {
                EXPECT(strcmp(out, "FRAME_2") == 0, "parser reinicia quadro ao ver novo '<'");
            }
        }
    }
    EXPECT(frames_found == 2, "parser processou exatamente 2 quadros completos");

    protocol_init();
    s_cmd_cb_count = 0;
    protocol_register_output_command_callback(on_proto_cmd);

    /* Quadro truncado ignorado */
    uint8_t tiny[3] = { PROTOCOL_MSG_OUTPUT_COMMAND, 0, 1 };
    protocol_process_frame(tiny, sizeof(tiny));
    EXPECT(s_cmd_cb_count == 0, "protocol ignora quadro menor que sizeof(protocol_msg_t)");

    protocol_msg_t msg;
    memset(&msg, 0, sizeof(msg));
    msg.type = PROTOCOL_MSG_OUTPUT_COMMAND;
    msg.data.output_command.target_node = 2;
    msg.data.output_command.requester_node = 1;
    msg.data.output_command.output_id = 103;
    msg.data.output_command.value = 1;
    protocol_process_frame((const uint8_t *)&msg, sizeof(msg));

    EXPECT(s_cmd_cb_count == 1 &&
           s_last_cmd.target_node == 2 &&
           s_last_cmd.output_id == 103 &&
           s_last_cmd.value == 1,
           "protocol despacha PROTOCOL_MSG_OUTPUT_COMMAND corretamente");

    printf("  [PASS] parser.c + protocol.c: enquadramento RS-485 e mensagens binarias\n");
}

int main(void)
{
    printf("=== [4/4] Core Runtime, I/O Image, Snapshot, Fail-Safe & Protocol Suite ===\n");
    test_io_image_double_buffer();
    test_state_event_bus_and_snapshot();
    test_failsafe_policies_and_persistence();
    test_parser_and_protocol();

    if (g_failures > 0) {
        printf("CORE RUNTIME SUITE FAILED (%d/%d checks failed)\n", g_failures, g_checks);
        return 1;
    }
    printf("CORE RUNTIME SUITE OK (%d assertions passed)\n", g_checks);
    return 0;
}
