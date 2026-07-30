---
name: spec-review
description: >
  Pre-implementation quality gate for a spec/plan. Reviews the newest doc in
  docs/specs or docs/plans for bugs, gaps, inconsistencies, and false assumptions
  about the codebase, then auto-fixes the doc and shows the diff. Use before
  implementation, or on "review the spec/plan", "audit the plan", /spec-review.
---

Review a spec/plan **before** implementation. The doc is under review; the code is the
reference you validate it against — raise the doc's quality, don't sync it to code.
Finding and validation go to subagents. You own: locate, merge, edit, stop.

## 1. Locate

```bash
find docs/specs docs/plans -type f -name '*.md' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null
```

First line is the target (or an explicit path if given). Print path + mtime. Stop if
there's nothing to review.

## 2. Round loop

Announce `Round N/3`. Repeat until step 3 says stop.

**a. Find** — two `general-purpose` subagents, one message, each given only the doc
path so every round is a fresh look.

- **A — doc quality:** logic errors, contradictions, gaps (missing steps, edge cases,
  success criteria), ambiguity, unjustified scope.
- **B — codebase validation:** verify every claim about the code with Grep/Read. Bad
  file/API references, false assumptions, pattern conflicts, duplication, feasibility
  — with `file:line` evidence.

Findings return `tag` (internal | code-mismatch), `severity`, `claim` (quote + line),
`problem`, `evidence`, `fix`.

| Severity | Meaning |
|---|---|
| critical | Implementing as written produces the wrong thing or fails outright |
| major | Real gap or false assumption; implementer stalls or guesses wrong |
| minor | Wording, polish, nice-to-have detail |

**b. Merge** — dedupe by (doc line, problem), keep the higher severity, drop anything
already parked. Then split each finding by trying to write a `-` con line for its fix:

- No con → **autofix**. Nothing is being decided, so fix it, however weighty it looks.
- Real con → **human-call**. Park it: don't fix, doesn't block, goes in the report.

A con is a concrete cost — invalidates sessions, touches 4 call sites, rules out an
approach the author may want. "Might not be what they meant" is not a con.

**c. Validate** — one `general-purpose` verifier per finding, all in one message:

```
Finding: <block>   Doc: <path>
Try to refute this. Read the doc and referenced code yourself.
Default to refuted=true when evidence is thin or you can't reproduce it.
Return: refuted, corrected_severity, reason, better_fix.
```

Drop refuted findings, apply `corrected_severity`. A finding you couldn't dispatch a
verifier for gets dropped, not kept on your own judgment.

**d. Fix** — edit the doc for every autofix survivor, blocking and minor alike. Keep
the author's intent and structure. Doc only — no source edits, no commits.

**e. Print** — one line per fix, issue in **two sentences max**, no surrounding prose:

```
Round 1 — fixed 2, parked 1, refuted 2

✓ §Migration, L44 (critical, code-mismatch)
  Doc calls `store.migrate(schema)`, which doesn't exist. Real entry point is
  `Store::run_migrations(&mut self)` at store/migrate.rs:88.
✓ §Rollout, L91 (major, internal)
  No success criteria for the canary stage, so nothing says whether to proceed.
  Added the error-rate threshold §Metrics already assumes.
⏸ §Auth, L12 (major) — parked, see report
```

## 3. Exit

**Blocking** = surviving critical or major **autofix** findings. Parked human-calls
never block.

- Zero blocking in a round → done, even if minor ones were fixed.
- Round 3 is the cap. Blockers still open → report them, don't start round 4.
- Reappears after being fixed twice → mark unresolved and surface it now.

## 4. Report

`git diff` of the doc, unresolved blockers with why each is open, then the parked
human-calls — the point of the whole run:

```
§Auth, L12 (major) — Spec assumes stateless sessions, but auth/session.rs:31 stores
them in Redis.

  A. Keep Redis, drop the stateless claim
     + No code change, ships as-is
     - Horizontal scaling still needs sticky sessions
  B. Move to signed tokens, rewrite §Auth
     + Matches the spec's intent
     - Touches 4 call sites, invalidates existing sessions

→ Recommend A: the stateless claim is incidental here, and B is its own piece of work.
```

Every parked finding gets options, pros, cons, and one `→` recommendation. A
recommendation without a stated reason isn't one.

## Red flags

- Skipping the verifier because a finding "is obviously right" — unverified findings
  are how a review corrupts a good doc.
- Finding it yourself instead of dispatching. Your context is polluted by the fixes you
  just made.
- Editing source files.
- Looping past round 3. Unresolved blockers are a valid outcome.
- Auto-fixing a human-call to reach a clean round. Deciding something the author didn't
  is worse than leaving the doc wrong.
