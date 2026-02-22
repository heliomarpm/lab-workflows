#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/node/coverage.sh
# Calculates test coverage for a Node.js project.
# Supports Jest (default) and c8. Falls back to custom command via COVERAGE_CMD.
#
# Usage:
#   ./coverage.sh [PROJECT_PATH]
#
# Environment:
#   COVERAGE_CMD    Custom command to run (optional). Must print a line with "XX.XX%"
#
# Outputs (GITHUB_OUTPUT + /tmp/qa-coverage-output.json):
#   coverage_pct    Numeric coverage percentage (e.g. "87.5")
#   coverage_tool   Tool used (jest | c8 | custom | unknown)
#   output_file     Path to JSON output
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-coverage-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to project path: $PROJECT_PATH"
log_step "Node.js — Coverage"
log_info "Working directory: $(pwd)"

require_cmd node
require_cmd npm

if [ ! -d "node_modules" ]; then
  log_info "node_modules not found — installing dependencies..."
  npm ci --prefer-offline 2>/dev/null || npm install
fi

# ── Run coverage ───────────────────────────────────────────────────────────────
COVERAGE_PCT=""
COVERAGE_TOOL="unknown"
START=$(date +%s)

extract_pct() {
  # Extracts the last percentage value from multi-line output
  grep -oP '(\d+\.\d+|\d+)(?=\s*%)' <<< "$1" | tail -1
}

if [ -n "${COVERAGE_CMD:-}" ]; then
  COVERAGE_TOOL="custom"
  log_info "Running custom coverage command: ${COVERAGE_CMD}"
  OUTPUT=$(eval "$COVERAGE_CMD" 2>&1) || true
  COVERAGE_PCT=$(extract_pct "$OUTPUT")

elif node -e "require('./node_modules/.bin/jest')" 2>/dev/null || \
     [ -f "jest.config.js" ] || [ -f "jest.config.ts" ] || \
     node -e "const p=require('./package.json'); process.exit(p.jest ? 0 : 1)" 2>/dev/null; then
  COVERAGE_TOOL="jest"
  log_info "Running: npx jest --coverage --coverageReporters=text-summary"
  OUTPUT=$(npx jest --coverage --coverageReporters=text-summary --passWithNoTests 2>&1) || true
  COVERAGE_PCT=$(extract_pct "$OUTPUT")

elif command -v c8 &>/dev/null || [ -f "node_modules/.bin/c8" ]; then
  COVERAGE_TOOL="c8"
  log_info "Running: npx c8 --reporter=text-summary npm test"
  OUTPUT=$(npx c8 --reporter=text-summary npm test 2>&1) || true
  COVERAGE_PCT=$(extract_pct "$OUTPUT")

else
  log_warn "No recognised coverage tool found (jest, c8). Set COVERAGE_CMD to use a custom command."
  gha_warning "Node Coverage" "No coverage tool detected. Install jest or c8, or set COVERAGE_CMD."
fi

if [ -z "$COVERAGE_PCT" ]; then
  log_warn "Could not parse coverage percentage from output."
  COVERAGE_PCT="0"
fi

log_success "Coverage: ${COVERAGE_PCT}% (tool: ${COVERAGE_TOOL}, $(elapsed $START))"

# ── Output ────────────────────────────────────────────────────────────────────
JSON=$(cat <<EOF
{
  "coverage_pct": ${COVERAGE_PCT},
  "coverage_tool": "${COVERAGE_TOOL}",
  "duration": "$(elapsed $START)"
}
EOF
)

json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "coverage_pct"  "$COVERAGE_PCT"
gha_set_output "coverage_tool" "$COVERAGE_TOOL"
gha_set_output "output_file"   "$OUTPUT_FILE"