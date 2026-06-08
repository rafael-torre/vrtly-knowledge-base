---
name: skill-customize
description: 'Author and update customization overrides for installed DB90 skills. Use when the user says "customize a skill" or "override agent behavior".'
---

# Customize

## Purpose
Author and update customize.toml override files for DB90 skills and agents. Overrides are stored in .agents/config/custom/ and merged on top of skill defaults at activation time.

## Inputs
- Skill or agent name to customize
- User's desired overrides (persona, menu items, persistent_facts, principles)
- Existing .agents/config/custom/<skill-name>.toml if present

## Outputs
- .agents/config/custom/<skill-name>.toml (team override)
- .agents/config/custom/<skill-name>.user.toml (personal override, gitignored)

## Steps (TODO)
1. Identify which skill or agent to customize
2. Read current defaults from .agents/skills/<skill-name>/customize.toml
3. Read existing overrides from .agents/config/custom/<skill-name>.toml if present
4. Elicit desired changes from user
5. Write/update .agents/config/custom/<skill-name>.toml with team overrides
6. If personal-only changes: write/update .agents/config/custom/<skill-name>.user.toml instead
7. Confirm merge result by resolving combined config
