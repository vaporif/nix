---
name: spec-review
description: >
  Pre-implementation quality gate for a spec/plan. Reviews the newest doc in
  docs/specs or docs/plans for bugs, gaps, inconsistencies, and false assumptions
  about the codebase, then auto-fixes the doc and shows the diff. Use before
  implementation, or on "review the spec/plan", "audit the plan", /spec-review.
---

Review a spec/plan **before** implementation. The doc is under review; the code is
the reference you validate it against — you raise the doc's quality, you don't sync
it to code.

## 1. Locate

```bash
find docs/specs docs/plans -type f -name '*.md' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null
```

First line is the target (or an explicit path if the user gave one). Print the path
+ mtime. Stop if there's nothing to review.

## 2. Two finders (parallel, one message)

Give each only the doc path.

- **A — doc quality:** logic errors, contradictions, gaps (missing steps, edge
  cases, success criteria), ambiguity, unjustified scope.
- **B — codebase validation:** verify every claim about the code with Grep/Read.
  Report bad file/API references, false assumptions, pattern conflicts,
  duplication, feasibility problems — with `file:line` evidence.

## 3. Merge

Dedupe into one set. Tag `internal` | `code-mismatch`, assign severity. Drop
anything you can't substantiate.

## 4. Auto-fix

Edit the doc to resolve confirmed findings; correct false assumptions to match the
real code. Keep the author's intent and structure. Doc only — no source, no commit.

## 5. Report

`git diff` of the doc + a one-line summary by tag/severity, and any findings left
for the user to decide.
