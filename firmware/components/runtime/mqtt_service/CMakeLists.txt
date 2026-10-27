idf_component_register(
    SRCS "mqtt_service.c"
    INCLUDE_DIRS "include"
    REQUIRES
        mqtt
        state
        io_command
        io_binding
        failsafe
        device_profile
        node_identity
        network_ready
        nvs_flash
        kernel_metrics
        json
        esp_timer
)
