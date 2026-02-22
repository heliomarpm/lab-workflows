#!/usr/bin/env bash
# =============================================================================
# detect-stack.sh
# Detects the technology stack of a project by inspecting characteristic files.
#
# Usage:
#   ./detect-stack.sh [PROJECT_PATH] [EXPLICIT_STACK]
#
# Arguments:
#   PROJECT_PATH    Path to inspect (default: ".")
#   EXPLICIT_STACK  If provided and not "auto", skip detection and use this value
#
# Outputs (GITHUB_OUTPUT + JSON):
#   stack           Detected stack name (node | php | dotnet | python | go | unknown)
#   stack_source    "explicit" | "auto-detect"
#   output_file     Path to the generated JSON output file
#
# Exit codes:
#   0  Success
#   1  Error
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell-helpers.sh"

# ── Args ──────────────────────────────────────────────────────────────────────
PROJECT_PATH="${1:-.}"
EXPLICIT_STACK="${2:-auto}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-detect-stack-output.json"

# ── Validate path ─────────────────────────────────────────────────────────────
if [ ! -d "$PROJECT_PATH" ]; then
  abort "Project path does not exist: '$PROJECT_PATH'"
fi

cd "$PROJECT_PATH"
log_step "Stack Detection"
log_info "Project path: $(pwd)"

# ── Detection ─────────────────────────────────────────────────────────────────
STACK=""
STACK_SOURCE=""

if [ "$EXPLICIT_STACK" != "auto" ] && [ -n "$EXPLICIT_STACK" ]; then
  STACK="$EXPLICIT_STACK"
  STACK_SOURCE="explicit"
  log_success "Stack provided explicitly: ${STACK}"
else
  STACK_SOURCE="auto-detect"
  log_info "Auto-detecting stack..."

  if [ -f "package.json" ]; then
    STACK="node"
  elif [ -f "composer.json" ]; then
    STACK="php"
  elif find . -maxdepth 3 -name "*.csproj" 2>/dev/null | grep -q .; then
    STACK="dotnet"
  elif [ -f "go.mod" ]; then
    STACK="go"
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    STACK="python"
  else
    STACK="unknown"
  fi

  if [ "$STACK" = "unknown" ]; then
    log_warn "Could not detect stack. No characteristic files found."
    gha_warning "Stack Detection" "Could not auto-detect stack. Falling back to 'unknown'."
  else
    log_success "Detected stack: ${STACK}"
  fi
fi

# ── Build JSON output ─────────────────────────────────────────────────────────
JSON=$(cat <<EOF
{
  "stack": "${STACK}",
  "stack_source": "${STACK_SOURCE}",
  "project_path": "$(pwd)"
}
EOF
)

json_write "$OUTPUT_FILE" "$JSON"
log_info "Output written to: ${OUTPUT_FILE}"

# ── Export to GITHUB_OUTPUT ───────────────────────────────────────────────────
gha_set_output "stack"        "$STACK"
gha_set_output "stack_source" "$STACK_SOURCE"
gha_set_output "output_file"  "$OUTPUT_FILE"

log_success "Done — stack: ${STACK} (${STACK_SOURCE})"