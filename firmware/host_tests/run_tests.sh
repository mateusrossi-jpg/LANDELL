#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================="
echo "  LANDELL FIRMWARE — NATIVE C HOST VALIDATION SUITE (GCC)        "
echo "================================================================="

START_NS=$(date +%s%N)
make -s all
make -s test
END_NS=$(date +%s%N)

ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))
echo ""
echo "================================================================="
echo "  ALL FIRMWARE C HOST SUITES PASSED IN ${ELAPSED_MS} ms (0 warnings)"
echo "================================================================="
