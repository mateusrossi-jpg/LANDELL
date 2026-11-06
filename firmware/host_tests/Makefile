CC      ?= gcc
CFLAGS  := -std=c11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter -Wno-stringop-truncation

FW_ROOT := ..
BUILD   := build

INCLUDES := \
	-Istubs \
	-I$(FW_ROOT)/components/runtime/ladder \
	-I$(FW_ROOT)/components/runtime/pve/include \
	-I$(FW_ROOT)/components/runtime/failsafe/include \
	-I$(FW_ROOT)/components/runtime/event_bus/include \
	-I$(FW_ROOT)/components/runtime/snapshot/include \
	-I$(FW_ROOT)/components/runtime/io_command/include \
	-I$(FW_ROOT)/components/runtime/io_driver/include \
	-I$(FW_ROOT)/components/runtime/automation/include \
	-I$(FW_ROOT)/components/runtime/fieldbus/include \
	-I$(FW_ROOT)/components/data/state/include \
	-I$(FW_ROOT)/components/data/io_image/include \
	-I$(FW_ROOT)/components/device_profile/include \
	-I$(FW_ROOT)/components/observability/kernel_trace/include \
	-I$(FW_ROOT)/components/kernel/scheduler/include \
	-I$(FW_ROOT)/components/kernel/control_kernel/include \
	-I$(FW_ROOT)/components/comm/parser/include \
	-I$(FW_ROOT)/components/comm/protocol/include

CORE_SRCS := \
	stubs/host_test_env.c \
	$(FW_ROOT)/components/data/state/state.c \
	$(FW_ROOT)/components/data/io_image/io_image.c \
	$(FW_ROOT)/components/runtime/event_bus/event_bus.c \
	$(FW_ROOT)/components/runtime/snapshot/snapshot.c \
	$(FW_ROOT)/components/runtime/io_command/io_command.c \
	$(FW_ROOT)/components/runtime/ladder/ladder_pid.c \
	$(FW_ROOT)/components/runtime/ladder/ladder_engine.c \
	$(FW_ROOT)/components/runtime/pve/pve.c \
	$(FW_ROOT)/components/runtime/failsafe/failsafe.c \
	$(FW_ROOT)/components/kernel/scheduler/scheduler.c \
	$(FW_ROOT)/components/comm/parser/parser.c \
	$(FW_ROOT)/components/comm/protocol/protocol.c

BINS := \
	$(BUILD)/test_embedded_self_tests \
	$(BUILD)/ladder_pid_host_test \
	$(BUILD)/test_ladder_vm \
	$(BUILD)/test_core_runtime \
	$(BUILD)/ladder_vm_cli

.PHONY: all test clean

all: $(BINS)

$(BUILD):
	@mkdir -p $(BUILD)

$(BUILD)/test_embedded_self_tests: test_embedded_self_tests.c $(CORE_SRCS) \
	$(FW_ROOT)/components/runtime/pve/pve_self_test.c \
	$(FW_ROOT)/components/kernel/scheduler/scheduler_self_test.c | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ \
		test_embedded_self_tests.c \
		$(FW_ROOT)/components/runtime/pve/pve_self_test.c \
		$(FW_ROOT)/components/kernel/scheduler/scheduler_self_test.c \
		$(CORE_SRCS)

$(BUILD)/ladder_pid_host_test: $(FW_ROOT)/components/runtime/ladder/host_test/ladder_pid_host_test.c \
	$(FW_ROOT)/components/runtime/ladder/ladder_pid.c | $(BUILD)
	$(CC) $(CFLAGS) -I$(FW_ROOT)/components/runtime/ladder -o $@ \
		$(FW_ROOT)/components/runtime/ladder/host_test/ladder_pid_host_test.c \
		$(FW_ROOT)/components/runtime/ladder/ladder_pid.c

$(BUILD)/test_ladder_vm: test_ladder_vm.c $(CORE_SRCS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ test_ladder_vm.c $(CORE_SRCS)

$(BUILD)/test_core_runtime: test_core_runtime.c $(CORE_SRCS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ test_core_runtime.c $(CORE_SRCS)

$(BUILD)/ladder_vm_cli: ladder_vm_cli.c $(CORE_SRCS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ ladder_vm_cli.c $(CORE_SRCS)

test: all
	@./$(BUILD)/test_embedded_self_tests
	@echo ""
	@echo "=== [2/4] Industrial PID Golden Vectors Suite (ladder_pid_host_test) ==="
	@./$(BUILD)/ladder_pid_host_test
	@echo ""
	@./$(BUILD)/test_ladder_vm
	@echo ""
	@./$(BUILD)/test_core_runtime

clean:
	rm -rf $(BUILD)
