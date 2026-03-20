---
description: Store in Qdrant (no args = session summary, with args = store that info)
argument-hint: Optional info to store
---

Store information in Qdrant memory using `mcp__qdrant__qdrant-store`.

**Before storing**: Search Qdrant with `qdrant-find` to check if similar information already exists. If found, skip or update instead of duplicating.

**Get context** for metadata:
- `pwd` for `project_path`
- `git branch --show-current` for `branch`
- `date -u +%s` for `date` (epoch float)
- `date -u +%Y-%m-%dT%H:%M:%SZ` for `date_display` (RFC 3339)
- Identify affected `files` (relative paths) if applicable

**If arguments provided**: Store "$ARGUMENTS" with metadata:
```json
{
  "type": "<note|decision|error-resolution|architecture>",
  "date": <epoch_float>,
  "date_display": "<RFC 3339>",
  "summary": "<one-line description for recall results>",
  "project_path": "<absolute path to project root>",
  "files": ["<relative paths if applicable>"],
  "branch": "<current git branch>",
  "related_to": ["<qdrant point IDs if related entries found during dedup search>"]
}
```

Choose type based on content:
- `note` — general information
- `decision` — key decisions made and why
- `error-resolution` — problems solved and solutions
- `architecture` — design patterns, structure choices

**If no arguments**: Summarize this entire conversation and store with metadata:
```json
{
  "type": "session-summary",
  "date": <epoch_float>,
  "date_display": "<RFC 3339>",
  "summary": "<one-line description>",
  "project_path": "<absolute path to project root>",
  "files": ["<relative paths of modified files>"],
  "goal": "<what was attempted>",
  "outcome": "<success|partial|blocked>",
  "branch": "<current git branch>",
  "related_to": ["<qdrant point IDs if related entries found>"]
}
```

Include: goals, problems solved, solutions, key files modified, commands used.

**After storing**: Parse the point ID from the response (format: `"stored (id=<point_id>) in collection '...'"`) and confirm what was stored — type, summary, and point ID.
