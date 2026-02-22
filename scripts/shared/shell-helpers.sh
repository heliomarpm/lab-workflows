#!/usr/bin/env bash
# =============================================================================
# shell-helpers.sh
# Shared utility functions for all QA scripts.
# Source this file at the top of any script: source "$(dirname "$0")/../shared/shell-helpers.sh"
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  CLR_RESET="\033[0m"
  CLR_BOLD="\033[1m"
  CLR_GREEN="\033[32m"
  CLR_YELLOW="\033[33m"
  CLR_RED="\033[31m"
  CLR_CYAN="\033[36m"
  CLR_GRAY="\033[90m"
else
  CLR_RESET="" CLR_BOLD="" CLR_GREEN="" CLR_YELLOW="" CLR_RED="" CLR_CYAN="" CLR_GRAY=""
fi

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo -e "${CLR_CYAN}ℹ ${CLR_RESET}${*}"; }
log_success() { echo -e "${CLR_GREEN}✅ ${CLR_RESET}${*}"; }
log_warn()    { echo -e "${CLR_YELLOW}⚠️  ${CLR_RESET}${*}"; }
log_error()   { echo -e "${CLR_RED}❌ ${CLR_RESET}${*}" >&2; }
log_step()    { echo -e "\n${CLR_BOLD}${CLR_CYAN}▶ ${*}${CLR_RESET}"; }
log_debug()   { [ "${DEBUG:-0}" = "1" ] && echo -e "${CLR_GRAY}[debug] ${*}${CLR_RESET}" || true; }

# ── GitHub Actions helpers ────────────────────────────────────────────────────

# gha_set_output KEY VALUE
# Writes a key=value pair to GITHUB_OUTPUT (multiline safe).
gha_set_output() {
  local key="$1"
  local value="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "${key}<<__GHA_EOF__"
      echo "${value}"
      echo "__GHA_EOF__"
    } >> "$GITHUB_OUTPUT"
    log_debug "GITHUB_OUTPUT: ${key}=${value}"
  else
    log_debug "[dry-run] GITHUB_OUTPUT not set — skipping: ${key}=${value}"
  fi
}

# gha_error TITLE MESSAGE
gha_error() { echo "::error title=${1}::${2}"; }

# gha_warning TITLE MESSAGE
gha_warning() { echo "::warning title=${1}::${2}"; }

# gha_notice TITLE MESSAGE
gha_notice() { echo "::notice title=${1}::${2}"; }

# gha_group TITLE — opens a collapsible log group
gha_group() { echo "::group::${*}"; }
gha_endgroup() { echo "::endgroup::"; }

# ── JSON helpers ──────────────────────────────────────────────────────────────

# json_write PATH JSON_STRING
# Writes a JSON string to a file, pretty-printed.
json_write() {
  local filepath="$1"
  local json="$2"
  mkdir -p "$(dirname "$filepath")"
  echo "$json" | python3 -m json.tool > "$filepath" 2>/dev/null || echo "$json" > "$filepath"
  log_debug "JSON written to: $filepath"
}

# json_escape STRING — escapes a string for safe embedding in JSON
json_escape() {
  python3 -c "import sys, json; print(json.dumps(sys.stdin.read().rstrip('\n')))" <<< "$1"
}

# ── Dependency checks ─────────────────────────────────────────────────────────

# require_cmd CMD [INSTALL_HINT]
require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required command not found: '$cmd'"
    [ -n "$hint" ] && log_error "Install hint: $hint"
    exit 1
  fi
  log_debug "Found command: $cmd ($(command -v "$cmd"))"
}

# ── Misc ──────────────────────────────────────────────────────────────────────

# elapsed START_SECONDS — returns human-readable elapsed time
elapsed() {
  local start="$1"
  local end
  end=$(date +%s)
  local diff=$(( end - start ))
  echo "${diff}s"
}

# is_ci — returns 0 (true) if running inside GitHub Actions
is_ci() { [ -n "${GITHUB_ACTIONS:-}" ]; }

# abort MESSAGE — logs error and exits 1
abort() {
  log_error "$*"
  exit 1
}