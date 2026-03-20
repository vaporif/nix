---
description: Save session context to Qdrant memory before context clear
---

Persist session state to Qdrant so the next context can resume with zero research.

**Steps:**

1. **Summarize session state.** Collect:
   - `goal`: one-line session/task goal
   - Approach taken and key decisions
   - Progress (with checkboxes: `- [x]` done, `- [ ]` remaining)
   - Gotchas discovered (file:line refs)
   - Next steps (exactly what to do first when resuming)

2. **Get context.** Run these commands to populate metadata:
   - `pwd` for `project_path`
   - `git branch --show-current` for `branch`
   - `date -u +%s` for `date` (epoch float)
   - `date -u +%Y-%m-%dT%H:%M:%SZ` for `date_display` (RFC 3339)
   - Identify affected `files` (relative paths from project root)

3. **Check for duplicates.** Search Qdrant with `qdrant-find`:
   - Query: the goal summary text
   - Filter: `{"must": [{"key": "project_path", "match": {"value": "<project_path>"}}, {"key": "branch", "match": {"value": "<branch>"}}, {"key": "type", "match": {"value": "checkpoint"}}, {"key": "date", "range": {"gte": <epoch minus 86400>}}]}`
   - If similar entries found, present them and ask whether to store a new checkpoint or skip

4. **Store in Qdrant.** Use `qdrant-store` with:
   - **Content**: Full structured summary (goal, approach, progress checkboxes, decisions, gotchas, next steps)
   - **Metadata**:
     ```json
     {
       "type": "checkpoint",
       "date": <epoch_float>,
       "date_display": "<RFC 3339>",
       "summary": "<one-line description>",
       "project_path": "<absolute path>",
       "files": ["<relative paths>"],
       "goal": "<one-line goal>",
       "outcome": "<success|partial|blocked>",
       "branch": "<git branch>",
       "related_to": ["<point IDs from dedup search if related>"]
     }
     ```

5. **Parse the point ID** from the `qdrant-store` response (format: `"stored (id=<point_id>) in collection '...'"`)

6. **Tell the user:**
   - What was stored (summary)
   - The point ID
   - Resume one-liner: `Recall checkpoint: "<summary>"`
