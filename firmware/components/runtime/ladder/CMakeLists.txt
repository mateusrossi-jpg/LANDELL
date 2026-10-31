idf_component_register(SRCS "ladder_engine.c" "ladder_pid.c"
                    INCLUDE_DIRS "."
                    REQUIRES state esp_common nvs_flash)
