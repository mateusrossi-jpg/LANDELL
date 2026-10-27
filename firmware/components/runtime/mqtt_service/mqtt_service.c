#include "mqtt_service.h"

#include "mqtt_client.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "cJSON.h"

#include "state.h"
#include "io_command.h"
#include "io_binding.h"
#include "failsafe.h"
#include "node_identity.h"
#include "network_ready.h"
#include "kernel_metrics.h"

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#define TAG "MQTT_SVC"
#define MQTT_NVS_NAMESPACE "endap_mqtt"

static mqtt_service_config_t s_config;
static mqtt_service_status_t s_status;
static esp_mqtt_client_handle_t s_client = NULL;
static SemaphoreHandle_t s_lock = NULL;
static bool s_initialized = false;
static uint32_t s_node_id = 0;

static int32_t s_last_outputs[STATE_MAX_ENTRIES];
static int32_t s_last_inputs[STATE_MAX_ENTRIES];
static bool s_first_sync = true;
static int64_t s_last_poll_time_us = 0;
static int64_t s_last_telemetry_time_us = 0;

/* Buffers estáticos para evitar consumo de pilha */
static io_binding_output_view_t s_static_outputs[IO_BINDING_MAX_OUTPUTS];
static io_binding_input_view_t s_static_inputs[IO_BINDING_MAX_INPUTS];

/* ============================================================
   NVS HELPERS
============================================================ */

static esp_err_t mqtt_nvs_load(mqtt_service_config_t *cfg)
{
    nvs_handle_t nvs;
    esp_err_t err;

    memset(cfg, 0, sizeof(*cfg));
    cfg->enabled = false;
    cfg->ha_discovery = true;
    cfg->publish_interval_ms = 100;
    snprintf(cfg->base_topic, sizeof(cfg->base_topic), "endap");
    snprintf(cfg->client_id, sizeof(cfg->client_id), "endap_%" PRIu32, s_node_id);

    err = nvs_open(MQTT_NVS_NAMESPACE, NVS_READONLY, &nvs);
    if (err != ESP_OK)
    {
        return err;
    }

    uint8_t u8_val = 0;
    if (nvs_get_u8(nvs, "enabled", &u8_val) == ESP_OK) {
        cfg->enabled = (u8_val != 0);
    }
    if (nvs_get_u8(nvs, "ha_disc", &u8_val) == ESP_OK) {
        cfg->ha_discovery = (u8_val != 0);
    }
    uint16_t u16_val = 0;
    if (nvs_get_u16(nvs, "pub_ms", &u16_val) == ESP_OK && u16_val >= 20) {
        cfg->publish_interval_ms = u16_val;
    }

    size_t len = sizeof(cfg->broker_url);
    nvs_get_str(nvs, "url", cfg->broker_url, &len);

    len = sizeof(cfg->client_id);
    nvs_get_str(nvs, "cid", cfg->client_id, &len);

    len = sizeof(cfg->username);
    nvs_get_str(nvs, "user", cfg->username, &len);

    len = sizeof(cfg->password);
    nvs_get_str(nvs, "pass", cfg->password, &len);

    len = sizeof(cfg->base_topic);
    nvs_get_str(nvs, "topic", cfg->base_topic, &len);

    nvs_close(nvs);
    return ESP_OK;
}

static esp_err_t mqtt_nvs_save(const mqtt_service_config_t *cfg)
{
    nvs_handle_t nvs;
    esp_err_t err = nvs_open(MQTT_NVS_NAMESPACE, NVS_READWRITE, &nvs);
    if (err != ESP_OK)
    {
        return err;
    }

    nvs_set_u8(nvs, "enabled", cfg->enabled ? 1 : 0);
    nvs_set_u8(nvs, "ha_disc", cfg->ha_discovery ? 1 : 0);
    nvs_set_u16(nvs, "pub_ms", cfg->publish_interval_ms);
    nvs_set_str(nvs, "url", cfg->broker_url);
    nvs_set_str(nvs, "cid", cfg->client_id);
    nvs_set_str(nvs, "user", cfg->username);
    nvs_set_str(nvs, "pass", cfg->password);
    nvs_set_str(nvs, "topic", cfg->base_topic);

    err = nvs_commit(nvs);
    nvs_close(nvs);
    return err;
}

/* ============================================================
   DISCOVERY PUBLISHING (HOME ASSISTANT)
============================================================ */

void mqtt_service_publish_discovery(void)
{
    if (!s_client || !s_status.connected || !s_config.ha_discovery)
    {
        return;
    }

    char topic[128];
    char will_topic[64];
    snprintf(will_topic, sizeof(will_topic), "%s/%" PRIu32 "/status", s_config.base_topic, s_node_id);

    /* 1. Descoberta de Saídas Digitais (Switches no Home Assistant) */
    int out_count = io_binding_export_outputs(s_static_outputs, IO_BINDING_MAX_OUTPUTS);

    for (int i = 0; i < out_count; i++)
    {
        snprintf(topic, sizeof(topic), "homeassistant/switch/endap_%" PRIu32 "/out_%d/config",
                 s_node_id, s_static_outputs[i].id);

        char state_topic[64];
        char cmd_topic[64];
        snprintf(state_topic, sizeof(state_topic), "%s/%" PRIu32 "/state/output/%d",
                 s_config.base_topic, s_node_id, s_static_outputs[i].id);
        snprintf(cmd_topic, sizeof(cmd_topic), "%s/%" PRIu32 "/cmd/output/%d/set",
                 s_config.base_topic, s_node_id, s_static_outputs[i].id);

        cJSON *root = cJSON_CreateObject();
        char name_buf[48];
        snprintf(name_buf, sizeof(name_buf), "%s (Q%d)",
                 s_static_outputs[i].name[0] ? s_static_outputs[i].name : "Saida", s_static_outputs[i].id);
        cJSON_AddStringToObject(root, "name", name_buf);

        char uid_buf[48];
        snprintf(uid_buf, sizeof(uid_buf), "endap_%" PRIu32 "_out_%d", s_node_id, s_static_outputs[i].id);
        cJSON_AddStringToObject(root, "unique_id", uid_buf);
        cJSON_AddStringToObject(root, "state_topic", state_topic);
        cJSON_AddStringToObject(root, "command_topic", cmd_topic);
        cJSON_AddStringToObject(root, "payload_on", "1");
        cJSON_AddStringToObject(root, "payload_off", "0");
        cJSON_AddStringToObject(root, "state_on", "1");
        cJSON_AddStringToObject(root, "state_off", "0");
        cJSON_AddStringToObject(root, "availability_topic", will_topic);
        cJSON_AddStringToObject(root, "payload_available", "online");
        cJSON_AddStringToObject(root, "payload_not_available", "offline");

        cJSON *dev = cJSON_CreateObject();
        cJSON *ids = cJSON_CreateArray();
        char dev_id[32];
        snprintf(dev_id, sizeof(dev_id), "endap_%" PRIu32, s_node_id);
        cJSON_AddItemToArray(ids, cJSON_CreateString(dev_id));
        cJSON_AddItemToObject(dev, "identifiers", ids);
        char dev_name[48];
        snprintf(dev_name, sizeof(dev_name), "ENDAP PLC %" PRIu32, s_node_id);
        cJSON_AddStringToObject(dev, "name", dev_name);
        cJSON_AddStringToObject(dev, "model", "ENDAP Industrial Controller");
        cJSON_AddStringToObject(dev, "manufacturer", "ENDAP Automation");
        cJSON_AddStringToObject(dev, "sw_version", "1.0.0");
        cJSON_AddItemToObject(root, "device", dev);

        char *payload = cJSON_PrintUnformatted(root);
        if (payload)
        {
            esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 1);
            free(payload);
        }
        cJSON_Delete(root);
    }

    /* 2. Descoberta de Entradas Digitais (Binary Sensors no Home Assistant) */
    int in_count = io_binding_export_inputs(s_static_inputs, IO_BINDING_MAX_INPUTS);

    for (int i = 0; i < in_count; i++)
    {
        snprintf(topic, sizeof(topic), "homeassistant/binary_sensor/endap_%" PRIu32 "/in_%d/config",
                 s_node_id, s_static_inputs[i].id);

        char state_topic[64];
        snprintf(state_topic, sizeof(state_topic), "%s/%" PRIu32 "/state/input/%d",
                 s_config.base_topic, s_node_id, s_static_inputs[i].id);

        cJSON *root = cJSON_CreateObject();
        char name_buf[48];
        snprintf(name_buf, sizeof(name_buf), "%s (I%d)",
                 s_static_inputs[i].name[0] ? s_static_inputs[i].name : "Entrada", s_static_inputs[i].id);
        cJSON_AddStringToObject(root, "name", name_buf);

        char uid_buf[48];
        snprintf(uid_buf, sizeof(uid_buf), "endap_%" PRIu32 "_in_%d", s_node_id, s_static_inputs[i].id);
        cJSON_AddStringToObject(root, "unique_id", uid_buf);
        cJSON_AddStringToObject(root, "state_topic", state_topic);
        cJSON_AddStringToObject(root, "payload_on", "1");
        cJSON_AddStringToObject(root, "payload_off", "0");
        cJSON_AddStringToObject(root, "availability_topic", will_topic);
        cJSON_AddStringToObject(root, "payload_available", "online");
        cJSON_AddStringToObject(root, "payload_not_available", "offline");

        cJSON *dev = cJSON_CreateObject();
        cJSON *ids = cJSON_CreateArray();
        char dev_id[32];
        snprintf(dev_id, sizeof(dev_id), "endap_%" PRIu32, s_node_id);
        cJSON_AddItemToArray(ids, cJSON_CreateString(dev_id));
        cJSON_AddItemToObject(dev, "identifiers", ids);
        char dev_name[48];
        snprintf(dev_name, sizeof(dev_name), "ENDAP PLC %" PRIu32, s_node_id);
        cJSON_AddStringToObject(dev, "name", dev_name);
        cJSON_AddStringToObject(dev, "model", "ENDAP Industrial Controller");
        cJSON_AddStringToObject(dev, "manufacturer", "ENDAP Automation");
        cJSON_AddStringToObject(dev, "sw_version", "1.0.0");
        cJSON_AddItemToObject(root, "device", dev);

        char *payload = cJSON_PrintUnformatted(root);
        if (payload)
        {
            esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 1);
            free(payload);
        }
        cJSON_Delete(root);
    }

    /* 3. Sensor de Telemetria: Jitter do Ciclo Determinístico */
    {
        snprintf(topic, sizeof(topic), "homeassistant/sensor/endap_%" PRIu32 "/jitter/config", s_node_id);
        cJSON *root = cJSON_CreateObject();
        cJSON_AddStringToObject(root, "name", "PLC Max Jitter");
        char uid_buf[48];
        snprintf(uid_buf, sizeof(uid_buf), "endap_%" PRIu32 "_jitter", s_node_id);
        cJSON_AddStringToObject(root, "unique_id", uid_buf);
        char state_topic[64];
        snprintf(state_topic, sizeof(state_topic), "%s/%" PRIu32 "/telemetry", s_config.base_topic, s_node_id);
        cJSON_AddStringToObject(root, "state_topic", state_topic);
        cJSON_AddStringToObject(root, "value_template", "{{ value_json.max_jitter_us }}");
        cJSON_AddStringToObject(root, "unit_of_measurement", "us");
        cJSON_AddStringToObject(root, "availability_topic", will_topic);
        cJSON_AddStringToObject(root, "payload_available", "online");
        cJSON_AddStringToObject(root, "payload_not_available", "offline");

        cJSON *dev = cJSON_CreateObject();
        cJSON *ids = cJSON_CreateArray();
        char dev_id[32];
        snprintf(dev_id, sizeof(dev_id), "endap_%" PRIu32, s_node_id);
        cJSON_AddItemToArray(ids, cJSON_CreateString(dev_id));
        cJSON_AddItemToObject(dev, "identifiers", ids);
        char dev_name[48];
        snprintf(dev_name, sizeof(dev_name), "ENDAP PLC %" PRIu32, s_node_id);
        cJSON_AddStringToObject(dev, "name", dev_name);
        cJSON_AddStringToObject(dev, "model", "ENDAP Industrial Controller");
        cJSON_AddStringToObject(dev, "manufacturer", "ENDAP Automation");
        cJSON_AddStringToObject(dev, "sw_version", "1.0.0");
        cJSON_AddItemToObject(root, "device", dev);

        char *payload = cJSON_PrintUnformatted(root);
        if (payload)
        {
            esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 1);
            free(payload);
        }
        cJSON_Delete(root);
    }

    ESP_LOGI(TAG, "Home Assistant MQTT Discovery publicado para %d outputs e %d inputs", out_count, in_count);
}

/* ============================================================
   PERIODIC PROCESS (CORE 0 ASYNCHRONOUS - VIA CORE_AUX_TASK)
============================================================ */

void mqtt_service_process(void)
{
    if (!s_status.connected || !s_client)
    {
        return;
    }

    int64_t now_us = esp_timer_get_time();
    int64_t poll_interval_us = (int64_t)s_config.publish_interval_ms * 1000LL;
    if (poll_interval_us < 20000LL) poll_interval_us = 100000LL;

    if (now_us - s_last_poll_time_us < poll_interval_us)
    {
        return;
    }
    s_last_poll_time_us = now_us;

    /* 1. Publicação de Saídas Digitais por Mudança (Egress) */
    int out_count = io_binding_export_outputs(s_static_outputs, IO_BINDING_MAX_OUTPUTS);
    for (int i = 0; i < out_count; i++)
    {
        uint16_t id = s_static_outputs[i].id;
        if (id < STATE_MAX_ENTRIES)
        {
            int32_t val = 0;
            if (state_get_int(id, &val))
            {
                if (s_first_sync || val != s_last_outputs[id])
                {
                    s_last_outputs[id] = val;
                    char topic[64];
                    snprintf(topic, sizeof(topic), "%s/%" PRIu32 "/state/output/%d",
                             s_config.base_topic, s_node_id, id);
                    const char *payload = val ? "1" : "0";
                    esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 1);
                    s_status.messages_published++;
                }
            }
        }
    }

    /* 2. Publicação de Entradas Digitais por Mudança (Egress) */
    int in_count = io_binding_export_inputs(s_static_inputs, IO_BINDING_MAX_INPUTS);
    for (int i = 0; i < in_count; i++)
    {
        uint16_t id = s_static_inputs[i].id;
        if (id < STATE_MAX_ENTRIES)
        {
            int32_t val = 0;
            if (state_get_int(id, &val))
            {
                if (s_first_sync || val != s_last_inputs[id])
                {
                    s_last_inputs[id] = val;
                    char topic[64];
                    snprintf(topic, sizeof(topic), "%s/%" PRIu32 "/state/input/%d",
                             s_config.base_topic, s_node_id, id);
                    const char *payload = val ? "1" : "0";
                    esp_mqtt_client_publish(s_client, topic, payload, 0, 1, 1);
                    s_status.messages_published++;
                }
            }
        }
    }

    s_first_sync = false;

    /* 3. Telemetria do Sistema (a cada 5 segundos) */
    if (now_us - s_last_telemetry_time_us >= 5000000LL)
    {
        s_last_telemetry_time_us = now_us;

        kernel_metrics_snapshot_t km;
        kernel_metrics_get(&km);

        char topic[64];
        snprintf(topic, sizeof(topic), "%s/%" PRIu32 "/telemetry", s_config.base_topic, s_node_id);

        char telem_json[192];
        snprintf(telem_json, sizeof(telem_json),
                 "{\"uptime_s\":%" PRIu32 ",\"free_heap\":%" PRIu32 ",\"max_jitter_us\":%" PRIu64 ",\"max_exec_us\":%" PRIu64 ",\"overruns\":%" PRIu32 "}",
                 (uint32_t)(now_us / 1000000ULL),
                 (uint32_t)esp_get_free_heap_size(),
                 km.max_jitter,
                 km.max_exec_time,
                 km.overrun_count);

        esp_mqtt_client_publish(s_client, topic, telem_json, 0, 0, 0);
        s_status.messages_published++;
    }
}

/* ============================================================
   INCOMING COMMAND HANDLER (INGRESS)
============================================================ */

static void mqtt_handle_incoming_data(const char *topic, const char *data)
{
    s_status.messages_received++;

    char prefix[64];
    snprintf(prefix, sizeof(prefix), "%s/%" PRIu32 "/cmd/", s_config.base_topic, s_node_id);
    size_t prefix_len = strlen(prefix);

    if (strncmp(topic, prefix, prefix_len) != 0)
    {
        return;
    }

    const char *sub = topic + prefix_len;

    /* Comando de saída: output/<id>/set */
    if (strncmp(sub, "output/", 7) == 0)
    {
        int id = 0;
        if (sscanf(sub, "output/%d/set", &id) == 1)
        {
            int32_t val = 0;
            if (strcmp(data, "1") == 0 || strcasecmp(data, "ON") == 0 || strcasecmp(data, "true") == 0)
            {
                val = 1;
            }
            else if (strcmp(data, "0") == 0 || strcasecmp(data, "OFF") == 0 || strcasecmp(data, "false") == 0)
            {
                val = 0;
            }
            else
            {
                val = atoi(data);
            }

            int32_t effective_val = val;
            const char *reason = NULL;

            if (failsafe_guard_command((uint16_t)id, val, FAILSAFE_COMMAND_MANUAL, &effective_val, &reason))
            {
                if (io_command_push((uint16_t)id, effective_val))
                {
                    ESP_LOGI(TAG, "Comando MQTT Output %d -> %d aplicado com sucesso", id, (int)effective_val);
                }
            }
            else
            {
                ESP_LOGW(TAG, "Comando MQTT Output %d bloqueado pelo failsafe: %s", id, reason ? reason : "desconhecido");
            }
        }
    }
    /* Comando de variável genérica/setpoint: var/<id>/set */
    else if (strncmp(sub, "var/", 4) == 0)
    {
        int id = 0;
        if (sscanf(sub, "var/%d/set", &id) == 1)
        {
            int32_t val = atoi(data);
            io_command_push((uint16_t)id, val);
            ESP_LOGI(TAG, "Comando MQTT Setpoint Var %d -> %" PRId32 " aplicado", id, val);
        }
    }
    /* Comando de reboot */
    else if (strcmp(sub, "reboot") == 0)
    {
        ESP_LOGW(TAG, "Comando de reinicialização recebido via MQTT");
        vTaskDelay(pdMS_TO_TICKS(500));
        esp_restart();
    }
}

/* ============================================================
   ESP-MQTT EVENT CALLBACK
============================================================ */

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    (void)handler_args;
    (void)base;
    esp_mqtt_event_handle_t event = event_data;

    switch ((esp_mqtt_event_id_t)event_id)
    {
        case MQTT_EVENT_CONNECTED:
        {
            ESP_LOGI(TAG, "Conectado ao Broker MQTT com sucesso!");
            s_status.connected = true;

            char status_topic[64];
            snprintf(status_topic, sizeof(status_topic), "%s/%" PRIu32 "/status", s_config.base_topic, s_node_id);
            esp_mqtt_client_publish(s_client, status_topic, "online", 0, 1, 1);

            char sub_topic[64];
            snprintf(sub_topic, sizeof(sub_topic), "%s/%" PRIu32 "/cmd/#", s_config.base_topic, s_node_id);
            esp_mqtt_client_subscribe(s_client, sub_topic, 1);

            s_first_sync = true;

            if (s_config.ha_discovery)
            {
                mqtt_service_publish_discovery();
            }
            break;
        }

        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGW(TAG, "Desconectado do Broker MQTT");
            s_status.connected = false;
            s_status.reconnect_count++;
            break;

        case MQTT_EVENT_DATA:
        {
            char topic_buf[128];
            char data_buf[128];

            int t_len = event->topic_len < (sizeof(topic_buf) - 1) ? event->topic_len : (sizeof(topic_buf) - 1);
            int d_len = event->data_len < (sizeof(data_buf) - 1) ? event->data_len : (sizeof(data_buf) - 1);

            memcpy(topic_buf, event->topic, t_len);
            topic_buf[t_len] = '\0';

            memcpy(data_buf, event->data, d_len);
            data_buf[d_len] = '\0';

            mqtt_handle_incoming_data(topic_buf, data_buf);
            break;
        }

        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "Erro no cliente MQTT");
            break;

        default:
            break;
    }
}

/* ============================================================
   NETWORK READY LISTENER
============================================================ */

static void mqtt_on_network_ready(const network_ready_snapshot_t *snapshot, void *ctx)
{
    (void)ctx;
    if (snapshot && snapshot->ready)
    {
        if (s_config.enabled && !s_status.connected && s_config.broker_url[0] != '\0')
        {
            ESP_LOGI(TAG, "Rede disponível: iniciando conexão MQTT com %s", s_config.broker_url);
            mqtt_service_start();
        }
    }
    else
    {
        if (s_client && s_status.connected)
        {
            ESP_LOGW(TAG, "Rede desconectada: parando cliente MQTT");
            mqtt_service_stop();
        }
    }
}

/* ============================================================
   PUBLIC API
============================================================ */

esp_err_t mqtt_service_init(void)
{
    if (s_initialized)
    {
        return ESP_OK;
    }

    s_lock = xSemaphoreCreateMutex();
    s_node_id = node_identity_get();

    memset(s_last_outputs, -1, sizeof(s_last_outputs));
    memset(s_last_inputs, -1, sizeof(s_last_inputs));

    mqtt_nvs_load(&s_config);

    memset(&s_status, 0, sizeof(s_status));
    s_status.enabled = s_config.enabled;
    strncpy(s_status.broker_url, s_config.broker_url, sizeof(s_status.broker_url) - 1);
    strncpy(s_status.client_id, s_config.client_id, sizeof(s_status.client_id) - 1);
    strncpy(s_status.base_topic, s_config.base_topic, sizeof(s_status.base_topic) - 1);

    network_ready_register_callback(mqtt_on_network_ready, NULL);

    s_initialized = true;
    ESP_LOGI(TAG, "Módulo MQTT inicializado. Habilitado=%d, Broker=%s", s_config.enabled, s_config.broker_url);

    if (s_config.enabled && network_ready_is_up() && s_config.broker_url[0] != '\0')
    {
        mqtt_service_start();
    }

    return ESP_OK;
}

esp_err_t mqtt_service_start(void)
{
    if (!s_initialized || !s_config.enabled || s_config.broker_url[0] == '\0')
    {
        return ESP_ERR_INVALID_STATE;
    }

    xSemaphoreTake(s_lock, portMAX_DELAY);

    if (s_client)
    {
        esp_mqtt_client_stop(s_client);
        esp_mqtt_client_destroy(s_client);
        s_client = NULL;
    }

    static char will_topic[64];
    snprintf(will_topic, sizeof(will_topic), "%s/%" PRIu32 "/status", s_config.base_topic, s_node_id);

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address = {
                .uri = s_config.broker_url,
            },
        },
        .credentials = {
            .client_id = s_config.client_id[0] ? s_config.client_id : NULL,
            .username = s_config.username[0] ? s_config.username : NULL,
            .authentication = {
                .password = s_config.password[0] ? s_config.password : NULL,
            },
        },
        .session = {
            .last_will = {
                .topic = will_topic,
                .msg = "offline",
                .msg_len = 7,
                .qos = 1,
                .retain = 1,
            },
            .keepalive = 60,
        },
        .task = {
            .priority = 2,
            .stack_size = 4096,
        },
    };

    s_client = esp_mqtt_client_init(&mqtt_cfg);
    if (!s_client)
    {
        ESP_LOGE(TAG, "Falha ao alocar esp_mqtt_client");
        xSemaphoreGive(s_lock);
        return ESP_FAIL;
    }

    esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_err_t err = esp_mqtt_client_start(s_client);

    xSemaphoreGive(s_lock);
    return err;
}

esp_err_t mqtt_service_stop(void)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (s_client)
    {
        char status_topic[64];
        snprintf(status_topic, sizeof(status_topic), "%s/%" PRIu32 "/status", s_config.base_topic, s_node_id);
        esp_mqtt_client_publish(s_client, status_topic, "offline", 0, 1, 1);

        esp_mqtt_client_stop(s_client);
        esp_mqtt_client_destroy(s_client);
        s_client = NULL;
    }
    s_status.connected = false;
    xSemaphoreGive(s_lock);
    return ESP_OK;
}

esp_err_t mqtt_service_get_config(mqtt_service_config_t *out_cfg)
{
    if (!out_cfg) return ESP_ERR_INVALID_ARG;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    *out_cfg = s_config;
    xSemaphoreGive(s_lock);
    return ESP_OK;
}

esp_err_t mqtt_service_set_config(const mqtt_service_config_t *in_cfg)
{
    if (!in_cfg) return ESP_ERR_INVALID_ARG;

    xSemaphoreTake(s_lock, portMAX_DELAY);
    s_config = *in_cfg;
    s_status.enabled = s_config.enabled;
    strncpy(s_status.broker_url, s_config.broker_url, sizeof(s_status.broker_url) - 1);
    strncpy(s_status.client_id, s_config.client_id, sizeof(s_status.client_id) - 1);
    strncpy(s_status.base_topic, s_config.base_topic, sizeof(s_status.base_topic) - 1);

    mqtt_nvs_save(&s_config);
    xSemaphoreGive(s_lock);

    if (s_config.enabled && network_ready_is_up() && s_config.broker_url[0] != '\0')
    {
        return mqtt_service_start();
    }
    else
    {
        return mqtt_service_stop();
    }
}

void mqtt_service_get_status(mqtt_service_status_t *out_status)
{
    if (!out_status) return;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    *out_status = s_status;
    xSemaphoreGive(s_lock);
}

bool mqtt_service_is_connected(void)
{
    return s_status.connected;
}
