#pragma once

#include <stdbool.h>
#include <stdio.h>

extern bool g_host_log_verbose;

#define ESP_LOGI(tag, fmt, ...) \
    do { if (g_host_log_verbose) fprintf(stderr, "[I][%s] " fmt "\n", (tag), ##__VA_ARGS__); } while (0)

#define ESP_LOGW(tag, fmt, ...) \
    do { if (g_host_log_verbose) fprintf(stderr, "[W][%s] " fmt "\n", (tag), ##__VA_ARGS__); } while (0)

#define ESP_LOGE(tag, fmt, ...) \
    do { if (g_host_log_verbose) fprintf(stderr, "[E][%s] " fmt "\n", (tag), ##__VA_ARGS__); } while (0)

#define ESP_LOGD(tag, fmt, ...) \
    do { if (g_host_log_verbose) fprintf(stderr, "[D][%s] " fmt "\n", (tag), ##__VA_ARGS__); } while (0)
