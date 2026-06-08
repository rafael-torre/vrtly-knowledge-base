# Step 2: Write to Final

**Input:** Validated source document, target final/ path

**Actions:**
- Derive final/ path: replace /intermediate/ with /final/ in source path
- Ensure final/ directory exists
- Copy document content; update frontmatter:
  - status: needs_review
  - last_updated: <today YYYY-MM-DD>
  - relates_to: populate with upstream layer final/ doc paths
- Write to final/ path

**Output:** Promoted document at final/ path
