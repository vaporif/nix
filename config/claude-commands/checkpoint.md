---
description: Save full session context to a checkpoint document before context clear, so the next session can resume with zero research
---

Create a checkpoint document that captures everything the next session needs to resume work seamlessly.

**Output file:** `docs/checkpoints/YYYY-MM-DD-<topic-slug>.md` (use today's date and a descriptive slug)

**Steps:**

1. **Find active session documents.** Check for any plans, specs, or working docs used this session:
   - Plans: `docs/superpowers/plans/*.md`
   - Specs: `docs/superpowers/specs/*.md`
   - Any other doc files read or written during this session
   - For each active doc, update its checkboxes (`- [ ]` → `- [x]`) to reflect actual progress made

2. Gather all context from this session:

**Session State:**
- What was the user's original request/goal?
- What approach was chosen and why?
- What alternatives were considered and rejected?

**Progress:**
- What tasks are DONE? (mark clearly as ✅)
- What is IN PROGRESS? (mark as 🔄, include exact state — what's left)
- What is NOT STARTED? (mark as ⬜)

**Key Discoveries:**
- Important findings from codebase exploration (file paths, patterns, gotchas)
- Any surprising behavior or bugs encountered
- Decisions made and their rationale

**Technical Context:**
- Relevant file paths and their roles
- Code patterns or conventions that were identified
- Dependencies or constraints discovered
- Any commands that were run and their relevant output

**Blockers & Open Questions:**
- Anything unresolved that needs attention
- Questions that still need answers

3. Write the checkpoint document with this structure:

```markdown
# Checkpoint: <descriptive title>

## Goal
<One paragraph: what the user wants to achieve>

## Approach
<Chosen approach and why. Mention rejected alternatives if relevant>

## Active Documents
List every plan, spec, or working doc from this session. For each:
- **Path:** `docs/superpowers/plans/YYYY-MM-DD-<name>.md`
- **Status:** completed / in-progress / not-started
- **Notes:** what was done, what remains

The next session MUST read these documents — they contain the full
task breakdown, design decisions, and progress state.

## Progress

### ✅ Done
- <completed item with key details>

### 🔄 In Progress
- <item and exact current state — what's done within it, what remains>

### ⬜ Not Started
- <planned item>

## Key Context
<File paths, patterns, decisions, gotchas — everything the next session
needs to avoid re-researching. Be specific: include line numbers, option
names, exact error messages, etc.>

## Resume Instructions
<Exact steps for the next session to pick up where this one left off.
Write as if talking to a fresh Claude with no memory of this session.
Start with: "Read these files first: <list active documents>".
Then: what to verify, and what to do next.>
```

4. After writing the checkpoint, tell the user:
   - The checkpoint file path
   - A one-liner they can paste into the next session to resume, e.g.:
     `Read docs/checkpoints/YYYY-MM-DD-<slug>.md and resume from where the previous session left off.`
