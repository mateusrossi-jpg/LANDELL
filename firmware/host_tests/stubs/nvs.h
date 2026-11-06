#pragma once

#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

typedef uint32_t nvs_handle_t;

typedef enum {
    NVS_READONLY = 0,
    NVS_READWRITE = 1,
} nvs_open_mode_t;

#define ESP_ERR_NVS_BASE            0x1100
#define ESP_ERR_NVS_NOT_FOUND       (ESP_ERR_NVS_BASE + 0x02)
#define ESP_ERR_NVS_INVALID_HANDLE  (ESP_ERR_NVS_BASE + 0x09)
#define ESP_ERR_NVS_INVALID_LENGTH  (ESP_ERR_NVS_BASE + 0x0c)
#define ESP_ERR_NVS_NO_FREE_PAGES   (ESP_ERR_NVS_BASE + 0x0d)
#define ESP_ERR_NVS_NEW_VERSION_FOUND (ESP_ERR_NVS_BASE + 0x10)

esp_err_t nvs_open(const char *namespace_name, nvs_open_mode_t open_mode, nvs_handle_t *out_handle);
void nvs_close(nvs_handle_t handle);
esp_err_t nvs_commit(nvs_handle_t handle);

esp_err_t nvs_set_blob(nvs_handle_t handle, const char *key, const void *value, size_t length);
esp_err_t nvs_get_blob(nvs_handle_t handle, const char *key, void *out_value, size_t *length);

esp_err_t nvs_set_u8(nvs_handle_t handle, const char *key, uint8_t value);
esp_err_t nvs_get_u8(nvs_handle_t handle, const char *key, uint8_t *out_value);

esp_err_t nvs_set_i32(nvs_handle_t handle, const char *key, int32_t value);
esp_err_t nvs_get_i32(nvs_handle_t handle, const char *key, int32_t *out_value);

esp_err_t nvs_erase_key(nvs_handle_t handle, const char *key);
esp_err_t nvs_erase_all(nvs_handle_t handle);
