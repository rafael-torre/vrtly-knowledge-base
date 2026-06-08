#!/bin/bash

# update-metadata.sh
# Fires on afterFileEdit, scoped to layers/**/final/**/*.md
# Auto-updates last_updated to today's date and cascades needs_review to downstream docs.

set -euo pipefail

EDITED_FILE="$1"
REPO_ROOT="${2:-.}"
TODAY=$(date +%Y-%m-%d)

# Only operate on final/ docs
if [[ ! "$EDITED_FILE" =~ /final/ ]]; then
    exit 0
fi

# Update last_updated field
if grep -q "^last_updated:" "$EDITED_FILE"; then
    # Use sed to update existing last_updated
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^last_updated: .*/last_updated: $TODAY/" "$EDITED_FILE"
    else
        sed -i "s/^last_updated: .*/last_updated: $TODAY/" "$EDITED_FILE"
    fi
else
    # Add last_updated after title field
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "/^title:/a\\
last_updated: $TODAY" "$EDITED_FILE"
    else
        sed -i "/^title:/a last_updated: $TODAY" "$EDITED_FILE"
    fi
fi

# Extract relates_to field and cascade needs_review to downstream docs
if grep -q "^relates_to:" "$EDITED_FILE"; then
    relates_to=$(grep "^relates_to:" "$EDITED_FILE" | head -1 | cut -d: -f2- | xargs)

    # Parse relates_to (space or comma-separated paths)
    for related_path in $relates_to; do
        # Resolve path relative to repo root
        if [[ ! "$related_path" =~ ^/ ]]; then
            related_path="${REPO_ROOT}/${related_path}"
        fi

        # Update the related doc's status if it exists
        if [[ -f "$related_path" ]]; then
            if grep -q "^status:" "$related_path"; then
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' 's/^status: .*/status: needs_review/' "$related_path"
                else
                    sed -i 's/^status: .*/status: needs_review/' "$related_path"
                fi
            else
                # Add status field if missing
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' "/^title:/a\\
status: needs_review" "$related_path"
                else
                    sed -i "/^title:/a status: needs_review" "$related_path"
                fi
            fi
        fi
    done
fi

exit 0
