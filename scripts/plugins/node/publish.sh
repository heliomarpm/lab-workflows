#!/usr/bin/env bash
# =============================================================================
# scripts/plugins/node/publish.sh
# Publishes a Node.js package to NPM and/or GitHub Packages.
#
# Usage:
#   ./publish.sh [PROJECT_PATH]
#
# Environment:
#   NPM_TOKEN           Token for NPM registry (required for NPM publish)
#   GITHUB_TOKEN        Token for GitHub Packages (required for GH Packages)
#   PUBLISH_TARGET      "npm" | "github" | "both" (default: "npm")
#   PACKAGE_VERSION     Version to publish (default: read from package.json)
#
# Outputs (GITHUB_OUTPUT + /tmp/qa-publish-output.json):
#   published           "true" | "false"
#   published_version   Version that was published
#   output_file         Path to JSON output
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/shell-helpers.sh"

PROJECT_PATH="${1:-.}"
OUTPUT_FILE="${QA_OUTPUT_DIR:-/tmp}/qa-publish-output.json"
PUBLISH_TARGET="${PUBLISH_TARGET:-npm}"

cd "$PROJECT_PATH" || abort "Cannot cd to project path: $PROJECT_PATH"
log_step "Node.js — Publish"
log_info "Working directory: $(pwd)"
log_info "Publish target: ${PUBLISH_TARGET}"

require_cmd node
require_cmd npm

if [ ! -f "package.json" ]; then
  abort "package.json not found in: $(pwd)"
fi

PACKAGE_VERSION="${PACKAGE_VERSION:-$(node -e "console.log(require('./package.json').version)")}"
PACKAGE_NAME=$(node -e "console.log(require('./package.json').name)")

log_info "Package: ${PACKAGE_NAME}@${PACKAGE_VERSION}"

if [ ! -d "node_modules" ]; then
  npm ci --prefer-offline 2>/dev/null || npm install
fi

PUBLISHED="false"
START=$(date +%s)

publish_to_npm() {
  [ -z "${NPM_TOKEN:-}" ] && abort "NPM_TOKEN is required for NPM publish."
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
  log_info "Publishing to NPM..."
  npm publish --access public
  log_success "Published to NPM: ${PACKAGE_NAME}@${PACKAGE_VERSION}"
}

publish_to_github() {
  [ -z "${GITHUB_TOKEN:-}" ] && abort "GITHUB_TOKEN is required for GitHub Packages publish."
  SCOPE=$(echo "$PACKAGE_NAME" | cut -d'/' -f1)
  REGISTRY="https://npm.pkg.github.com"
  echo "${SCOPE}:registry=${REGISTRY}" >> ~/.npmrc
  echo "//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}" >> ~/.npmrc
  log_info "Publishing to GitHub Packages..."
  npm publish --registry "$REGISTRY"
  log_success "Published to GitHub Packages: ${PACKAGE_NAME}@${PACKAGE_VERSION}"
}

case "$PUBLISH_TARGET" in
  npm)    publish_to_npm;    PUBLISHED="true" ;;
  github) publish_to_github; PUBLISHED="true" ;;
  both)   publish_to_npm; publish_to_github; PUBLISHED="true" ;;
  *)      abort "Unknown PUBLISH_TARGET: '${PUBLISH_TARGET}'. Expected: npm | github | both" ;;
esac

# ── Output ────────────────────────────────────────────────────────────────────
JSON=$(cat <<EOF
{
  "published": ${PUBLISHED},
  "published_version": "${PACKAGE_VERSION}",
  "package_name": "${PACKAGE_NAME}",
  "target": "${PUBLISH_TARGET}",
  "duration": "$(elapsed $START)"
}
EOF
)

json_write "$OUTPUT_FILE" "$JSON"
gha_set_output "published"          "$PUBLISHED"
gha_set_output "published_version"  "$PACKAGE_VERSION"
gha_set_output "output_file"        "$OUTPUT_FILE"