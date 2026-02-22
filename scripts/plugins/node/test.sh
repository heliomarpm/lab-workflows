#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/node/test.sh
# Runs unit tests for a Node.js project.
# Auto-installs dependencies if node_modules is absent.
#
# Usage:
#   ./test.sh [PROJECT_PATH]
#
# Outputs (GITHUB_OUTPUT + /tmp/qa-test-output.json):
#   has_tests       "true" | "false"
#   tests_passed    "true" | "false" | "" (if no tests found)
#   output_file     Path to JSON output
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-test-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to project path: $PROJECT_PATH"
log_step "Node.js — Unit Tests"
log_info "Working directory: $(pwd)"

# ── Dependency checks ──────────────────────────────────────────────────────────
require_cmd node "https://nodejs.org"
require_cmd npm  "https://nodejs.org"

# ── Detect test script ─────────────────────────────────────────────────────────
if [ ! -f "package.json" ]; then
  abort "package.json not found in: $(pwd)"
fi

HAS_TEST_SCRIPT=$(node -e "
  const p = require('./package.json');
  const hasTest = p.scripts && p.scripts.test && !p.scripts.test.includes('no test specified');
  process.exit(hasTest ? 0 : 1);
" && echo "true" || echo "false")

if [ "$HAS_TEST_SCRIPT" = "false" ]; then
  log_warn "No test script found in package.json."
  gha_warning "Node Tests" "No test script defined in package.json."

  JSON="{\"has_tests\": false, \"tests_passed\": null, \"test_command\": null}"
  json_write "$OUTPUT_FILE" "$JSON"
  gha_set_output "has_tests"    "false"
  gha_set_output "tests_passed" ""
  gha_set_output "output_file"  "$OUTPUT_FILE"
  exit 0
fi

# ── Install dependencies ───────────────────────────────────────────────────────
if [ ! -d "node_modules" ]; then
  log_info "node_modules not found — installing dependencies..."
  npm ci --prefer-offline 2>/dev/null || npm install
fi

# ── Run tests ─────────────────────────────────────────────────────────────────
TEST_CMD="npm test"
log_info "Running: ${TEST_CMD}"

TESTS_PASSED="false"
START=$(date +%s)

if $TEST_CMD; then
  TESTS_PASSED="true"
  log_success "Tests passed ($(elapsed $START))"
else
  log_error "Tests failed ($(elapsed $START))"
  gha_error "Node Tests Failed" "npm test exited with a non-zero status."
fi

# ── Output ────────────────────────────────────────────────────────────────────
JSON=$(cat <<EOF
{
  "has_tests": true,
  "tests_passed": $TESTS_PASSED,
  "test_command": "${TEST_CMD}",
  "duration": "$(elapsed $START)"
}
EOF
)

json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "has_tests"    "true"
gha_set_output "tests_passed" "$TESTS_PASSED"
gha_set_output "output_file"  "$OUTPUT_FILE"

[ "$TESTS_PASSED" = "true" ] && exit 0 || exit 1