---
description: Generate PR title and description
---

Generate a pull request title and description.

**Steps:**

1. Run `git log main..HEAD --oneline` to see all commits in this branch
2. Run `git diff main...HEAD --stat` to see files changed
3. Run `git diff main...HEAD` to understand the actual changes
4. Check for PR template in `.github/PULL_REQUEST_TEMPLATE.md` or `.github/PULL_REQUEST_TEMPLATE/`

**Generate PR content:**

**Title:** Use conventional commit format: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- Scope is optional but recommended (e.g., `feat(auth): add login flow`)
- Description should be concise, lowercase, imperative mood, no period

**Description:**
```
## Summary
Brief explanation of what this PR does and why.

## Changes
- Bullet points of key changes
- Group related changes together

## Notes
Any additional context, breaking changes, or follow-up tasks.
```

**Style rules:**
- Be specific about what changed and why
- Mention any breaking changes prominently
- Link related issues if mentioned in commits
- Keep it scannable - reviewers are busy
- If repo has a PR template, follow that structure instead

**Present the title and description** for user to review/edit.

**After user confirms**, create the PR using `mcp__github__create_pull_request` with:
- owner/repo from `git remote get-url origin`
- head: current branch (`git branch --show-current`)
- base: main (or master if that's the default)
- title and body from above

Return the PR URL when done.
