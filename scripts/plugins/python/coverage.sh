#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/python/coverage.sh — Calculates test coverage for Python (pytest-cov).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-coverage-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to: $PROJECT_PATH"
log_step "Python — Coverage"

require_cmd python3
pip install pytest pytest-cov -q

START=$(date +%s)
OUTPUT=$(pytest --cov=. --cov-report=term-missing 2>&1) || true
COVERAGE_PCT=$(echo "$OUTPUT" | grep "TOTAL" | grep -oP '(\d+)(?=\s*%)' | tail -1)
[ -z "$COVERAGE_PCT" ] && { log_warn "Could not parse coverage. Defaulting to 0."; COVERAGE_PCT="0"; }
log_success "Coverage: ${COVERAGE_PCT}% ($(elapsed $START))"

JSON="{\"coverage_pct\": ${COVERAGE_PCT}, \"coverage_tool\": \"pytest-cov\", \"duration\": \"$(elapsed $START)\"}"
json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "coverage_pct"  "$COVERAGE_PCT"
gha_set_output "coverage_tool" "pytest-cov"
gha_set_output "output_file"   "$OUTPUT_FILE"