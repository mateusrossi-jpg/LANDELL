#ifndef SCHEDULER_SELF_TEST_H
#define SCHEDULER_SELF_TEST_H

#include <stdbool.h>

/**
 * @brief Runs unit/self-tests for scheduler IO tasks.
 *
 * Exercises scheduler_run_io() and scheduler_run_io_apply() ensuring:
 *  - io_command popping and budget enforcement (budget = 1 per run)
 *  - State updating upon processing commands
 *  - Double-buffer swapping in io_image during scheduler_run_io
 *  - Output driver update execution via scheduler_run_io_apply
 *
 * @return true if all tests pass, false otherwise.
 */
bool scheduler_run_self_tests(void);

#endif /* SCHEDULER_SELF_TEST_H */
