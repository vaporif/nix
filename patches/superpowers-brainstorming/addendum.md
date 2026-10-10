
## Local Customizations

These rules apply on top of everything above. Where they conflict with
earlier text, these win.

### Executing the Plan

After writing-plans, execute with the strategy recorded in the plan header.
Do NOT ask the user again:

- **Subagents**: invoke subagent-driven-development. The executor reads the plan's `## Task Dependency Graph` and dispatches independent tasks in parallel batches, dependent tasks only after their predecessors pass review. Single-task plans run as a single dispatch. This is the default for most work.
- **Agent teams**: use `/team-feature` to spawn a coordinated team (persistent agents in tmux panes with shared task list and inter-agent messaging). The team-lead MUST enforce three-stage review gates after each implementer completes a task:
  1. **Spec compliance review**: team-reviewer reads actual code against task requirements — checks for missing requirements, extra/unneeded work, and misunderstandings. Does NOT trust the implementer's report. If issues found, implementer fixes and reviewer re-reviews until approved.
  2. **Code quality review** (only after spec compliance passes): team-reviewer checks file responsibilities, decomposition, codebase pattern adherence, and standard quality concerns. Critical/Important issues block; Minor issues are noted. Implementer fixes and re-reviews until approved.
  3. **Final holistic review**: after all tasks pass both stages, team-reviewer performs a cross-stream review checking consistency, integration seams, and cross-cutting concerns that per-task reviews might miss.

  Never skip reviews. Never start code quality review before spec compliance passes. Never mark a task complete with open review issues.
- After all tasks complete (in either strategy), the executing skill **always** invokes the `post-implementation-polish` skill. The agent type used inside polish is set by the plan's `Polish:` line (defaults to `general-purpose`). Polish is never inline-only, never skipped, never user-confirmed.

If the user later countermands the strategy ("use a team instead", "switch back to subagents"), update the spec and plan accordingly.

### Humanize All Non-Code Prose

Apply the `humanizer` skill to all non-code text: questions, playback, approach proposals, the design document, and plan prose. It does not apply to code blocks, file paths, commands, configuration snippets, or structured data (tables, checklists).

Strip AI-isms as you write rather than producing slop and cleaning it up. Watch for significance inflation ("pivotal", "crucial"), promotional language ("seamless"), "serves as" instead of "is", superficial -ing phrases, rule-of-three lists, "not just X, but Y", filler ("in order to"), sycophantic openers, generic positive conclusions, em dash overuse, excessive boldface, and inline-header vertical lists. Write like a person talking to another person.

### Document Pros and Cons for Every Decision

Every design decision, architecture choice, library selection, or approach recommendation includes explicit pros and cons:

- In conversation: follow "When a real choice comes up" above. Choices left to you get one line with the con you're accepting; choices that are theirs get the full comparison.
- In the design document: architecture decisions and library/tool selections get a "Pros / Cons / Why we chose this" block. If a decision has no meaningful cons, you probably haven't thought hard enough about it.
- In plans: task-level design choices get brief pros/cons, proportional to the choice.

Keep the format simple: Pros (what you gain), Cons (what you give up or risk), and optionally Why (the tiebreaker).

The point is not ceremony. It's making trade-offs visible so the user and future readers can see what was considered and why.

### Conventions Live Crate-Local

When the design relies on norms specific to a package, crate, or module (comment policy, error patterns, naming, layout), capture them in a crate-local `AGENTS.md` inside that package, not only in a parent doc. A norm the implementer reads next to the code it governs is followed; one referenced from three levels up is ignored. If a task introduces such a norm, plan the crate-local `AGENTS.md` as part of it.
