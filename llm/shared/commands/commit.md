---
description: Generate commit message from staged changes
---

Generate a commit message for staged changes.

**Steps:**

1. Run `git diff --cached` to see staged changes
2. Run `git log --oneline -10` to understand commit style in this repo

**Generate commit message:**
- Single line only: type(scope): summary (max 50 chars)
- Types: feat, fix, refactor, docs, test, chore, perf
- Must be readable at a glance in GitHub commit list
- No body unless user specifically asks for it

**Style rules:**
- Use imperative mood ("add feature" not "added feature")
- No period at end
- Keep it short - prefer brevity over detail

**Present the message** and ask user to confirm or edit before committing.

If user confirms, run `git commit -m "<message>"`.
