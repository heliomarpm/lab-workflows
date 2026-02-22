#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/dotnet/test.sh — Runs unit tests for a .NET project.
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-test-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to: $PROJECT_PATH"
log_step ".NET — Unit Tests"

require_cmd dotnet "https://dotnet.microsoft.com"

HAS_TESTS="false"
TESTS_PASSED="false"

if find . -name "*Tests*.csproj" -o -name "*Test*.csproj" 2>/dev/null | grep -q .; then
  HAS_TESTS="true"
  START=$(date +%s)
  log_info "Running: dotnet test"
  if dotnet test --logger "console;verbosity=normal"; then
    TESTS_PASSED="true"
    log_success "Tests passed ($(elapsed $START))"
  else
    log_error "Tests failed"
    gha_error ".NET Tests Failed" "dotnet test exited with a non-zero status."
  fi
else
  log_warn "No test projects found (*Tests*.csproj or *Test*.csproj)."
  gha_warning ".NET Tests" "No test project files found."
fi

JSON="{\"has_tests\": ${HAS_TESTS}, \"tests_passed\": $([ "$HAS_TESTS" = "true" ] && echo "$TESTS_PASSED" || echo "null"), \"test_command\": \"dotnet test\"}"
json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "has_tests"    "$HAS_TESTS"
gha_set_output "tests_passed" "$TESTS_PASSED"
gha_set_output "output_file"  "$OUTPUT_FILE"
[ "$TESTS_PASSED" = "true" ] || [ "$HAS_TESTS" = "false" ] && exit 0 || exit 1