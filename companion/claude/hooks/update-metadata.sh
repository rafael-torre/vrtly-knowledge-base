#!/bin/bash

# update-metadata.sh (Claude wrapper)
# Fires on PostToolUse (Edit|Write), scoped to layers/**/final/**/*.md.
# Claude delivers the tool input as JSON on stdin; this wrapper extracts
# the file path and delegates to the shared update-metadata.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CLAUDE_PROJECT_DIR:-.}"

# Read JSON from stdin and extract file_path (Edit tool) or path (Write tool)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Resolve to absolute path if relative
if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="${REPO_ROOT}/${FILE_PATH}"
fi

exec "${REPO_ROOT}/companion/hooks/update-metadata.sh" "$FILE_PATH" "$REPO_ROOT"
