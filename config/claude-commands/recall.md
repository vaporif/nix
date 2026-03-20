---
description: Search Qdrant memory
argument-hint: query [project:path|all] [type:checkpoint|note|decision|error-resolution|architecture|session-summary] [file:path] [branch:name] [date:today|7d|30d|start..end|all]
---

Search Qdrant memory using `mcp__qdrant__qdrant-find` with semantic search + metadata filters.

**Parse filters from arguments.** Extract these from $ARGUMENTS (remaining text becomes the semantic query):
- `project:<path>|all` — filter by project path. Default: current `pwd` (auto-injected)
- `type:<type>` — filter by entry type
- `file:<path>` — filter by affected file (uses `any` match for array fields)
- `branch:<name>` — filter by git branch
- `date:today|7d|30d|<start>..<end>|all` — date range filter. Default: last 30 days (auto-injected)

**Auto-injected defaults** (applied unless explicitly overridden):
- `project_path` = current `pwd`
- `date` = last 30 days (`date -u +%s` minus 2592000 to now)

Use `project:all` or `date:all` to disable these defaults.

**Build query_filter.** Combine parsed filters into Qdrant filter format:

Project filter:
```json
{"key": "project_path", "match": {"value": "/path/to/project"}}
```

Type filter:
```json
{"key": "type", "match": {"value": "checkpoint"}}
```

File filter (array — must use `any` form):
```json
{"key": "files", "match": {"any": ["home/common/mcp.nix"]}}
```

Branch filter:
```json
{"key": "branch", "match": {"value": "main"}}
```

Date range filter (epoch floats):
```json
{"key": "date", "range": {"gte": 1742428800.0, "lte": 1742515200.0}}
```

Date shortcuts:
- `today` — midnight UTC today to now
- `7d` — 7 days ago to now
- `30d` — 30 days ago to now
- `<start>..<end>` — Unix epoch range

Wrap all conditions in `{"must": [...]}`.

**Execute search.** Call `qdrant-find` with:
- `query`: semantic search text (the non-filter part of arguments, or "recent entries" if no query text)
- `query_filter`: the built filter object

**Display results.** For each result show:
- `summary` | `date_display` | `type` | `project_path`
- Offer to show full content of specific entries

**Fallback.** If filtered search returns no results, retry with semantic-only search (no `query_filter`). This handles pre-migration entries that used `project` instead of `project_path`.

**No arguments.** Search recent entries for current project:
- Query: "recent session context and decisions"
- Filter: `project_path` = current pwd, `date` = last 30 days

**Related entries.** If results contain `related_to` point IDs, offer to search for related entries using their summary as query text (point-by-ID lookup not yet available).

**After showing results**: Suggest related searches based on what was found.
