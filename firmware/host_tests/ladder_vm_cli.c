/* CLI deterministico da VM Ladder real em C (ladder_engine.c + ladder_pid.c + state.c)
 * Usado pelos testes de paridade cruzada do Flutter Studio para validar que o
 * BytecodeCompiler (Dart) + LadderSimulator (Dart) produzem exatamente o mesmo
 * estado que o firmware real do ESP32 ciclo a ciclo!
 *
 * Protocolo de entrada (stdin, linhas de texto):
 *   LOAD <hex_bytes_sem_espacos>
 *   SET <id> <val>
 *   ADVANCE <ms>
 *   STEP [<count>]
 *   QUERY <id1> [<id2> ...]
 *   QUIT
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "host_test_env.h"
#include "state.h"
#include "event_bus.h"
#include "snapshot.h"
#include "ladder_engine.h"

static int hex_nibble(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
    if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
    return -1;
}

int main(void)
{
    host_test_reset_env();
    event_bus_init();
    state_init();
    snapshot_init();
    ladder_engine_init();

    char line[8192];
    while (fgets(line, sizeof(line), stdin) != NULL) {
        char *nl = strpbrk(line, "\r\n");
        if (nl) *nl = '\0';
        if (line[0] == '\0' || line[0] == '#') continue;

        if (strncmp(line, "LOAD ", 5) == 0) {
            const char *hex = line + 5;
            while (*hex == ' ') hex++;
            size_t hex_len = strlen(hex);
            uint8_t buf[2048];
            size_t out_len = 0;
            bool ok = (hex_len % 2 == 0) && (hex_len / 2 <= sizeof(buf));
            for (size_t i = 0; ok && i < hex_len; i += 2) {
                int hi = hex_nibble(hex[i]);
                int lo = hex_nibble(hex[i + 1]);
                if (hi < 0 || lo < 0) { ok = false; break; }
                buf[out_len++] = (uint8_t)((hi << 4) | lo);
            }
            if (!ok) {
                printf("ERR HEX\n");
            } else {
                esp_err_t err = ladder_engine_load_program(buf, out_len);
                if (err == ESP_OK) printf("OK LOAD %zu\n", out_len);
                else printf("ERR LOAD %d\n", (int)err);
            }
            fflush(stdout);
        } else if (strncmp(line, "SET ", 4) == 0) {
            unsigned int id = 0;
            int val = 0;
            if (sscanf(line + 4, "%u %d", &id, &val) == 2) {
                state_set_int((uint16_t)id, (int32_t)val);
                printf("OK SET\n");
            } else {
                printf("ERR SET\n");
            }
            fflush(stdout);
        } else if (strncmp(line, "ADVANCE ", 8) == 0) {
            long long ms = atoll(line + 8);
            host_test_advance_ms((int64_t)ms);
            printf("OK ADVANCE\n");
            fflush(stdout);
        } else if (strncmp(line, "STEP", 4) == 0) {
            int count = 1;
            if (line[4] == ' ') count = atoi(line + 5);
            if (count < 1) count = 1;
            for (int i = 0; i < count; i++) {
                ladder_engine_run();
            }
            printf("OK STEP %d\n", count);
            fflush(stdout);
        } else if (strncmp(line, "QUERY ", 6) == 0) {
            printf("STATE");
            char *p = line + 6;
            char *tok = strtok(p, " \t");
            while (tok != NULL) {
                uint16_t id = (uint16_t)atoi(tok);
                int32_t val = 0;
                state_get_int(id, &val);
                printf(" %u=%d", (unsigned int)id, (int)val);
                tok = strtok(NULL, " \t");
            }
            printf("\n");
            fflush(stdout);
        } else if (strcmp(line, "RESET") == 0) {
            host_test_reset_env();
            event_bus_init();
            state_init();
            snapshot_init();
            ladder_engine_init();
            printf("OK RESET\n");
            fflush(stdout);
        } else if (strcmp(line, "QUIT") == 0) {
            break;
        }
    }
    return 0;
}
