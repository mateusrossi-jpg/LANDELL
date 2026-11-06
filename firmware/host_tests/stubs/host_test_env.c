#include "host_test_env.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs.h"
#include "device_profile.h"
#include "io_map.h"

#include <string.h>

bool g_host_log_verbose = false;

static int64_t s_now_us = 1000000LL; /* Comeca em t=1000ms (pos-boot real do ESP32) */
static esp_reset_reason_t s_reset_reason = ESP_RST_POWERON;

uint32_t g_host_io_scan_calls = 0;
uint32_t g_host_io_update_calls = 0;
uint32_t g_host_fieldbus_calls = 0;
uint32_t g_host_automation_tick_calls = 0;
uint32_t g_host_control_kernel_calls = 0;

/* ============================================================
 * SIMULATED CLOCK & SYSTEM RESET REASON
 * ============================================================ */

int64_t esp_timer_get_time(void)
{
    return s_now_us;
}

void host_test_set_time_us(int64_t us)
{
    s_now_us = us;
}

void host_test_set_time_ms(int64_t ms)
{
    s_now_us = ms * 1000LL;
}

void host_test_advance_ms(int64_t delta_ms)
{
    s_now_us += delta_ms * 1000LL;
}

esp_reset_reason_t esp_reset_reason(void)
{
    return s_reset_reason;
}

void host_test_set_reset_reason(esp_reset_reason_t reason)
{
    s_reset_reason = reason;
}

/* ============================================================
 * IN-MEMORY NVS EMULATOR (BLOB / U8 / I32 + NAMESPACES)
 * ============================================================ */

#define HOST_NVS_MAX_NS      12
#define HOST_NVS_MAX_ENTRIES 64
#define HOST_NVS_MAX_BLOB    4096

typedef struct {
    bool used;
    char ns[16];
    char key[16];
    uint8_t data[HOST_NVS_MAX_BLOB];
    size_t len;
} host_nvs_entry_t;

typedef struct {
    bool open;
    char ns[16];
    nvs_open_mode_t mode;
} host_nvs_handle_slot_t;

static char s_known_ns[HOST_NVS_MAX_NS][16];
static size_t s_known_ns_count = 0;
static host_nvs_entry_t s_entries[HOST_NVS_MAX_ENTRIES];
static host_nvs_handle_slot_t s_handles[16];

void host_nvs_reset(void)
{
    memset(s_known_ns, 0, sizeof(s_known_ns));
    s_known_ns_count = 0;
    memset(s_entries, 0, sizeof(s_entries));
    memset(s_handles, 0, sizeof(s_handles));
}

static bool ns_exists(const char *ns)
{
    for (size_t i = 0; i < s_known_ns_count; i++) {
        if (strcmp(s_known_ns[i], ns) == 0) return true;
    }
    return false;
}

static void ns_ensure(const char *ns)
{
    if (ns_exists(ns)) return;
    if (s_known_ns_count < HOST_NVS_MAX_NS) {
        strncpy(s_known_ns[s_known_ns_count], ns, sizeof(s_known_ns[0]) - 1);
        s_known_ns_count++;
    }
}

static host_nvs_handle_slot_t *get_slot(nvs_handle_t h)
{
    if (h == 0 || h > 16) return NULL;
    host_nvs_handle_slot_t *slot = &s_handles[h - 1];
    return slot->open ? slot : NULL;
}

static host_nvs_entry_t *find_entry(const char *ns, const char *key)
{
    for (size_t i = 0; i < HOST_NVS_MAX_ENTRIES; i++) {
        if (s_entries[i].used &&
            strcmp(s_entries[i].ns, ns) == 0 &&
            strcmp(s_entries[i].key, key) == 0) {
            return &s_entries[i];
        }
    }
    return NULL;
}

esp_err_t nvs_open(const char *namespace_name, nvs_open_mode_t open_mode, nvs_handle_t *out_handle)
{
    if (!namespace_name || !out_handle) return ESP_ERR_INVALID_ARG;

    if (open_mode == NVS_READONLY && !ns_exists(namespace_name)) {
        return ESP_ERR_NVS_NOT_FOUND;
    }
    if (open_mode == NVS_READWRITE) {
        ns_ensure(namespace_name);
    }

    for (size_t i = 0; i < 16; i++) {
        if (!s_handles[i].open) {
            memset(&s_handles[i], 0, sizeof(s_handles[i]));
            s_handles[i].open = true;
            strncpy(s_handles[i].ns, namespace_name, sizeof(s_handles[i].ns) - 1);
            s_handles[i].mode = open_mode;
            *out_handle = (nvs_handle_t)(i + 1);
            return ESP_OK;
        }
    }
    return ESP_ERR_NO_MEM;
}

void nvs_close(nvs_handle_t handle)
{
    host_nvs_handle_slot_t *slot = get_slot(handle);
    if (slot) slot->open = false;
}

esp_err_t nvs_commit(nvs_handle_t handle)
{
    return get_slot(handle) ? ESP_OK : ESP_ERR_NVS_INVALID_HANDLE;
}

esp_err_t nvs_set_blob(nvs_handle_t handle, const char *key, const void *value, size_t length)
{
    host_nvs_handle_slot_t *slot = get_slot(handle);
    if (!slot || slot->mode != NVS_READWRITE) return ESP_ERR_NVS_INVALID_HANDLE;
    if (!key || (!value && length > 0) || length > HOST_NVS_MAX_BLOB) return ESP_ERR_INVALID_ARG;

    host_nvs_entry_t *entry = find_entry(slot->ns, key);
    if (!entry) {
        for (size_t i = 0; i < HOST_NVS_MAX_ENTRIES; i++) {
            if (!s_entries[i].used) {
                entry = &s_entries[i];
                break;
            }
        }
    }
    if (!entry) return ESP_ERR_NVS_NO_FREE_PAGES;

    memset(entry, 0, sizeof(*entry));
    entry->used = true;
    strncpy(entry->ns, slot->ns, sizeof(entry->ns) - 1);
    strncpy(entry->key, key, sizeof(entry->key) - 1);
    if (length > 0) memcpy(entry->data, value, length);
    entry->len = length;
    return ESP_OK;
}

esp_err_t nvs_get_blob(nvs_handle_t handle, const char *key, void *out_value, size_t *length)
{
    host_nvs_handle_slot_t *slot = get_slot(handle);
    if (!slot) return ESP_ERR_NVS_INVALID_HANDLE;
    if (!key || !length) return ESP_ERR_INVALID_ARG;

    host_nvs_entry_t *entry = find_entry(slot->ns, key);
    if (!entry) return ESP_ERR_NVS_NOT_FOUND;

    if (out_value == NULL) {
        *length = entry->len;
        return ESP_OK;
    }
    if (*length < entry->len) {
        *length = entry->len;
        return ESP_ERR_NVS_INVALID_LENGTH;
    }
    memcpy(out_value, entry->data, entry->len);
    *length = entry->len;
    return ESP_OK;
}

esp_err_t nvs_set_u8(nvs_handle_t handle, const char *key, uint8_t value)
{
    return nvs_set_blob(handle, key, &value, sizeof(value));
}

esp_err_t nvs_get_u8(nvs_handle_t handle, const char *key, uint8_t *out_value)
{
    size_t len = sizeof(uint8_t);
    return nvs_get_blob(handle, key, out_value, &len);
}

esp_err_t nvs_set_i32(nvs_handle_t handle, const char *key, int32_t value)
{
    return nvs_set_blob(handle, key, &value, sizeof(value));
}

esp_err_t nvs_get_i32(nvs_handle_t handle, const char *key, int32_t *out_value)
{
    size_t len = sizeof(int32_t);
    return nvs_get_blob(handle, key, out_value, &len);
}

esp_err_t nvs_erase_key(nvs_handle_t handle, const char *key)
{
    host_nvs_handle_slot_t *slot = get_slot(handle);
    if (!slot || slot->mode != NVS_READWRITE) return ESP_ERR_NVS_INVALID_HANDLE;
    host_nvs_entry_t *entry = find_entry(slot->ns, key);
    if (!entry) return ESP_ERR_NVS_NOT_FOUND;
    entry->used = false;
    return ESP_OK;
}

esp_err_t nvs_erase_all(nvs_handle_t handle)
{
    host_nvs_handle_slot_t *slot = get_slot(handle);
    if (!slot || slot->mode != NVS_READWRITE) return ESP_ERR_NVS_INVALID_HANDLE;
    for (size_t i = 0; i < HOST_NVS_MAX_ENTRIES; i++) {
        if (s_entries[i].used && strcmp(s_entries[i].ns, slot->ns) == 0) {
            s_entries[i].used = false;
        }
    }
    return ESP_OK;
}

bool host_nvs_corrupt_byte(const char *ns, const char *key, size_t offset)
{
    host_nvs_entry_t *entry = find_entry(ns, key);
    if (!entry || offset >= entry->len) return false;
    entry->data[offset] ^= 0xFFU;
    return true;
}

/* ============================================================
 * DEVICE PROFILE & HARDWARE DRIVER STUBS (6 DI / 6 DO DEFAULT)
 * ============================================================ */

int device_profile_output_count(void)
{
    return (int)ENDAP_DEFAULT_ACTIVE_OUTPUTS; /* 6 saidas: IDs 100..105 */
}

uint16_t device_profile_output_id_at(int index)
{
    if (index < 0 || index >= (int)ENDAP_DEFAULT_ACTIVE_OUTPUTS) return 0U;
    return ENDAP_OUTPUT_ID(index);
}

bool device_profile_is_valid_output(uint16_t id)
{
    return id >= ENDAP_OUTPUT_ID(0) && id < ENDAP_OUTPUT_ID(ENDAP_DEFAULT_ACTIVE_OUTPUTS);
}

void io_driver_scan_inputs(void)      { g_host_io_scan_calls++; }
void io_driver_update(void)           { g_host_io_update_calls++; }
void fieldbus_tick(void)              { g_host_fieldbus_calls++; }
void automation_engine_tick_1ms(void) { g_host_automation_tick_calls++; }
void control_kernel_task(void)        { g_host_control_kernel_calls++; }

void host_test_reset_env(void)
{
    s_now_us = 1000000LL;
    s_reset_reason = ESP_RST_POWERON;
    g_host_io_scan_calls = 0;
    g_host_io_update_calls = 0;
    g_host_fieldbus_calls = 0;
    g_host_automation_tick_calls = 0;
    g_host_control_kernel_calls = 0;
    host_nvs_reset();
}
