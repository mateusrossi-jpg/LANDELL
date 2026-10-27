#include "ladder_engine.h"
#include <string.h>
#include <inttypes.h>
#include "esp_log.h"
#include "state.h"
#include "io_map.h"
#include "esp_attr.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_timer.h"

static const char *TAG = "ladder";

#define LADDER_MAX_PROGRAM_SIZE 2048

static uint8_t s_bytecode[LADDER_MAX_PROGRAM_SIZE];
static size_t s_bytecode_length = 0;
static bool s_has_program = false;

// OPCODES correspondentes ao compilador do Studio
#define OP_LD             0x01
#define OP_LDN            0x02
#define OP_AND            0x03
#define OP_ANDN           0x04
#define OP_OR             0x05
#define OP_ORN            0x06
#define OP_ST             0x10
#define OP_SET            0x11
#define OP_RST            0x12
#define OP_OR_BLOCK_START 0x20
#define OP_OR_BLOCK_NEXT  0x21
#define OP_OR_BLOCK_END   0x22
#define OP_TON            0x30
#define OP_TOF            0x31
#define OP_CTU            0x32
#define OP_CTD            0x33
#define OP_EQU            0x40
#define OP_GRT            0x41
#define OP_LES            0x42
#define OP_ADD            0x50
#define OP_SUB            0x51
#define OP_MUL            0x52
#define OP_DIV            0x53
#define OP_PID            0x60

#define MAX_TIMERS 16
#define MAX_COUNTERS 16
#define MAX_PIDS 4
#define MAX_STACK 16

typedef struct {
    uint16_t tag_id;
    bool active;
    bool last_acc;
    int64_t start_time_ms;
} timer_state_t;

typedef struct {
    uint16_t tag_id;
    bool last_acc;
    int32_t current_count;
} counter_state_t;

typedef struct {
    uint16_t pv_tag_id;
    int32_t last_error;
    int32_t integral; // acumulador integral com escala x100
    int32_t last_mv;  // última saída calculada MV (0..100%)
    int64_t last_time_ms;
} pid_state_t;

static timer_state_t s_timers[MAX_TIMERS];
static size_t s_timer_count = 0;
static counter_state_t s_counters[MAX_COUNTERS];
static size_t s_counter_count = 0;
static pid_state_t s_pids[MAX_PIDS];
static size_t s_pid_count = 0;

static pid_state_t* get_or_create_pid(uint16_t pv_tag_id) {
    for (size_t i = 0; i < s_pid_count; i++) {
        if (s_pids[i].pv_tag_id == pv_tag_id) return &s_pids[i];
    }
    if (s_pid_count < MAX_PIDS) {
        s_pids[s_pid_count].pv_tag_id = pv_tag_id;
        s_pids[s_pid_count].last_error = 0;
        s_pids[s_pid_count].integral = 0;
        s_pids[s_pid_count].last_mv = 0;
        s_pids[s_pid_count].last_time_ms = 0;
        return &s_pids[s_pid_count++];
    }
    return NULL;
}

static timer_state_t* get_or_create_timer(uint16_t tag_id) {
    for (size_t i = 0; i < s_timer_count; i++) {
        if (s_timers[i].tag_id == tag_id) return &s_timers[i];
    }
    if (s_timer_count < MAX_TIMERS) {
        s_timers[s_timer_count].tag_id = tag_id;
        s_timers[s_timer_count].active = false;
        s_timers[s_timer_count].last_acc = false;
        s_timers[s_timer_count].start_time_ms = 0;
        return &s_timers[s_timer_count++];
    }
    return NULL;
}

static counter_state_t* get_or_create_counter(uint16_t tag_id) {
    for (size_t i = 0; i < s_counter_count; i++) {
        if (s_counters[i].tag_id == tag_id) return &s_counters[i];
    }
    if (s_counter_count < MAX_COUNTERS) {
        s_counters[s_counter_count].tag_id = tag_id;
        s_counters[s_counter_count].last_acc = false;
        s_counters[s_counter_count].current_count = 0;
        return &s_counters[s_counter_count++];
    }
    return NULL;
}

static void reset_timer_or_counter(uint16_t tag_id)
{
    for (size_t i = 0; i < s_timer_count; i++) {
        if (s_timers[i].tag_id == tag_id) {
            s_timers[i].active = false;
            s_timers[i].last_acc = false;
            s_timers[i].start_time_ms = 0;
            break;
        }
    }
    for (size_t i = 0; i < s_counter_count; i++) {
        if (s_counters[i].tag_id == tag_id) {
            s_counters[i].last_acc = false;
            s_counters[i].current_count = 0;
            break;
        }
    }
}

esp_err_t ladder_engine_init(void)
{
    s_bytecode_length = 0;
    s_has_program = false;
    s_timer_count = 0;
    s_counter_count = 0;
    s_pid_count = 0;
    memset(s_bytecode, 0, sizeof(s_bytecode));
    memset(s_timers, 0, sizeof(s_timers));
    memset(s_counters, 0, sizeof(s_counters));
    memset(s_pids, 0, sizeof(s_pids));

    // Zera saídas físicas (Q0.0..Q0.7), memórias (M), timers (T), counters (C) e saídas analógicas (AO)
    // para evitar que bobinas removidas no novo programa permaneçam travadas em nível alto
    for (uint16_t id = 100; id <= 107; id++) state_set_int(id, 0);
    for (uint16_t id = 26; id <= 71; id++) state_set_int(id, 0);
    state_set_int(80, 0);
    state_set_int(81, 0);

    // Load from NVS
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("endap_ladder", NVS_READONLY, &my_handle);
    if (err == ESP_OK) {
        size_t required_size = 0;
        err = nvs_get_blob(my_handle, "bytecode", NULL, &required_size);
        if (err == ESP_OK && required_size > 0 && required_size <= LADDER_MAX_PROGRAM_SIZE) {
            err = nvs_get_blob(my_handle, "bytecode", s_bytecode, &required_size);
            if (err == ESP_OK) {
                s_bytecode_length = required_size;
                s_has_program = true;
                ESP_LOGI(TAG, "Restored %zu bytes of bytecode from NVS.", required_size);
            }
        }
        nvs_close(my_handle);
    } else {
        ESP_LOGI(TAG, "No bytecode found in NVS (or NVS not initialized).");
    }

    ESP_LOGI(TAG, "Ladder Bytecode Engine Initialized.");
    return ESP_OK;
}

esp_err_t ladder_engine_clear(void)
{
    s_has_program = false;
    s_bytecode_length = 0;
    s_timer_count = 0;
    s_counter_count = 0;
    s_pid_count = 0;
    memset(s_bytecode, 0, sizeof(s_bytecode));
    memset(s_timers, 0, sizeof(s_timers));
    memset(s_counters, 0, sizeof(s_counters));
    memset(s_pids, 0, sizeof(s_pids));

    // Zera saídas físicas (Q0.0..Q0.7), memórias (M), timers (T), counters (C) e saídas analógicas (AO)
    // para evitar que bobinas removidas no novo programa permaneçam travadas em nível alto
    for (uint16_t id = 100; id <= 107; id++) state_set_int(id, 0);
    for (uint16_t id = 26; id <= 71; id++) state_set_int(id, 0);
    state_set_int(80, 0);
    state_set_int(81, 0);

    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("endap_ladder", NVS_READWRITE, &my_handle);
    if (err == ESP_OK) {
        nvs_erase_key(my_handle, "bytecode");
        nvs_commit(my_handle);
        nvs_close(my_handle);
        ESP_LOGI(TAG, "Ladder bytecode cleared from NVS.");
    }
    return ESP_OK;
}

esp_err_t ladder_engine_load_program(const uint8_t *buffer, size_t length)
{
    if (length > LADDER_MAX_PROGRAM_SIZE) {
        return ESP_ERR_NO_MEM;
    }
    
    // Check Header "ENDP"
    if (length < 5 || buffer[0] != 0x45 || buffer[1] != 0x4E || buffer[2] != 0x44 || buffer[3] != 0x50) {
        ESP_LOGE(TAG, "Invalid Bytecode Header");
        return ESP_ERR_INVALID_ARG;
    }

    // Pass 1: Validate opcodes and limit check timers/counters
    size_t pc = 5;
    size_t unique_timers = 0;
    size_t unique_counters = 0;
    uint16_t timer_tags[MAX_TIMERS];
    uint16_t counter_tags[MAX_COUNTERS];

    while (pc < length) {
        uint8_t op = buffer[pc++];
        if (op == 0xFF) break;

        if ((op >= OP_LD && op <= OP_ORN) || (op >= OP_ST && op <= OP_RST)) {
            if (pc + 1 >= length) return ESP_ERR_INVALID_ARG;
            pc += 2;
        } else if (op >= OP_OR_BLOCK_START && op <= OP_OR_BLOCK_END) {
            // Stack instructions (no operand)
        } else if (op == OP_TON || op == OP_TOF) {
            if (pc + 1 >= length) return ESP_ERR_INVALID_ARG;
            uint16_t tag_id = (buffer[pc] << 8) | buffer[pc + 1];
            pc += 2;
            if (pc + 1 >= length) return ESP_ERR_INVALID_ARG; // preset_ms (uint16_t)
            pc += 2;

            bool exists = false;
            for (size_t i = 0; i < unique_timers; i++) {
                if (timer_tags[i] == tag_id) { exists = true; break; }
            }
            if (!exists) {
                if (unique_timers >= MAX_TIMERS) {
                    ESP_LOGE(TAG, "Exceeded MAX_TIMERS limit (%d)", MAX_TIMERS);
                    return ESP_ERR_NO_MEM;
                }
                timer_tags[unique_timers++] = tag_id;
            }
        } else if (op == OP_CTU || op == OP_CTD) {
            if (pc + 1 >= length) return ESP_ERR_INVALID_ARG;
            uint16_t tag_id = (buffer[pc] << 8) | buffer[pc + 1];
            pc += 2;
            if (pc + 1 >= length) return ESP_ERR_INVALID_ARG; // preset_cnt (uint16_t)
            pc += 2;

            bool exists = false;
            for (size_t i = 0; i < unique_counters; i++) {
                if (counter_tags[i] == tag_id) { exists = true; break; }
            }
            if (!exists) {
                if (unique_counters >= MAX_COUNTERS) {
                    ESP_LOGE(TAG, "Exceeded MAX_COUNTERS limit (%d)", MAX_COUNTERS);
                    return ESP_ERR_NO_MEM;
                }
                counter_tags[unique_counters++] = tag_id;
            }
        } else if (op >= OP_EQU && op <= OP_LES) {
            if (pc + 3 >= length) return ESP_ERR_INVALID_ARG;
            pc += 4;
        } else if (op >= OP_ADD && op <= OP_DIV) {
            if (pc + 6 >= length) return ESP_ERR_INVALID_ARG;
            uint8_t flags_b = buffer[pc + 2];
            if (flags_b != 0x00 && flags_b != 0x01) {
                ESP_LOGE(TAG, "Invalid math flags_b 0x%02X at offset %zu", flags_b, pc + 2);
                return ESP_ERR_INVALID_ARG;
            }
            pc += 7;
        } else if (op == OP_PID) {
            // pv(2) + sp(2) + mv(2) + kp(2) + ki(2) + kd(2) = 12 bytes
            if (pc + 11 >= length) return ESP_ERR_INVALID_ARG;
            pc += 12;
        } else {
            ESP_LOGE(TAG, "Unknown Opcode 0x%02X at offset %zu", op, pc - 1);
            return ESP_ERR_INVALID_ARG;
        }
    }

    // Pass 2: Save and initialize structures
    ladder_engine_clear();
    memcpy(s_bytecode, buffer, length);
    s_bytecode_length = length;
    s_has_program = true;
    
    // Save to NVS
    nvs_handle_t my_handle;
    esp_err_t err = nvs_open("endap_ladder", NVS_READWRITE, &my_handle);
    if (err == ESP_OK) {
        nvs_set_blob(my_handle, "bytecode", s_bytecode, s_bytecode_length);
        nvs_commit(my_handle);
        nvs_close(my_handle);
        ESP_LOGI(TAG, "Ladder program saved to NVS, size: %zu bytes", length);
    } else {
        ESP_LOGE(TAG, "Failed to open NVS to save bytecode.");
    }

    return ESP_OK;
}

size_t ladder_engine_get_program(uint8_t *out_buf, size_t max_len)
{
    if (!s_has_program || out_buf == NULL || max_len == 0) return 0;
    size_t copy_len = (s_bytecode_length < max_len) ? s_bytecode_length : max_len;
    memcpy(out_buf, s_bytecode, copy_len);
    return copy_len;
}

// Rodar no HOT PATH - IRAM_ATTR para garantir determinismo
void IRAM_ATTR ladder_engine_run(void)
{
    if (!s_has_program || s_bytecode_length < 5) return;

    bool accumulator = true;
    
    // Branch stacks
    bool logic_stack[MAX_STACK];
    bool or_stack[MAX_STACK];
    int stack_ptr = 0;

    size_t pc = 5; // Pula Header (4 bytes) + Versão (1 byte)
    int64_t now_ms = esp_timer_get_time() / 1000;

    while (pc < s_bytecode_length) {
        uint8_t opcode = s_bytecode[pc++];
        
        if (opcode == 0xFF) {
            break; // Terminator
        }

        // Handle no-operand branch stack instructions
        if (opcode == OP_OR_BLOCK_START) {
            if (stack_ptr < MAX_STACK) {
                logic_stack[stack_ptr] = accumulator;
                or_stack[stack_ptr] = false;
                stack_ptr++;
            }
            continue;
        } else if (opcode == OP_OR_BLOCK_NEXT) {
            if (stack_ptr > 0) {
                or_stack[stack_ptr - 1] = or_stack[stack_ptr - 1] || accumulator;
                accumulator = logic_stack[stack_ptr - 1];
            }
            continue;
        } else if (opcode == OP_OR_BLOCK_END) {
            if (stack_ptr > 0) {
                or_stack[stack_ptr - 1] = or_stack[stack_ptr - 1] || accumulator;
                accumulator = or_stack[stack_ptr - 1];
                stack_ptr--;
            }
            continue;
        }

        if (pc + 1 >= s_bytecode_length) break; // Safety check for operand

        if (opcode >= OP_ADD && opcode <= OP_DIV) {
            uint16_t tag_a_id = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
            pc += 2;
            if (pc + 4 >= s_bytecode_length) break;
            uint8_t flags_b = s_bytecode[pc];
            uint16_t operand_b_raw = (s_bytecode[pc + 1] << 8) | s_bytecode[pc + 2];
            uint16_t dest_tag_id = (s_bytecode[pc + 3] << 8) | s_bytecode[pc + 4];
            pc += 5;

            if (accumulator) {
                int32_t valA = 0;
                int32_t valB = 0;
                state_get_int(tag_a_id, &valA);
                if (flags_b == 0x00) {
                    state_get_int(operand_b_raw, &valB);
                } else if (flags_b == 0x01) {
                    valB = (int16_t)operand_b_raw;
                }

                int64_t res64 = 0;
                if (opcode == OP_ADD) {
                    res64 = (int64_t)valA + (int64_t)valB;
                } else if (opcode == OP_SUB) {
                    res64 = (int64_t)valA - (int64_t)valB;
                } else if (opcode == OP_MUL) {
                    res64 = (int64_t)valA * (int64_t)valB;
                } else if (opcode == OP_DIV) {
                    if (valB == 0) {
                        res64 = 0;
                    } else {
                        res64 = (int64_t)valA / (int64_t)valB;
                    }
                }

                if (res64 > 2147483647LL) res64 = 2147483647LL;
                if (res64 < -2147483648LL) res64 = -2147483648LL;

                state_set_int(dest_tag_id, (int32_t)res64);
            }
            continue;
        }

        if (opcode == OP_PID) {
            if (pc + 11 >= s_bytecode_length) break;
            uint16_t pv_tag_id = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
            uint16_t sp_tag_id = (s_bytecode[pc + 2] << 8) | s_bytecode[pc + 3];
            uint16_t mv_tag_id = (s_bytecode[pc + 4] << 8) | s_bytecode[pc + 5];
            uint16_t kp_scaled = (s_bytecode[pc + 6] << 8) | s_bytecode[pc + 7];
            uint16_t ki_scaled = (s_bytecode[pc + 8] << 8) | s_bytecode[pc + 9];
            uint16_t kd_scaled = (s_bytecode[pc + 10] << 8) | s_bytecode[pc + 11];
            pc += 12;

            // Proteção caso o usuário tenha invertido PV (colocando Q0.x = 100..115) e MV (colocando AI0.x = 72..79)
            if ((pv_tag_id >= 100 && pv_tag_id <= 115) && (mv_tag_id >= 72 && mv_tag_id <= 79)) {
                pv_tag_id = mv_tag_id;
                mv_tag_id = 33; // M0.7 (MV_PID)
            } else if (mv_tag_id >= 72 && mv_tag_id <= 79) {
                // Nunca sobrescrever registradores físicos de entrada analógica (AI0.0..AI0.3 = 72..75)
                mv_tag_id = 33; // M0.7 (MV_PID)
            }

            // Se pv_tag_id apontar para canal físico bruto (22..25), redireciona para registrador escalonado 0..100% (72..75)
            if (pv_tag_id >= 22 && pv_tag_id <= 25) {
                pv_tag_id = (uint16_t)(72 + (pv_tag_id - 22));
            }

            pid_state_t *p = get_or_create_pid(pv_tag_id);
            int32_t current_mv = p ? p->last_mv : 0;

            if (accumulator) {
                int32_t pv = 0;
                int32_t sp = 50;
                state_get_int(pv_tag_id, &pv);

                if ((sp_tag_id & 0x8000) != 0) {
                    // Constante literal codificada com bit 15 (ex: 50 -> 50%)
                    sp = (int32_t)(sp_tag_id & 0x7FFF);
                    if (sp > 100 && sp <= 4095) {
                        if (sp >= 3800) sp = 5;
                        else if (sp <= 1500) sp = 95;
                        else sp = ((3800 - sp) * 100) / (3800 - 1500);
                    }
                    if (sp < 1) sp = 1;
                    if (sp > 100) sp = 100;
                } else if (sp_tag_id > 100 && sp_tag_id <= 4095) {
                    // Caso o compilador legado tenha enviado um número literal > 100 (ex: 4000)
                    sp = 50;
                } else {
                    state_get_int(sp_tag_id, &sp);
                    if (sp_tag_id > 0 && (sp <= 5 || sp > 100)) {
                        sp = 50;
                        state_set_int(sp_tag_id, 50);
                    }
                }

                if (p) {
                    int64_t dt_ms = now_ms - p->last_time_ms;
                    if (dt_ms >= 100 || p->last_time_ms == 0) {
                        if (p->last_time_ms == 0 || dt_ms > 1000) dt_ms = 100;
                        p->last_time_ms = now_ms;

                        // Erro de Controle para Irrigação:
                        // Quanto mais SECO (PV baixo), maior o erro -> Relé LIGA para irrigar.
                        // Quando estiver ÚMIDO (PV >= SP), erro <= 0 -> Relé DESLIGA imediatamente.
                        int32_t error = sp - pv;

                        // Proporcional: (Kp * error) / 100
                        int32_t p_term = ((int32_t)kp_scaled * error) / 100;

                        // Integral com Anti-Windup e descarga imediata ao atingir o Setpoint (error <= 0):
                        if (error <= 0) {
                            p->integral = 0;
                        } else {
                            p->integral += (error * (int32_t)dt_ms) / 1000;
                            if (p->integral > 200) p->integral = 200;
                            if (p->integral < 0) p->integral = 0;
                        }
                        int32_t i_term = ((int32_t)ki_scaled * p->integral) / 100;

                        // Derivativo
                        int32_t d_term = 0;
                        if (dt_ms > 0) {
                            d_term = (((int32_t)kd_scaled * (error - p->last_error) * 1000) / (int32_t)dt_ms) / 100;
                        }
                        p->last_error = error;

                        int32_t mv = p_term + i_term + d_term;
                        if (mv < 0) mv = 0;
                        if (mv > 100) mv = 100;

                        p->last_mv = mv;
                        current_mv = mv;
                    }

                    if (mv_tag_id >= 100 && mv_tag_id <= 115) {
                        // Se MV apontar direto para uma saída digital Q0.x, atua como chave (MV > 20% = ON)
                        state_set_int(mv_tag_id, (current_mv > 20) ? 1 : 0);
                    } else {
                        state_set_int(mv_tag_id, current_mv);
                    }
                    // Espelha sempre em M0.7 (33 = MV_PID) para telemetria na IHM/Studio
                    if (mv_tag_id != 33) {
                        state_set_int(33, current_mv);
                    }
                    // Se MV for MV_PID (33) ou AO0.0 (80), espelha na saída analógica proporcional AO0.0 (GPIO 25 / DAC1)
                    if ((mv_tag_id == 33 || mv_tag_id == 80) && mv_tag_id != 80) {
                        state_set_int(80, current_mv);
                    }
                }
            } else {
                // Rung desenergizada antes do PID: zera saída e acumulador
                if (p) {
                    p->integral = 0;
                    p->last_error = 0;
                    p->last_mv = 0;
                }
                current_mv = 0;
                state_set_int(mv_tag_id, 0);
                if (mv_tag_id != 33) {
                    state_set_int(33, 0);
                }
                if (mv_tag_id == 33 || mv_tag_id == 80) {
                    state_set_int(80, 0);
                }
            }

            // Verifica se há uma Bobina ou instrução em série nesta mesma Rung após o bloco PID (pino ENO)
            uint8_t next_op = (pc < s_bytecode_length) ? s_bytecode[pc] : 0xFF;
            bool has_downstream_on_rung = (next_op == OP_ST || next_op == OP_SET || next_op == OP_RST ||
                                           next_op == OP_AND || next_op == OP_ANDN ||
                                           next_op == OP_TON || next_op == OP_TOF ||
                                           next_op == OP_CTU || next_op == OP_CTD);
            if (has_downstream_on_rung) {
                // Pino ENO conduz energia para a Bobina quando MV > 20% (solo seco) e corta quando MV <= 20% (úmido/água)
                accumulator = accumulator && (current_mv > 20);
            } else {
                accumulator = true; // Reseta power flow para a próxima rung
            }
            continue;
        }

        uint16_t tag_id = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
        pc += 2;

        int32_t val = 0;
        state_get_int(tag_id, &val);
        bool tag_val = (val > 0);

        switch (opcode) {
            case OP_LD:   accumulator = tag_val; break;
            case OP_LDN:  accumulator = !tag_val; break;
            case OP_AND:  accumulator = accumulator && tag_val; break;
            case OP_ANDN: accumulator = accumulator && !tag_val; break;
            case OP_OR:   accumulator = accumulator || tag_val; break;
            case OP_ORN:  accumulator = accumulator || !tag_val; break;
            case OP_ST: {
                state_set_int(tag_id, accumulator ? 1 : 0);
                uint8_t next_op = (pc < s_bytecode_length) ? s_bytecode[pc] : 0xFF;
                if (next_op != OP_ST && next_op != OP_SET && next_op != OP_RST) {
                    accumulator = true; // Reseta power flow apenas quando iniciar uma nova rung
                }
                break;
            }
            case OP_SET: {
                if (accumulator) state_set_int(tag_id, 1);
                uint8_t next_op = (pc < s_bytecode_length) ? s_bytecode[pc] : 0xFF;
                if (next_op != OP_ST && next_op != OP_SET && next_op != OP_RST) {
                    accumulator = true; // Reseta power flow apenas quando iniciar uma nova rung
                }
                break;
            }
            case OP_RST: {
                if (accumulator) {
                    state_set_int(tag_id, 0);
                    reset_timer_or_counter(tag_id);
                }
                uint8_t next_op = (pc < s_bytecode_length) ? s_bytecode[pc] : 0xFF;
                if (next_op != OP_ST && next_op != OP_SET && next_op != OP_RST) {
                    accumulator = true; // Reseta power flow apenas quando iniciar uma nova rung
                }
                break;
            }

            case OP_TON: {
                if (pc + 1 >= s_bytecode_length) break;
                uint16_t preset_ms = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
                pc += 2;

                timer_state_t *t = get_or_create_timer(tag_id);
                if (!t) break;

                if (accumulator) {
                    if (!t->active) {
                        t->active = true;
                        t->start_time_ms = now_ms;
                    }
                    int64_t elapsed = now_ms - t->start_time_ms;
                    bool done = (elapsed >= preset_ms);
                    state_set_int(tag_id, done ? 1 : 0);
                    accumulator = done;
                } else {
                    t->active = false;
                    state_set_int(tag_id, 0);
                    accumulator = false;
                }
                break;
            }

            case OP_TOF: {
                if (pc + 1 >= s_bytecode_length) break;
                uint16_t preset_ms = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
                pc += 2;

                timer_state_t *t = get_or_create_timer(tag_id);
                if (!t) break;

                if (accumulator) {
                    t->active = false;
                    state_set_int(tag_id, 1);
                    accumulator = true;
                } else {
                    if (t->last_acc && !accumulator) {
                        t->active = true;
                        t->start_time_ms = now_ms;
                    }
                    if (t->active) {
                        int64_t elapsed = now_ms - t->start_time_ms;
                        if (elapsed >= preset_ms) {
                            t->active = false;
                            state_set_int(tag_id, 0);
                            accumulator = false;
                        } else {
                            state_set_int(tag_id, 1);
                            accumulator = true;
                        }
                    } else {
                        state_set_int(tag_id, 0);
                        accumulator = false;
                    }
                }
                t->last_acc = accumulator;
                break;
            }

            case OP_CTU: {
                if (pc + 1 >= s_bytecode_length) break;
                uint16_t preset_cnt = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
                pc += 2;

                counter_state_t *c = get_or_create_counter(tag_id);
                if (!c) break;

                if (accumulator && !c->last_acc) {
                    c->current_count++;
                }
                c->last_acc = accumulator;

                bool done = (c->current_count >= preset_cnt);
                state_set_int(tag_id, done ? 1 : 0);
                accumulator = done;
                break;
            }

            case OP_CTD: {
                if (pc + 1 >= s_bytecode_length) break;
                uint16_t preset_cnt = (s_bytecode[pc] << 8) | s_bytecode[pc + 1];
                pc += 2;

                counter_state_t *c = get_or_create_counter(tag_id);
                if (!c) break;

                if (c->current_count == 0) {
                    c->current_count = preset_cnt;
                }

                if (accumulator && !c->last_acc) {
                    if (c->current_count > 0) c->current_count--;
                }
                c->last_acc = accumulator;

                bool done = (c->current_count == 0);
                state_set_int(tag_id, done ? 1 : 0);
                accumulator = done;
                break;
            }

            case OP_EQU: {
                if (pc + 1 >= s_bytecode_length) break;
                int16_t preset_val = (int16_t)((s_bytecode[pc] << 8) | s_bytecode[pc + 1]);
                pc += 2;
                accumulator = accumulator && (val == preset_val);
                break;
            }
            case OP_GRT: {
                if (pc + 1 >= s_bytecode_length) break;
                int16_t preset_val = (int16_t)((s_bytecode[pc] << 8) | s_bytecode[pc + 1]);
                pc += 2;
                accumulator = accumulator && (val > preset_val);
                break;
            }
            case OP_LES: {
                if (pc + 1 >= s_bytecode_length) break;
                int16_t preset_val = (int16_t)((s_bytecode[pc] << 8) | s_bytecode[pc + 1]);
                pc += 2;
                accumulator = accumulator && (val < preset_val);
                break;
            }

            default: break;
        }
    }
}

bool ladder_engine_run_self_test(void)
{
    ESP_LOGI(TAG, "Iniciando self-test unitario do Ladder Engine (Contrato X/Y)...");

    uint8_t saved_bytecode[LADDER_MAX_PROGRAM_SIZE];
    size_t saved_length = s_bytecode_length;
    bool saved_has_program = s_has_program;
    if (saved_has_program && saved_length > 0) {
        memcpy(saved_bytecode, s_bytecode, saved_length);
    }

    uint8_t test_prog[] = {
        'E', 'N', 'D', 'P', 0x01,
        OP_LD, (ENDAP_INPUT_ID(0) >> 8) & 0xFF, ENDAP_INPUT_ID(0) & 0xFF,
        OP_ST, (ENDAP_OUTPUT_ID(0) >> 8) & 0xFF, ENDAP_OUTPUT_ID(0) & 0xFF,
        0xFF
    };

    esp_err_t err = ladder_engine_load_program(test_prog, sizeof(test_prog));
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Self-test falhou ao carregar programa de teste: %d", err);
        goto fail;
    }

    state_set_int(ENDAP_INPUT_ID(0), 0);
    state_set_int(ENDAP_OUTPUT_ID(0), 1);
    ladder_engine_run();

    int32_t out_val = -1;
    state_get_int(ENDAP_OUTPUT_ID(0), &out_val);
    if (out_val != 0) {
        ESP_LOGE(TAG, "Self-test falhou: X0=0 deveria produzir Y0=0, mas obteve %" PRId32, out_val);
        goto fail;
    }

    state_set_int(ENDAP_INPUT_ID(0), 1);
    ladder_engine_run();

    state_get_int(ENDAP_OUTPUT_ID(0), &out_val);
    if (out_val != 1) {
        ESP_LOGE(TAG, "Self-test falhou: X0=1 deveria produzir Y0=1, mas obteve %" PRId32, out_val);
        goto fail;
    }

    state_set_int(ENDAP_INPUT_ID(0), 0);
    ladder_engine_run();

    state_get_int(ENDAP_OUTPUT_ID(0), &out_val);
    if (out_val != 0) {
        ESP_LOGE(TAG, "Self-test falhou: X0=0 (reset) deveria produzir Y0=0, mas obteve %" PRId32, out_val);
        goto fail;
    }

    if (saved_has_program && saved_length > 0) {
        ladder_engine_load_program(saved_bytecode, saved_length);
    } else {
        ladder_engine_clear();
    }

    ESP_LOGI(TAG, "Self-test unitario do Ladder Engine (Contrato X/Y) concluido com SUCESSO!");
    return true;

fail:
    if (saved_has_program && saved_length > 0) {
        ladder_engine_load_program(saved_bytecode, saved_length);
    } else {
        ladder_engine_clear();
    }
    return false;
}
