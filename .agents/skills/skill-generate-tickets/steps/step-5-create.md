# Step 5: Create Tickets

**Actions:**
- Read board.type from .companion.yaml
- TODO: implement connector per board type:
  - linear: use Linear MCP tool
  - github: use gh CLI
  - jira: use Jira REST API
  - other: prompt user for manual creation instructions
- For each ticket: create on board, capture returned ticket ID and URL
