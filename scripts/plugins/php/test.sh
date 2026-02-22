#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/php/test.sh — Runs unit tests for a PHP project (PHPUnit).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-test-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to: $PROJECT_PATH"
log_step "PHP — Unit Tests"

require_cmd php      "https://www.php.net"
require_cmd composer "https://getcomposer.org"

[ ! -d "vendor" ] && { log_info "Installing composer dependencies..."; composer install --no-interaction --prefer-dist; }

HAS_TESTS="false"
TESTS_PASSED="false"

if [ -f "vendor/bin/phpunit" ] || [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
  HAS_TESTS="true"
  START=$(date +%s)
  log_info "Running: ./vendor/bin/phpunit"
  if ./vendor/bin/phpunit; then
    TESTS_PASSED="true"
    log_success "Tests passed ($(elapsed $START))"
  else
    log_error "Tests failed"
    gha_error "PHP Tests Failed" "PHPUnit exited with a non-zero status."
  fi
else
  log_warn "No PHPUnit configuration found (phpunit.xml / phpunit.xml.dist)."
  gha_warning "PHP Tests" "No PHPUnit configuration found."
fi

JSON="{\"has_tests\": ${HAS_TESTS}, \"tests_passed\": $([ "$HAS_TESTS" = "true" ] && echo "$TESTS_PASSED" || echo "null"), \"test_command\": \"./vendor/bin/phpunit\"}"
json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "has_tests"    "$HAS_TESTS"
gha_set_output "tests_passed" "$TESTS_PASSED"
gha_set_output "output_file"  "$OUTPUT_FILE"
[ "$TESTS_PASSED" = "true" ] || [ "$HAS_TESTS" = "false" ] && exit 0 || exit 1