#pragma once

#include "esp_err.h"
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MQTT_MAX_URL_LEN        128
#define MQTT_MAX_CLIENT_ID_LEN  32
#define MQTT_MAX_USER_LEN       32
#define MQTT_MAX_PASS_LEN       64
#define MQTT_MAX_TOPIC_LEN      32

typedef struct
{
    bool enabled;
    char broker_url[MQTT_MAX_URL_LEN];
    char client_id[MQTT_MAX_CLIENT_ID_LEN];
    char username[MQTT_MAX_USER_LEN];
    char password[MQTT_MAX_PASS_LEN];
    char base_topic[MQTT_MAX_TOPIC_LEN];
    bool ha_discovery;
    uint16_t publish_interval_ms;
} mqtt_service_config_t;

typedef struct
{
    bool connected;
    bool enabled;
    uint32_t messages_published;
    uint32_t messages_received;
    uint32_t reconnect_count;
    char broker_url[MQTT_MAX_URL_LEN];
    char client_id[MQTT_MAX_CLIENT_ID_LEN];
    char base_topic[MQTT_MAX_TOPIC_LEN];
} mqtt_service_status_t;

/**
 * @brief Inicializa o serviço MQTT (lê NVS, registra callback de rede).
 */
esp_err_t mqtt_service_init(void);

/**
 * @brief Conecta ao Broker MQTT caso configurado e habilitado.
 */
esp_err_t mqtt_service_start(void);

/**
 * @brief Desconecta do Broker MQTT.
 */
esp_err_t mqtt_service_stop(void);

/**
 * @brief Obtém a configuração salva em NVS.
 */
esp_err_t mqtt_service_get_config(mqtt_service_config_t *out_cfg);

/**
 * @brief Salva a configuração em NVS e reinicia o cliente se necessário.
 */
esp_err_t mqtt_service_set_config(const mqtt_service_config_t *in_cfg);

/**
 * @brief Obtém o status operacional atual.
 */
void mqtt_service_get_status(mqtt_service_status_t *out_status);

/**
 * @brief Informa se o cliente MQTT está com sessão ativa no broker.
 */
bool mqtt_service_is_connected(void);

/**
 * @brief Processamento periódico assíncrono no Core 0 (chamado via core_aux_task).
 */
void mqtt_service_process(void);

/**
 * @brief Publica manualmente as definições de Home Assistant Auto-Discovery.
 */
void mqtt_service_publish_discovery(void);

#ifdef __cplusplus
}
#endif
