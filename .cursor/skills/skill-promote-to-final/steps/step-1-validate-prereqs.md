# Step 1: Validate Prerequisites

**Input:** Source intermediate/ document path from user

**Actions:**
- Read source document frontmatter
- Identify layer from path (layers/layer-N-*/intermediate/...)
- Load Layer N-1 final/ documents via relates_to or layer path
- Check: at least one Layer N-1 final/ doc has status: consensus
- Check: source doc has been reviewed (look for review-findings.md alongside, or ask user)

**Halt if:**
- Layer N-1 has no consensus docs → block with message: "Upstream layer N-1 must reach consensus before promoting Layer N documents"
- Source document has open blockers in review findings
