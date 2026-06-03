#!/bin/bash

# init.sh
# Wires the DB90 companion system into Cursor, Claude, or both.
# Copies companion files to the appropriate config directories,
# creates .companion.yaml from the example if absent,
# and adds gitignore entries. Safe to re-run after updates.
#
# Usage:
#   ./init.sh                    # Interactive — prompts for tool and installs in repo root
#   ./init.sh /path/to/target    # Install in another folder (prompts for tool)
#   ./init.sh --cursor           # Install Cursor setup only
#   ./init.sh --claude           # Install Claude setup only
#   ./init.sh --both             # Install both setups
#   ./init.sh /path/to/target --cursor|--claude|--both

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPANION_DIR="${SCRIPT_DIR}"

# ── Argument parsing ──────────────────────────────────────────────────────────

REPO_ROOT=""
TOOL_FLAG=""

for arg in "$@"; do
    case "$arg" in
        --cursor) TOOL_FLAG="cursor" ;;
        --claude) TOOL_FLAG="claude" ;;
        --both)   TOOL_FLAG="both"   ;;
        *)
            if [[ -z "$REPO_ROOT" && -d "$arg" ]]; then
                REPO_ROOT="$(cd "$arg" && pwd)"
            fi
            ;;
    esac
done

# Default repo root to parent of companion/
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

# ── Tool selection ────────────────────────────────────────────────────────────

if [[ -z "$TOOL_FLAG" ]]; then
    echo ""
    echo "Which AI tool do you want to configure?"
    echo "  1) Cursor"
    echo "  2) Claude"
    echo "  3) Both"
    echo ""
    read -r -p "Enter choice [1-3]: " tool_choice
    case "$tool_choice" in
        1) TOOL_FLAG="cursor" ;;
        2) TOOL_FLAG="claude" ;;
        3) TOOL_FLAG="both"   ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

INSTALL_CURSOR=false
INSTALL_CLAUDE=false

[[ "$TOOL_FLAG" == "cursor" || "$TOOL_FLAG" == "both" ]] && INSTALL_CURSOR=true
[[ "$TOOL_FLAG" == "claude" || "$TOOL_FLAG" == "both" ]] && INSTALL_CLAUDE=true

# ── Header ────────────────────────────────────────────────────────────────────

echo ""
echo "🔧 Initializing DB90 Companion System..."
echo "   Repo root : $REPO_ROOT"
echo "   Target    : $TOOL_FLAG"
echo ""

# ── Shared: layer-specific skill detection ────────────────────────────────────

HAS_DRAFT_FEATURE_SPEC=false
HAS_DRAFT_DESIGN_SPEC=false
HAS_DRAFT_TECHNICAL_SPEC=false

[[ -d "$REPO_ROOT/layers/layer-1-product/tools/draft-feature-spec"    ]] && HAS_DRAFT_FEATURE_SPEC=true
[[ -d "$REPO_ROOT/layers/layer-2-design/tools/draft-design-spec"      ]] && HAS_DRAFT_DESIGN_SPEC=true
[[ -d "$REPO_ROOT/layers/layer-3-architecture/tools/draft-technical-spec" ]] && HAS_DRAFT_TECHNICAL_SPEC=true

# ── Install: Cursor ───────────────────────────────────────────────────────────

install_cursor() {
    local CURSOR_DIR="${REPO_ROOT}/.cursor"
    mkdir -p "$CURSOR_DIR"

    echo "📋 [Cursor] Installing rules..."
    mkdir -p "$CURSOR_DIR/rules"
    cp "$COMPANION_DIR/rules/db90-companion.mdc" "$CURSOR_DIR/rules/db90-companion.mdc"
    echo "   ✓ db90-companion.mdc"

    echo "🪝 [Cursor] Installing hooks..."
    mkdir -p "$CURSOR_DIR/hooks"
    cp "$COMPANION_DIR/hooks/scan-project-state.sh" "$CURSOR_DIR/hooks/scan-project-state.sh"
    chmod +x "$CURSOR_DIR/hooks/scan-project-state.sh"
    echo "   ✓ scan-project-state.sh"

    cp "$COMPANION_DIR/hooks/update-metadata.sh" "$CURSOR_DIR/hooks/update-metadata.sh"
    chmod +x "$CURSOR_DIR/hooks/update-metadata.sh"
    echo "   ✓ update-metadata.sh"

    echo "⚙️  [Cursor] Installing hooks.json..."
    cp "$COMPANION_DIR/hooks.json" "$CURSOR_DIR/hooks.json"
    echo "   ✓ hooks.json"

    echo "🎯 [Cursor] Installing companion skills..."
    mkdir -p "$CURSOR_DIR/skills"
    cp -r "$COMPANION_DIR/skills/scan-project-state" "$CURSOR_DIR/skills/scan-project-state"
    echo "   ✓ scan-project-state"
    cp -r "$COMPANION_DIR/skills/session-handoff" "$CURSOR_DIR/skills/session-handoff"
    echo "   ✓ session-handoff"

    echo "🏗️  [Cursor] Installing layer-specific skills..."
    if $HAS_DRAFT_FEATURE_SPEC; then
        cp -r "$REPO_ROOT/layers/layer-1-product/tools/draft-feature-spec" "$CURSOR_DIR/skills/draft-feature-spec"
        echo "   ✓ draft-feature-spec (Layer 1)"
    fi
    if $HAS_DRAFT_DESIGN_SPEC; then
        cp -r "$REPO_ROOT/layers/layer-2-design/tools/draft-design-spec" "$CURSOR_DIR/skills/draft-design-spec"
        echo "   ✓ draft-design-spec (Layer 2)"
    fi
    if $HAS_DRAFT_TECHNICAL_SPEC; then
        cp -r "$REPO_ROOT/layers/layer-3-architecture/tools/draft-technical-spec" "$CURSOR_DIR/skills/draft-technical-spec"
        echo "   ✓ draft-technical-spec (Layer 3)"
    fi

    echo ""
    echo "   ✅ Cursor setup complete."
    echo "   → Restart Cursor to activate the companion rule."
    echo "   → The session-start hook will run on next session, generating .cursor/session-state.md"
}

# ── Install: Claude ───────────────────────────────────────────────────────────

install_claude() {
    local CLAUDE_DIR="${REPO_ROOT}/.claude"
    local CLAUDE_GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
    mkdir -p "$CLAUDE_DIR"

    # CLAUDE.md lives at the repo root — Claude auto-loads it from there on every session
    echo "📋 [Claude] Installing CLAUDE.md..."
    cp "$COMPANION_DIR/claude/CLAUDE.md" "$REPO_ROOT/CLAUDE.md"
    echo "   ✓ CLAUDE.md → ${REPO_ROOT}/CLAUDE.md"

    echo "📋 [Claude] Installing rules..."
    mkdir -p "$CLAUDE_DIR/rules"
    cp "$COMPANION_DIR/claude/rules/db90-companion.md" "$CLAUDE_DIR/rules/db90-companion.md"
    echo "   ✓ db90-companion.md"

    echo "🪝 [Claude] Installing hooks..."
    mkdir -p "$CLAUDE_DIR/hooks"
    cp "$COMPANION_DIR/hooks/scan-project-state.sh" "$CLAUDE_DIR/hooks/scan-project-state.sh"
    chmod +x "$CLAUDE_DIR/hooks/scan-project-state.sh"
    echo "   ✓ scan-project-state.sh"

    cp "$COMPANION_DIR/claude/hooks/update-metadata.sh" "$CLAUDE_DIR/hooks/update-metadata.sh"
    chmod +x "$CLAUDE_DIR/hooks/update-metadata.sh"
    echo "   ✓ update-metadata.sh"

    echo "⚙️  [Claude] Installing settings.json..."
    cp "$COMPANION_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
    echo "   ✓ settings.json"

    echo "🎯 [Claude] Installing companion skills to ~/.claude/skills/..."
    mkdir -p "$CLAUDE_GLOBAL_SKILLS_DIR"

    local SCAN_DEST="$CLAUDE_GLOBAL_SKILLS_DIR/scan-project-state"
    mkdir -p "$SCAN_DEST"
    cp "$COMPANION_DIR/claude/skills/scan-project-state/SKILL.md" "$SCAN_DEST/SKILL.md"
    echo "   ✓ scan-project-state → $SCAN_DEST"

    local HANDOFF_DEST="$CLAUDE_GLOBAL_SKILLS_DIR/session-handoff"
    mkdir -p "$HANDOFF_DEST"
    cp "$COMPANION_DIR/claude/skills/session-handoff/SKILL.md" "$HANDOFF_DEST/SKILL.md"
    echo "   ✓ session-handoff → $HANDOFF_DEST"

    echo "🏗️  [Claude] Installing layer-specific skills to ~/.claude/skills/..."
    if $HAS_DRAFT_FEATURE_SPEC; then
        local DEST="$CLAUDE_GLOBAL_SKILLS_DIR/draft-feature-spec"
        mkdir -p "$DEST"
        cp -r "$REPO_ROOT/layers/layer-1-product/tools/draft-feature-spec/." "$DEST/"
        echo "   ✓ draft-feature-spec (Layer 1) → $DEST"
    fi
    if $HAS_DRAFT_DESIGN_SPEC; then
        local DEST="$CLAUDE_GLOBAL_SKILLS_DIR/draft-design-spec"
        mkdir -p "$DEST"
        cp -r "$REPO_ROOT/layers/layer-2-design/tools/draft-design-spec/." "$DEST/"
        echo "   ✓ draft-design-spec (Layer 2) → $DEST"
    fi
    if $HAS_DRAFT_TECHNICAL_SPEC; then
        local DEST="$CLAUDE_GLOBAL_SKILLS_DIR/draft-technical-spec"
        mkdir -p "$DEST"
        cp -r "$REPO_ROOT/layers/layer-3-architecture/tools/draft-technical-spec/." "$DEST/"
        echo "   ✓ draft-technical-spec (Layer 3) → $DEST"
    fi

    echo ""
    echo "   ✅ Claude setup complete."
    echo "   → CLAUDE.md placed at ${REPO_ROOT}/CLAUDE.md (auto-loaded by Claude on every session)"
    echo "   → Rules installed at ${CLAUDE_DIR}/rules/"
    echo "   → Hooks installed at ${CLAUDE_DIR}/hooks/ and wired via ${CLAUDE_DIR}/settings.json"
    echo "   → Skills installed globally at ~/.claude/skills/"
}

# ── Run installs ──────────────────────────────────────────────────────────────

$INSTALL_CURSOR && install_cursor && echo ""
$INSTALL_CLAUDE && install_claude && echo ""

# ── .companion.yaml ───────────────────────────────────────────────────────────

echo "🔐 Configuring companion..."
if [[ ! -f "$REPO_ROOT/.companion.yaml" ]]; then
    cp "$COMPANION_DIR/.companion.yaml.example" "$REPO_ROOT/.companion.yaml"
    echo "   ✓ Created .companion.yaml (edit with your name and role)"
else
    echo "   ℹ️  .companion.yaml already exists (skipping)"
fi

# ── .gitignore ────────────────────────────────────────────────────────────────

echo ""
echo "📝 Updating .gitignore..."
GITIGNORE_FILE="${REPO_ROOT}/.gitignore"

ENTRIES_TO_ADD=(
    ".companion.yaml"
    ".cursor/session-state.md"
    ".cursor/session-handoff.md"
    ".claude/session-state.md"
    ".claude/session-handoff.md"
)

for entry in "${ENTRIES_TO_ADD[@]}"; do
    if ! grep -q "^${entry}$" "$GITIGNORE_FILE" 2>/dev/null; then
        echo "$entry" >> "$GITIGNORE_FILE"
        echo "   ✓ Added $entry"
    else
        echo "   ℹ️  $entry already in .gitignore"
    fi
done

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "✅ DB90 Companion System initialized!"
echo ""
echo "Next steps:"
echo "1. Edit .companion.yaml with your name and role"
if $INSTALL_CURSOR; then
echo "2. [Cursor] Restart Cursor to activate the companion rule"
fi
if $INSTALL_CLAUDE; then
echo "2. [Claude] Start a new Claude Code session — CLAUDE.md and .claude/rules/ are auto-loaded"
echo "   → The SessionStart hook will run scan-project-state.sh automatically"
echo "   → PostToolUse hook will update metadata after each edit to a final/ doc"
fi
echo ""
echo "For help, see: companion/README.md"
