#pragma once

/* ====================================================================
 * ENDAP API FIELD CONSTRAINTS (C <-> DART SINGLE SOURCE OF TRUTH)
 * ==================================================================== */

/* Endpoints URIs */
#define ENDAP_API_URI_DIAGNOSTICS "/api/diagnostics"
#define ENDAP_API_URI_STATUS      "/api/status"
#define ENDAP_API_URI_IO_MAP      "/api/io/map"
#define ENDAP_API_URI_NODES       "/api/cluster/nodes"

/* /api/diagnostics - Kernel Determinism Fields */
#define ENDAP_FIELD_UPTIME_MS              "uptime_ms"
#define ENDAP_FIELD_K_PERIOD_US            "k_period_us"
#define ENDAP_FIELD_K_JITTER_MIN           "k_jitter_min"
#define ENDAP_FIELD_K_JITTER_AVG           "k_jitter_avg"
#define ENDAP_FIELD_K_JITTER_MAX           "k_jitter_max"
#define ENDAP_FIELD_K_EXEC_MAX             "k_exec_max"
#define ENDAP_FIELD_K_DEADLINE_MISS        "k_deadline_miss"
#define ENDAP_FIELD_K_DEADLINE_MISS_RECENT "k_deadline_miss_recent"
#define ENDAP_FIELD_K_OVERRUN              "k_overrun"
#define ENDAP_FIELD_K_LOOP_FAULT           "k_loop_fault"

/* /api/diagnostics - Cluster Metrics Fields */
#define ENDAP_FIELD_CLUSTER_ACTIVE         "cluster_active"
#define ENDAP_FIELD_C_TOTAL                "c_total"
#define ENDAP_FIELD_C_ONLINE               "c_online"
#define ENDAP_FIELD_C_SUSPECT              "c_suspect"
#define ENDAP_FIELD_C_OFFLINE              "c_offline"
#define ENDAP_FIELD_C_HEALTH               "c_health"
#define ENDAP_FIELD_C_SELF                 "c_self"
#define ENDAP_FIELD_C_MASTER               "c_master"

/* /api/cluster/nodes - Node Item Fields */
#define ENDAP_FIELD_NODE_ID                "node_id"
#define ENDAP_FIELD_CLUSTER_STATE          "cluster_state"
#define ENDAP_FIELD_REGISTRY_STATE         "registry_state"
#define ENDAP_FIELD_OPERATIONAL            "operational"
