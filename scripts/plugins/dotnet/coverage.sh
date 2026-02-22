#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/dotnet/coverage.sh — Calculates test coverage for .NET (Cobertura).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-coverage-output.json"

cd "$PROJECT_PATH" || abort "Cannot cd to: $PROJECT_PATH"
log_step ".NET — Coverage"

require_cmd dotnet "https://dotnet.microsoft.com"

START=$(date +%s)
dotnet test --collect:"XPlat Code Coverage" --results-directory ./TestResults 2>&1 || true
COVERAGE_FILE=$(find ./TestResults -name "coverage.cobertura.xml" 2>/dev/null | head -1)

if [ -n "$COVERAGE_FILE" ]; then
  COVERAGE_PCT=$(python3 - <<PYEOF
import xml.etree.ElementTree as ET
tree = ET.parse('${COVERAGE_FILE}')
root = tree.getroot()
rate = float(root.get('line-rate', 0)) * 100
print(f'{rate:.1f}')
PYEOF
)
else
  log_warn "Could not find coverage.cobertura.xml in ./TestResults"
  COVERAGE_PCT="0"
fi

log_success "Coverage: ${COVERAGE_PCT}% ($(elapsed $START))"

JSON="{\"coverage_pct\": ${COVERAGE_PCT}, \"coverage_tool\": \"dotnet-coverage\", \"duration\": \"$(elapsed $START)\"}"
json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "coverage_pct"  "$COVERAGE_PCT"
gha_set_output "coverage_tool" "dotnet-coverage"
gha_set_output "output_file"   "$OUTPUT_FILE"