#include "io_driver.h"
#include "cluster_io.h"
#include "cluster_metrics.h"
#include "cluster_transport.h"
#include "node_registry.h"
#include "protocol.h"
#include "device_profile.h"
#include "failsafe.h"
#include "io_map.h"
#include "io_binding.h"

#include "driver/gpio.h"
#include "esp_attr.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "http_server.h"
#include "io_image.h"
#include "state.h"
#include "esp_adc/adc_oneshot.h"
#include "driver/dac_oneshot.h"
#include "pve.h"

#include <inttypes.h>
#include <string.h>

#define TAG "IO_DRIVER"
#define INPUT_DEBOUNCE_SAMPLES 8
#define INPUT_DIAG_PERIOD_US   (5ULL * 1000ULL * 1000ULL)
#define IO_DRIVER_MAX_OUTPUTS  16
#define IO_DRIVER_MAX_INPUTS   16
#define ADC_DEADBAND_COUNTS    64
#define ADC_SETTLE_SAMPLES     3

static uint8_t last_index = 0;
static uint64_t last_diag_report_us = 0;
static adc_oneshot_unit_handle_t adc1_handle = NULL;
static bool adc1_initialized = false;
#if SOC_DAC_SUPPORTED
static dac_oneshot_handle_t dac0_handle = NULL; // GPIO 25 (AO0.0, ID 80)
static dac_oneshot_handle_t dac1_handle = NULL; // GPIO 26 (AO0.1, ID 81)
#endif
static volatile uint8_t pending_dac_mask = 0;
static int32_t last_dac0_pct = -1;
static int32_t last_dac1_pct = -1;

static inline int resolve_legacy_input_slot(uint16_t id)
{
    if (id >= ENDAP_INPUT_ID(0) && id <= ENDAP_INPUT_ID(11)) {
        return (int)(id - ENDAP_INPUT_ID(0)); // IDs 10..21 -> 0..11 (DI)
    }
    if (id >= ENDAP_INPUT_ID(12) && id <= ENDAP_INPUT_ID(15)) {
        return (int)(id - ENDAP_INPUT_ID(0)); // IDs 22..25 -> 12..15 (AI)
    }
    return -1;
}

/* ============================================================
   OUTPUT TABLE
============================================================ */

typedef struct
{
    uint16_t id;
    gpio_num_t gpio;
    bool active_low;
} output_channel_t;

static output_channel_t output_table[IO_DRIVER_MAX_OUTPUTS];
static size_t output_count = 0;

/* ============================================================
   INPUT TABLE
============================================================ */

typedef struct
{
    uint16_t id;
    gpio_num_t gpio;
    bool active_low;
    uint8_t debounce_samples;
    uint8_t last_sample;
    uint8_t stable_value;
    uint8_t stable_count;
    uint32_t raw_edges;
    uint32_t stable_edges;
    uint32_t reported_raw_edges;
    uint32_t reported_stable_edges;
    uint32_t recent_raw_edges;
    uint32_t recent_stable_edges;
    uint32_t recent_noise_edges;
    device_channel_backend_t backend;
    int endpoint_index;
    int32_t last_adc_raw;
    uint8_t adc_settle_count;
    uint8_t image_value; /* valor publicado (real debounced ou forçado) */
} input_channel_t;

static input_channel_t input_table[IO_DRIVER_MAX_INPUTS];
static size_t input_count = 0;

/* ============================================================
   PENDING MASK (🔥 DETERMINÍSTICO)
============================================================ */

static volatile uint32_t pending_mask = 0;
static uint32_t local_mask = 0;

/* ============================================================
   FORCE TABLE (forçamento real de E/S)
   - Bit i = índice na output_table / input_table.
   - Escrito apenas pelo task HTTP (via io_driver_force_*),
     lido no hot path com um único teste de bit (O(1)).
   - Ordem de escrita: valor antes do enable (set) e enable antes
     de qualquer outra coisa (release) => leitor nunca vê valor velho.
   - Somente RAM: todo force é perdido no reboot (comportamento seguro).
============================================================ */

static volatile uint32_t out_force_en = 0;
static volatile uint32_t out_force_val = 0;
static volatile uint32_t in_force_en = 0;
static volatile uint32_t in_force_val = 0;

static uint8_t io_driver_clamp_debounce_samples(uint8_t configured)
{
    if (configured < INPUT_DEBOUNCE_SAMPLES)
        return INPUT_DEBOUNCE_SAMPLES;

    if (configured > 32U)
        return 32U;

    return configured;
}

static inline int IRAM_ATTR io_driver_output_gpio_level(const output_channel_t *ch, bool logical_on)
{
    return ch->active_low ? (logical_on ? 0 : 1) : (logical_on ? 1 : 0);
}

static inline void io_driver_state_shadow_assign(int32_t *shadow, uint16_t id, int32_t value)
{
    if (!shadow)
        return;

    if (id >= STATE_MAX_ENTRIES)
        return;

    shadow[id] = value;
}

static void io_driver_load_profile(void)
{
    io_binding_output_view_t output_views[IO_BINDING_MAX_OUTPUTS];
    io_binding_input_view_t input_views[IO_BINDING_MAX_INPUTS];
    int profile_output_count = io_binding_export_outputs(output_views, IO_BINDING_MAX_OUTPUTS);
    int profile_input_count = io_binding_export_inputs(input_views, IO_BINDING_MAX_INPUTS);

    output_count = 0;
    input_count = 0;

    for (int i = 0; i < profile_output_count && output_count < IO_DRIVER_MAX_OUTPUTS; i++)
    {
        const io_binding_output_view_t *binding = &output_views[i];
        const device_output_profile_t *cfg = device_profile_find_output(binding->id);

        if (!cfg)
            continue;

        output_table[output_count].id = cfg->id;
        output_table[output_count].gpio = (gpio_num_t)binding->gpio;
        output_table[output_count].active_low = cfg->active_low;
        output_count++;
    }

    for (int i = 0; i < profile_input_count && input_count < IO_DRIVER_MAX_INPUTS; i++)
    {
        const io_binding_input_view_t *binding = &input_views[i];
        const device_input_profile_t *cfg = device_profile_find_input(binding->id);

        if (!cfg)
            continue;

        input_table[input_count] = (input_channel_t){
            .id = cfg->id,
            .gpio = (gpio_num_t)binding->gpio,
            .active_low = cfg->active_low,
            .debounce_samples = io_driver_clamp_debounce_samples(cfg->debounce_samples),
            .backend = binding->backend,
            .endpoint_index = binding->endpoint_index,
            .last_adc_raw = 0,
            .adc_settle_count = 0,
        };
        input_count++;
    }
}

/* ============================================================
   INIT
============================================================ */

void io_driver_init(void)
{
    int32_t state_shadow[STATE_MAX_ENTRIES] = {0};

    ESP_LOGI(TAG, "Inicializando IO Driver");
    io_driver_load_profile();
    pending_mask = 0;
    local_mask = 0;
    out_force_en = 0;
    out_force_val = 0;
    in_force_en = 0;
    in_force_val = 0;
    last_index = 0;
    last_diag_report_us = 0;

    /*
     * Boot-safe initialization:
     * - preserva o snapshot/restauração já carregado
     * - aplica bootstrap de IO no shadow local
     * - importa tudo de forma silenciosa no final
     * Evita side effects de state_set_int() durante o boot
     * (event bus / snapshot dirty / http notify / output hook).
     */
    state_export_snapshot(state_shadow, STATE_MAX_ENTRIES);

    for (size_t i = 0; i < output_count; i++)
    {
        int32_t restored_value = 0;
        int32_t boot_value = 0;
        const char *boot_origin = "startup-policy";

        if (output_table[i].gpio == GPIO_NUM_NC)
        {
            io_image_set_output(output_table[i].id, 0);
            io_driver_state_shadow_assign(state_shadow, output_table[i].id, 0);

            ESP_LOGI(TAG,
                "Output %u -> GPIO %d (%s, restored=%" PRId32 ", boot=%" PRId32 ", origin=%s)",
                output_table[i].id,
                output_table[i].gpio,
                output_table[i].active_low ? "active-low" : "active-high",
                restored_value,
                boot_value,
                boot_origin ? boot_origin : "startup-policy");
            continue;
        }

        gpio_config_t cfg =
        {
            .pin_bit_mask = (1ULL << output_table[i].gpio),
            .mode = GPIO_MODE_INPUT_OUTPUT,
            .pull_up_en = 0,
            .pull_down_en = 0,
            .intr_type = GPIO_INTR_DISABLE
        };

        gpio_config(&cfg);

        if (!state_get_int(output_table[i].id, &restored_value))
            restored_value = 0;

        if (!failsafe_startup_value(output_table[i].id, restored_value, &boot_value, &boot_origin))
            boot_value = 0;

        gpio_set_level(output_table[i].gpio,
            io_driver_output_gpio_level(&output_table[i], boot_value != 0));

        io_driver_state_shadow_assign(state_shadow, output_table[i].id, boot_value);

        ESP_LOGI(TAG,
            "Output %u -> GPIO %d (%s, restored=%" PRId32 ", boot=%" PRId32 ", origin=%s)",
            output_table[i].id,
            output_table[i].gpio,
            output_table[i].active_low ? "active-low" : "active-high",
            restored_value,
            boot_value,
            boot_origin ? boot_origin : "startup-policy");

        local_mask |= (1U << i);
    }

    int analog_channels_loaded = 0;
    for (size_t i = 0; i < input_count; i++)
    {
        if (input_table[i].backend == DEVICE_CHANNEL_BACKEND_ADC_NATIVE)
        {
            if (!adc1_initialized)
            {
                adc_oneshot_unit_init_cfg_t init_config = {
                    .unit_id = ADC_UNIT_1,
                };
                esp_err_t err = adc_oneshot_new_unit(&init_config, &adc1_handle);
                if (err == ESP_OK)
                {
                    adc1_initialized = true;
                }
                else
                {
                    ESP_LOGE(TAG, "Falha ao inicializar ADC1 oneshot unit: %s", esp_err_to_name(err));
                }
            }

            if (adc1_initialized)
            {
                adc_channel_t channel;
                adc_unit_t unit;
                esp_err_t err = adc_oneshot_io_to_channel(input_table[i].gpio, &unit, &channel);
                if (err == ESP_OK && unit == ADC_UNIT_1)
                {
                    input_table[i].endpoint_index = (int)channel;
                    adc_oneshot_chan_cfg_t config = {
                        .atten = ADC_ATTEN_DB_12,
                        .bitwidth = ADC_BITWIDTH_DEFAULT,
                    };
                    err = adc_oneshot_config_channel(adc1_handle, channel, &config);
                    if (err != ESP_OK)
                    {
                        ESP_LOGE(TAG, "Falha ao configurar canal ADC %d: %s", channel, esp_err_to_name(err));
                    }
                    else
                    {
                        ESP_LOGI(TAG, "Canal ADC %d configurado com sucesso para GPIO %d", channel, input_table[i].gpio);
                    }
                }
                else
                {
                    ESP_LOGE(TAG, "GPIO %d nao mapeia para um canal ADC1 valido ou erro: %s", input_table[i].gpio, esp_err_to_name(err));
                }
            }

            input_table[i].last_adc_raw = 0;
            input_table[i].stable_value = 0;
            input_table[i].stable_count = (uint8_t)(analog_channels_loaded % 10);
            analog_channels_loaded++;

            int initial_raw = 0;
            if (adc1_initialized && adc_oneshot_read(adc1_handle, (adc_channel_t)input_table[i].endpoint_index, &initial_raw) == ESP_OK)
            {
                input_table[i].last_adc_raw = initial_raw;
                input_table[i].stable_value = initial_raw;
            }

            io_image_set_input(input_table[i].id, input_table[i].last_adc_raw);
            io_driver_state_shadow_assign(state_shadow, input_table[i].id, input_table[i].last_adc_raw);

            if (input_table[i].gpio == GPIO_NUM_34) {
                pve_update(&pve_variables[0], input_table[i].last_adc_raw);
            } else if (input_table[i].gpio == GPIO_NUM_35) {
                pve_update(&pve_variables[0], input_table[i].last_adc_raw);
                pve_update(&pve_variables[1], input_table[i].last_adc_raw);
            }

            ESP_LOGI(TAG,
                "Input %u (Analogico) -> GPIO %d (ADC1 Ch %d, initial_raw=%d)",
                input_table[i].id,
                input_table[i].gpio,
                input_table[i].endpoint_index,
                initial_raw);
        }
        else
        {
            if (input_table[i].gpio == GPIO_NUM_NC)
            {
                input_table[i].last_sample = 0;
                input_table[i].stable_value = 0;
                input_table[i].stable_count = input_table[i].debounce_samples;
                input_table[i].image_value = 0;

                io_image_set_input(input_table[i].id, 0);
                io_driver_state_shadow_assign(state_shadow, input_table[i].id, 0);

                ESP_LOGI(TAG,
                    "Input %u -> GPIO %d (%s, pull-%s, debounce=%u)",
                    input_table[i].id,
                    input_table[i].gpio,
                    input_table[i].active_low ? "active-low" : "active-high",
                    input_table[i].active_low ? "up" : "down",
                    input_table[i].debounce_samples);
                continue;
            }

            gpio_config_t cfg =
            {
                .pin_bit_mask = (1ULL << input_table[i].gpio),
                .mode = GPIO_MODE_INPUT,
                .pull_up_en = input_table[i].active_low ? GPIO_PULLUP_ENABLE : GPIO_PULLUP_DISABLE,
                .pull_down_en = input_table[i].active_low ? GPIO_PULLDOWN_DISABLE : GPIO_PULLDOWN_ENABLE,
                .intr_type = GPIO_INTR_DISABLE
            };

            gpio_config(&cfg);

            int level = gpio_get_level(input_table[i].gpio);
            uint8_t logical = input_table[i].active_low ? (level == 0) : (level != 0);

            input_table[i].last_sample = logical;
            input_table[i].stable_value = logical;
            input_table[i].stable_count = input_table[i].debounce_samples;
            input_table[i].image_value = logical;

            io_image_set_input(input_table[i].id, logical);
            io_driver_state_shadow_assign(state_shadow, input_table[i].id, logical);

            ESP_LOGI(TAG,
                "Input %u -> GPIO %d (%s, pull-%s, debounce=%u%s)",
                input_table[i].id,
                input_table[i].gpio,
                input_table[i].active_low ? "active-low" : "active-high",
                device_profile_gpio_is_input_only(input_table[i].gpio)
                    ? "externo"
                    : (input_table[i].active_low ? "up" : "down"),
                input_table[i].debounce_samples,
                device_profile_gpio_is_input_only(input_table[i].gpio) ? ", input-only" : "");
        }
    }

    state_import_snapshot(state_shadow, STATE_MAX_ENTRIES);

#if SOC_DAC_SUPPORTED
    bool gpio25_used = false;
    bool gpio26_used = false;
    for (size_t i = 0; i < output_count; i++) {
        if (output_table[i].gpio == GPIO_NUM_25) gpio25_used = true;
        if (output_table[i].gpio == GPIO_NUM_26) gpio26_used = true;
    }
    for (size_t i = 0; i < input_count; i++) {
        if (input_table[i].gpio == GPIO_NUM_25) gpio25_used = true;
        if (input_table[i].gpio == GPIO_NUM_26) gpio26_used = true;
    }
    if (!gpio25_used && dac0_handle == NULL) {
        dac_oneshot_config_t dac0_cfg = { .chan_id = DAC_CHAN_0 };
        if (dac_oneshot_new_channel(&dac0_cfg, &dac0_handle) == ESP_OK) {
            dac_oneshot_output_voltage(dac0_handle, 0);
            ESP_LOGI(TAG, "Output Analogico AO0.0 (ID 80) -> GPIO 25 (DAC_CHAN_0, 0-100%% / 0-3.3V)");
        }
    }
    if (!gpio26_used && dac1_handle == NULL) {
        dac_oneshot_config_t dac1_cfg = { .chan_id = DAC_CHAN_1 };
        if (dac_oneshot_new_channel(&dac1_cfg, &dac1_handle) == ESP_OK) {
            dac_oneshot_output_voltage(dac1_handle, 0);
            ESP_LOGI(TAG, "Output Analogico AO0.1 (ID 81) -> GPIO 26 (DAC_CHAN_1, 0-100%% / 0-3.3V)");
        }
    }
#endif
}

/* ============================================================
   HELPERS
============================================================ */

static bool IRAM_ATTR io_driver_is_known_state(uint16_t id)
{
    if (id == 80 || id == 81)
        return true;

    for (size_t i = 0; i < output_count; i++)
    {
        if (output_table[i].id == id)
            return true;
    }

    for (size_t i = 0; i < input_count; i++)
    {
        if (input_table[i].id == id)
            return true;
    }

    return false;
}

/* ============================================================
   STATE HOOK (🔥 NÃO EXECUTA GPIO)
============================================================ */

void IRAM_ATTR state_output_changed(uint16_t id, int32_t value)
{
    (void)value;

    if (id == 80) {
        pending_dac_mask |= 0x01;
    } else if (id == 81) {
        pending_dac_mask |= 0x02;
    }

    for (size_t i = 0; i < output_count; i++)
    {
        if (output_table[i].id == id)
        {
            pending_mask |= (1U << i);
            break;
        }
    }

    if (id >= 108 && id < 200)
    {
        cluster_metrics_t metrics = cluster_get_metrics();
        if (metrics.self_node != 0U && cluster_transport_is_ready())
        {
            uint8_t target_ctrl_idx = (id - 100) / 8;
            uint32_t owner = node_registry_find_id_by_controller_index(target_ctrl_idx);
            if (owner == 0U || owner == metrics.self_node)
            {
                owner = node_registry_find_first_remote_node(metrics.self_node);
            }
            if (owner != 0U && owner != metrics.self_node)
            {
                protocol_msg_t msg = {0};
                msg.type = PROTOCOL_MSG_OUTPUT_COMMAND;
                msg.data.output_command.target_node = owner;
                msg.data.output_command.requester_node = metrics.self_node;
                msg.data.output_command.output_id = id;
                msg.data.output_command.value = value;
                cluster_transport_broadcast_frame((const uint8_t *)&msg, sizeof(msg));
            }
        }
    }

    if (io_driver_is_known_state(id))
        http_server_notify_state_change();
}

/* ============================================================
   INPUT SCAN (🔥 DETERMINÍSTICO)
============================================================ */

void IRAM_ATTR io_driver_scan_inputs(void)
{
    for (size_t i = 0; i < input_count; i++)
    {
        input_channel_t *ch = &input_table[i];

        if (ch->backend == DEVICE_CHANNEL_BACKEND_ADC_NATIVE)
        {
            ch->stable_count++;
            if (ch->stable_count < 10)
            {
                continue;
            }
            ch->stable_count = 0;

            if (adc1_initialized)
            {
                int raw_val = 0;
                if (adc_oneshot_read(adc1_handle, (adc_channel_t)ch->endpoint_index, &raw_val) == ESP_OK)
                {
                    // Se o GPIO 34 estiver desconectado/flutuando (< 900 counts; sensor capacitivo real opera entre 1100 e 4095),
                    // ignora completamente para não sobrescrever state[22] (AI0.0) nem state[72] com ruído de pino aberto.
                    if (ch->gpio == GPIO_NUM_34 && raw_val < 900)
                    {
                        continue;
                    }

                    int32_t diff = raw_val - ch->last_adc_raw;
                    if (diff < 0) diff = -diff;

                    if (diff >= ADC_DEADBAND_COUNTS)
                    {
                        ch->adc_settle_count++;
                        if (ch->adc_settle_count >= ADC_SETTLE_SAMPLES)
                        {
                            ch->last_adc_raw = raw_val;
                            ch->adc_settle_count = 0;
                            state_set_int(ch->id, raw_val);
                            if (ch->id >= ENDAP_INPUT_ID(14) && ch->id <= ENDAP_INPUT_ID(15)) {
                                uint16_t iec_ai_id = (uint16_t)(72 + (ch->id - ENDAP_INPUT_ID(12)));
                                state_set_int(iec_ai_id, raw_val);
                            }
                        }
                    }
                    else
                    {
                        ch->adc_settle_count = 0;
                    }

                    io_image_set_input(ch->id, raw_val);

                    if (ch->gpio == GPIO_NUM_35 || (ch->gpio == GPIO_NUM_34 && raw_val >= 900)) {
                        // Sensor de solo capacitivo típico (AIN1 / AIN2):
                        // No ar / SECO: Raw = 4095 (ou próximo de 3800..4095) -> 0% de umidade (PRECISA irrigar)
                        // Na água / MOLHADO: Raw ~ 1250 a 1500 -> 100% de umidade (NÃO precisa irrigar)
                        int32_t scaled_pct = 0;
                        if (raw_val >= 3800) {
                            scaled_pct = 0; // Seco / Ar
                        } else if (raw_val <= 1500) {
                            scaled_pct = 100; // Imerso em água
                        } else {
                            // Interpolação linear decrescente:
                            // raw_val de 3800 a 1500 mapeia para 0 a 100
                            scaled_pct = (int32_t)((3800 - raw_val) * 100 / (3800 - 1500));
                        }
                        if (scaled_pct < 0) scaled_pct = 0;
                        if (scaled_pct > 100) scaled_pct = 100;

                        // Alimenta a tag AI0.0 / %IW0.0 (ID 72) e pve_variables[0] (AIN1)
                        state_set_int(72, scaled_pct);
                        pve_update(&pve_variables[0], raw_val);

                        if (ch->gpio == GPIO_NUM_35) {
                            // Espelha também em state[22] (AI0.0) e state[23] (AI0.1), state[73] (AI0.1 %),
                            // io_image de AI0.0 (22) e pve_variables[1] (AIN2)
                            state_set_int(ch->id, raw_val);
                            state_set_int(ENDAP_INPUT_ID(12), raw_val);
                            state_set_int(73, scaled_pct);
                            io_image_set_input(ENDAP_INPUT_ID(12), raw_val);
                            pve_update(&pve_variables[1], raw_val);
                        }
                    }
                }
            }
            continue;
        }

        int level = gpio_get_level(ch->gpio);
        uint8_t logical = ch->active_low ? (level == 0) : (level != 0);

        if (logical != ch->last_sample)
        {
            ch->last_sample = logical;
            ch->stable_count = 1;
            ch->raw_edges++;
        }
        else if (ch->stable_count < ch->debounce_samples)
        {
            ch->stable_count++;
        }

        /*
         * Publica somente o valor estabilizado (debounced) na imagem e no
         * estado. Escrever o valor cru a cada scan faz a linha do ladder
         * "piscar" e a saida comutar com ruido de contato do comando real.
         */
        if (ch->stable_count >= ch->debounce_samples && ch->stable_value != logical)
        {
            ch->stable_value = logical;
            ch->stable_edges++;
        }

        /*
         * Valor efetivo: forçado (se habilitado) ou real estabilizado.
         * O debounce continua rodando sobre o sinal real durante o force,
         * então ao liberar o valor real é publicado imediatamente.
         */
        uint32_t bit = (1U << i);
        uint8_t effective = (in_force_en & bit) ? (uint8_t)((in_force_val & bit) ? 1U : 0U)
                                                : ch->stable_value;

        if (effective != ch->image_value)
        {
            ch->image_value = effective;
            io_image_set_input(ch->id, effective);
            state_set_int(ch->id, effective);
            http_server_notify_state_change();
        }
    }
}

static void io_driver_force_supervise(void)
{
    uint32_t en = out_force_en;

    if (en == 0U)
        return;

    /* Fail-safe sempre vence o forçamento manual. */
    for (size_t i = 0; i < output_count; i++)
    {
        uint32_t bit = (1U << i);
        if ((en & bit) && failsafe_is_active(output_table[i].id))
        {
            out_force_en &= ~bit;
            pending_mask |= bit;
            ESP_LOGW(TAG, "FORCE: output %u liberado automaticamente (fail-safe ativo)", output_table[i].id);
        }
    }
}

void io_driver_process(void)
{
    uint64_t now_us = (uint64_t)esp_timer_get_time();

    io_driver_force_supervise();

    if ((now_us - last_diag_report_us) < INPUT_DIAG_PERIOD_US)
        return;

    last_diag_report_us = now_us;

    for (size_t i = 0; i < input_count; i++)
    {
        input_channel_t *ch = &input_table[i];
        uint32_t raw = ch->raw_edges;
        uint32_t stable = ch->stable_edges;
        uint32_t noise = (raw > stable) ? (raw - stable) : 0U;
        uint32_t delta_raw = raw - ch->reported_raw_edges;
        uint32_t delta_stable = stable - ch->reported_stable_edges;
        uint32_t delta_noise = (delta_raw > delta_stable) ? (delta_raw - delta_stable) : 0U;

        ch->recent_raw_edges = delta_raw;
        ch->recent_stable_edges = delta_stable;
        ch->recent_noise_edges = delta_noise;
        ch->reported_raw_edges = raw;
        ch->reported_stable_edges = stable;

        if (delta_raw == 0U && delta_stable == 0U)
            continue;

        if (delta_noise > 0U)
        {
            ESP_LOGW(TAG,
                "INPUT_DIAG: input=%u level=%u raw=%" PRIu32 " stable=%" PRIu32 " noise=%" PRIu32
                " (+raw=%" PRIu32 " +stable=%" PRIu32 " +noise=%" PRIu32 ")",
                ch->id,
                ch->stable_value,
                raw,
                stable,
                noise,
                delta_raw,
                delta_stable,
                delta_noise);
        }
        else
        {
            ESP_LOGI(TAG,
                "INPUT_DIAG: input=%u level=%u raw=%" PRIu32 " stable=%" PRIu32 " noise=%" PRIu32
                " (+raw=%" PRIu32 " +stable=%" PRIu32 ")",
                ch->id,
                ch->stable_value,
                raw,
                stable,
                noise,
                delta_raw,
                delta_stable);
        }
    }
}

int io_driver_get_input_diag(io_driver_input_diag_t *out, int max_inputs)
{
    int count = ((int)input_count < max_inputs) ? (int)input_count : max_inputs;

    if (!out || max_inputs <= 0)
        return (int)input_count;

    for (int i = 0; i < count; i++)
    {
        uint32_t raw = input_table[i].raw_edges;
        uint32_t stable = input_table[i].stable_edges;

        out[i].id = input_table[i].id;
        out[i].level = input_table[i].stable_value;
        out[i].raw_edges = raw;
        out[i].stable_edges = stable;
        out[i].noise_edges = (raw > stable) ? (raw - stable) : 0U;
        out[i].recent_raw_edges = input_table[i].recent_raw_edges;
        out[i].recent_stable_edges = input_table[i].recent_stable_edges;
        out[i].recent_noise_edges = input_table[i].recent_noise_edges;
    }

    return count;
}

/* ============================================================
   APPLY OUTPUTS (🔥 CONTROLADO)
============================================================ */

void IRAM_ATTR io_driver_update(void)
{
#if SOC_DAC_SUPPORTED
    uint8_t dac_mask = pending_dac_mask;
    if (dac_mask != 0U)
    {
        if ((dac_mask & 0x01U) && dac0_handle != NULL)
        {
            int32_t pct = 0;
            (void)state_get_int(80, &pct);
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
            if (pct != last_dac0_pct) {
                last_dac0_pct = pct;
                uint8_t dac_byte = (uint8_t)((pct * 255) / 100);
                (void)dac_oneshot_output_voltage(dac0_handle, dac_byte);
            }
            pending_dac_mask &= ~0x01U;
        }
        if ((dac_mask & 0x02U) && dac1_handle != NULL)
        {
            int32_t pct = 0;
            (void)state_get_int(81, &pct);
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
            if (pct != last_dac1_pct) {
                last_dac1_pct = pct;
                uint8_t dac_byte = (uint8_t)((pct * 255) / 100);
                (void)dac_oneshot_output_voltage(dac1_handle, dac_byte);
            }
            pending_dac_mask &= ~0x02U;
        }
    }
#endif

    uint32_t mask = pending_mask;

    if (output_count == 0U || mask == 0U)
        return;

    for (size_t i = 0; i < output_count; i++)
    {
        if (mask & (1U << i))
        {
            int32_t value = 0;
            uint32_t bit = (1U << i);
            bool have_value = state_get_int(output_table[i].id, &value);

            if (out_force_en & bit)
            {
                value = (out_force_val & bit) ? 1 : 0;
                have_value = true;
            }

            if (have_value)
            {
                uint32_t target_level = io_driver_output_gpio_level(&output_table[i], value != 0);
                if (output_table[i].gpio != GPIO_NUM_NC && (int)output_table[i].gpio >= 0)
                {
                    gpio_set_level(output_table[i].gpio, target_level);
                }
            }
            pending_mask &= ~(1U << i);
        }
    }
}

bool io_driver_get_output_physical_level(uint16_t id, int32_t *out_physical_val)
{
    if (!out_physical_val)
        return false;

    for (size_t i = 0; i < output_count; i++)
    {
        if (output_table[i].id == id)
        {
            if (output_table[i].gpio == GPIO_NUM_NC || (int)output_table[i].gpio < 0)
            {
                int32_t val = 0;
                (void)state_get_int(id, &val);
                *out_physical_val = val;
                return true;
            }

            int level = gpio_get_level(output_table[i].gpio);
            *out_physical_val = output_table[i].active_low ? (level == 0 ? 1 : 0) : (level != 0 ? 1 : 0);
            return true;
        }
    }

    return false;
}


/* ============================================================
   FORCE API (chamada pelo task HTTP, nunca pelo hot path)
============================================================ */

static int io_driver_find_output_index(uint16_t id)
{
    for (size_t i = 0; i < output_count; i++)
    {
        if (output_table[i].id == id)
            return (int)i;
    }
    return -1;
}

static int io_driver_find_digital_input_index(uint16_t id)
{
    for (size_t i = 0; i < input_count; i++)
    {
        if (input_table[i].id == id &&
            input_table[i].backend != DEVICE_CHANNEL_BACKEND_ADC_NATIVE)
            return (int)i;
    }
    return -1;
}

io_driver_force_result_t io_driver_force_set(uint16_t id, int32_t value)
{
    int idx = io_driver_find_output_index(id);

    if (idx >= 0)
    {
        uint32_t bit = (1U << idx);

        if (failsafe_is_active(id))
            return IO_DRIVER_FORCE_BLOCKED_FAILSAFE;

        if (value != 0)
            out_force_val |= bit;
        else
            out_force_val &= ~bit;
        out_force_en |= bit;
        pending_mask |= bit;
        state_set_int(id, value != 0 ? 1 : 0);
        http_server_notify_state_change();
        return IO_DRIVER_FORCE_OK;
    }

    idx = io_driver_find_digital_input_index(id);
    if (idx >= 0)
    {
        uint32_t bit = (1U << idx);

        if (value != 0)
            in_force_val |= bit;
        else
            in_force_val &= ~bit;
        in_force_en |= bit;
        input_table[idx].image_value = (value != 0 ? 1 : 0);
        state_set_int(id, value != 0 ? 1 : 0);
        io_image_set_input(id, value != 0 ? 1 : 0);
        http_server_notify_state_change();
        return IO_DRIVER_FORCE_OK;
    }

    return IO_DRIVER_FORCE_NOT_FOUND;
}

io_driver_force_result_t io_driver_force_release(uint16_t id)
{
    int idx = io_driver_find_output_index(id);

    if (idx >= 0)
    {
        uint32_t bit = (1U << idx);
        out_force_en &= ~bit;
        pending_mask |= bit; /* reaplica o valor da lógica */
        http_server_notify_state_change();
        return IO_DRIVER_FORCE_OK;
    }

    idx = io_driver_find_digital_input_index(id);
    if (idx >= 0)
    {
        in_force_en &= ~(1U << idx);
        uint8_t real_val = input_table[idx].stable_value;
        input_table[idx].image_value = real_val;
        state_set_int(id, real_val);
        io_image_set_input(id, real_val);
        http_server_notify_state_change();
        return IO_DRIVER_FORCE_OK;
    }

    return IO_DRIVER_FORCE_NOT_FOUND;
}

int io_driver_force_release_all(void)
{
    int released = __builtin_popcount(out_force_en) + __builtin_popcount(in_force_en);
    uint32_t out_mask = out_force_en;

    out_force_en = 0;
    in_force_en = 0;
    for (size_t i = 0; i < input_count; i++)
    {
        if (input_table[i].backend == DEVICE_CHANNEL_BACKEND_ADC_NATIVE)
        {
            if (input_table[i].gpio == GPIO_NUM_34 && input_table[i].last_adc_raw < 900)
                continue;
            int32_t adc_val = input_table[i].last_adc_raw;
            state_set_int(input_table[i].id, adc_val);
            io_image_set_input(input_table[i].id, adc_val);
            if (input_table[i].gpio == GPIO_NUM_35)
            {
                state_set_int(ENDAP_INPUT_ID(12), adc_val);
                io_image_set_input(ENDAP_INPUT_ID(12), adc_val);
            }
            continue;
        }
        uint8_t real_val = input_table[i].stable_value;
        input_table[i].image_value = real_val;
        state_set_int(input_table[i].id, real_val);
        io_image_set_input(input_table[i].id, real_val);
    }
    pending_mask |= out_mask;
    http_server_notify_state_change();
    return released;
}

bool io_driver_force_get(uint16_t id, int32_t *out_value)
{
    int idx = io_driver_find_output_index(id);

    if (idx >= 0)
    {
        uint32_t bit = (1U << idx);
        if (!(out_force_en & bit))
            return false;
        if (out_value)
            *out_value = (out_force_val & bit) ? 1 : 0;
        return true;
    }

    idx = io_driver_find_digital_input_index(id);
    if (idx >= 0)
    {
        uint32_t bit = (1U << idx);
        if (!(in_force_en & bit))
            return false;
        if (out_value)
            *out_value = (in_force_val & bit) ? 1 : 0;
        return true;
    }

    return false;
}

int io_driver_force_export(io_driver_force_entry_t *out, int max_entries)
{
    int count = 0;

    for (size_t i = 0; i < output_count && count < max_entries; i++)
    {
        uint32_t bit = (1U << i);
        if (!(out_force_en & bit))
            continue;
        if (out)
        {
            out[count].id = output_table[i].id;
            out[count].value = (out_force_val & bit) ? 1 : 0;
            out[count].is_output = true;
        }
        count++;
    }

    for (size_t i = 0; i < input_count && count < max_entries; i++)
    {
        uint32_t bit = (1U << i);
        if (!(in_force_en & bit))
            continue;
        if (out)
        {
            out[count].id = input_table[i].id;
            out[count].value = (in_force_val & bit) ? 1 : 0;
            out[count].is_output = false;
        }
        count++;
    }

    return count;
}
