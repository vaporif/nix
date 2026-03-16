---
description: Save session context before context clear — updates active docs in-place, writes minimal resume pointer
---

Persist session state so the next context can resume with zero research.

**Principle:** Don't duplicate — update source docs in-place, then write a thin checkpoint that points to them. If no docs exist, create one structured doc that serves as both plan and checkpoint.

**Output file:** `docs/checkpoints/YYYY-MM-DD-<topic-slug>.md`

**Steps:**

1. **Check for active documents.** Look for plans/specs/docs touched this session:
   - Plans: `docs/superpowers/plans/*.md`
   - Specs: `docs/superpowers/specs/*.md`
   - Any other working docs read or written this session

2. **If active docs exist** — update them in-place:
   - Mark completed checkboxes: `- [ ]` → `- [x]`
   - Annotate in-progress steps inline: `- [ ] Step 3 — 🔄 auth logic done, tests remain`
   - Then write a **thin pointer checkpoint:**

```markdown
# Checkpoint: <title>

## Goal
<1-2 sentences>

## Read These First
- `<path to spec>` — design spec
- `<path to plan>` — implementation plan (checkboxes updated)
- <any other active docs>

## Session Notes
<ONLY things not in the docs above:>
- Gotchas discovered (file:line refs)
- Verbal decisions not in spec/plan
- Error messages or surprising behavior
- Blockers or open questions

## Next Steps
<"Continue from Chunk X, Task Y, Step Z in the plan.">
<Commands to verify current state before resuming.>
```

3. **If NO active docs exist** — create a **standalone checkpoint** with enough structure to resume without research:

```markdown
# Checkpoint: <title>

## Goal
<1-2 sentences: what the user wants>

## Approach
<Chosen approach and why. Rejected alternatives if relevant.>

## Progress
Tasks with checkbox tracking — same format as superpowers plans:

### Chunk 1: <name>
- [x] Completed step (key details inline)
- [ ] In-progress step — 🔄 what's done, what remains
- [ ] Not started step

### Chunk 2: <name>
- [ ] ...

## Key Context
- File paths and their roles (file:line refs)
- Patterns or conventions identified
- Gotchas, error messages, surprising behavior
- Dependencies or constraints discovered

## Next Steps
<Exactly what to do first. Be specific.>
<Commands to verify current state before resuming.>
```

4. **Tell the user:**
   - Which docs were updated (if any)
   - The checkpoint file path
   - A resume one-liner:
     `Read docs/checkpoints/YYYY-MM-DD-<slug>.md and resume the work.`
