---
description: Audit ferrex memory health
argument-hint: [namespace:name|all]
---

Run a memory health audit using `mcp__ferrex__reflect`.

**Auto-set namespace** from project directory name, unless `namespace:all` or `namespace:<name>` specified.

**Call** `mcp__ferrex__reflect` with:
- `namespace`: detected or specified
- `include_contradictions`: true
- `include_stale`: true
- `limit`: 20

**Display results:**

For stale memories:
- Content summary, age, staleness score
- Suggest: `/forget <id>` to remove, or `/remember` updated version to supersede

For contradictions:
- Show both conflicting triples side by side
- Suggest: `/remember` the correct fact with `supersedes` pointing to the old memory ID

**After showing results:** Offer to batch-forget stale entries or help resolve contradictions.
