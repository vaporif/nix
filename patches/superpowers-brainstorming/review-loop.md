**Spec review loop (multi-agent, software designs).** The builder check
finds questions for your human partner; this loop finds defects in the
document. It runs once the builder check's answers are folded in, and
the document is not handed over until it is clean. Without a subagent
tool, do each finder and validator pass yourself, re-reading the
document fresh each time.

For a small design (3 or fewer tasks in the dependency graph), run the
same loop with one finder and one validator per iteration (skip the
merge step) and cap it at 5 iterations. It still runs until clean, never
a single pass. Otherwise iterate finder → merge → validator → fix until
clean:

1. **Find:** dispatch 2 `spec-document-reviewer` subagents in parallel (template: `spec-document-reviewer-prompt.md` in this directory), named `spec-finder-<iteration>a` and `spec-finder-<iteration>b`. Each gets the spec file path and precise review context — never your session history. They independently produce issue lists.
2. **Merge:** deduplicate and consolidate the two lists into one set of distinct findings.
3. **Validate:** dispatch 2 validator subagents in parallel against the merged set, named `spec-validator-<iteration>a` and `spec-validator-<iteration>b`. Each confirms which findings are real critical/blocker issues and rejects false positives. Keep only findings at least one validator confirms.
4. **Fix:** apply fixes for the confirmed critical/blocker issues.
5. **Reap:** `TaskStop` each of this iteration's four agents — both finders and both validators — as soon as its report has been consumed. Dispatched agents do not exit on their own; each one sits resident holding its full context, so ten unreaped iterations leave 40 alive and the memory they hold is what pushes a small machine into swap. Never reap an agent whose report you have not read yet, and reap before dispatching the next iteration rather than at the end of the loop.
6. **Loop:** repeat from step 1. Stop when validators confirm 0 critical/blocker issues.
7. **Cap:** after 10 iterations, stop and surface to the user for direction.

Then hand it over for review, with the list of calls you made:

> "Spec written and saved to `<path>`. Please review it and let me know if you want to make any changes before we start writing out the implementation plan."

If they request changes, make them and re-run the review loop. Only
proceed once they approve.
