idf_component_register(
    SRCS "io_driver.c"
    INCLUDE_DIRS "include"
    REQUIRES 
    	driver
        state
        device_profile
        failsafe
        io_image
        cluster
        protocol
    PRIV_REQUIRES kernel_trace
        http_server
        esp_driver_gpio
        esp_driver_dac
        esp_adc
        pve
)
