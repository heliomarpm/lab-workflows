#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/node/generate-config.sh
# Merges Node.js-specific settings into the shared .releaserc.json base config.
# Adds npm plugin, sets package paths, and writes the final config.
#
# Usage:
#   ./generate-config.sh [PROJECT_PATH]
#
# Environment:
#   PUBLISH_TO_NPM      "true" | "false" (default: "true")
#   PUBLISH_TO_GITHUB   "true" | "false" (default: "false")
#   NPM_TOKEN           Required if PUBLISH_TO_NPM=true
#   GITHUB_TOKEN        Required if PUBLISH_TO_GITHUB=true
#
# Outputs (GITHUB_OUTPUT + /tmp/qa-generate-config-output.json):
#   config_path     Path to the generated .releaserc.json
#   output_file     Path to JSON output
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-generate-config-output.json"
SHARED_RELEASERC="${SCRIPT_DIR}/../../shared/semantic-release/.releaserc.json"
CONFIG_OUTPUT="${PROJECT_PATH}/.releaserc.generated.json"

PUBLISH_TO_NPM="${PUBLISH_TO_NPM:-true}"
PUBLISH_TO_GITHUB="${PUBLISH_TO_GITHUB:-false}"

cd "$PROJECT_PATH" || abort "Cannot cd to project path: $PROJECT_PATH"
log_step "Node.js — Generate Semantic Release Config"

require_cmd node
require_cmd python3

if [ ! -f "$SHARED_RELEASERC" ]; then
  abort "Base .releaserc.json not found at: $SHARED_RELEASERC"
fi

log_info "Base config: ${SHARED_RELEASERC}"

# ── Build plugins array ────────────────────────────────────────────────────────
PLUGINS_EXTRA="[]"

if [ "$PUBLISH_TO_NPM" = "true" ]; then
  [ -z "${NPM_TOKEN:-}" ] && log_warn "PUBLISH_TO_NPM=true but NPM_TOKEN is not set."
  PLUGINS_EXTRA=$(echo "$PLUGINS_EXTRA" | python3 -c "
import sys, json
plugins = json.load(sys.stdin)
plugins.append(['@semantic-release/npm', {'npmPublish': True}])
print(json.dumps(plugins))
")
fi

if [ "$PUBLISH_TO_GITHUB" = "true" ]; then
  [ -z "${GITHUB_TOKEN:-}" ] && log_warn "PUBLISH_TO_GITHUB=true but GITHUB_TOKEN is not set."
  PLUGINS_EXTRA=$(echo "$PLUGINS_EXTRA" | python3 -c "
import sys, json
plugins = json.load(sys.stdin)
plugins.append(['@semantic-release/npm', {'npmPublish': True, 'pkgRoot': '.', 'tarballDir': 'dist'}])
print(json.dumps(plugins))
")
fi

# ── Merge with base config ─────────────────────────────────────────────────────
python3 - <<PYEOF > "$CONFIG_OUTPUT"
import json

with open('${SHARED_RELEASERC}') as f:
    base = json.load(f)

extra_plugins = ${PLUGINS_EXTRA}
base.setdefault('plugins', [])

# Insert stack-specific plugins before the last plugin (usually git-tag)
insert_pos = max(len(base['plugins']) - 1, 0)
for plugin in reversed(extra_plugins):
    base['plugins'].insert(insert_pos, plugin)

print(json.dumps(base, indent=2))
PYEOF

log_success "Config generated: ${CONFIG_OUTPUT}"
cat "$CONFIG_OUTPUT"

# ── Output ────────────────────────────────────────────────────────────────────
JSON=$(cat <<EOF
{
  "config_path": "${CONFIG_OUTPUT}",
  "publish_to_npm": ${PUBLISH_TO_NPM},
  "publish_to_github": ${PUBLISH_TO_GITHUB}
}
EOF
)

json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "config_path"  "$CONFIG_OUTPUT"
gha_set_output "output_file"  "$OUTPUT_FILE"