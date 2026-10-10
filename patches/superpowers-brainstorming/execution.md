**Before writing a software design**, settle execution so the doc can
record it:

1. **Name the units.** Split the system into small units, each with one
   clear purpose, an interface others use without reading its internals,
   and tests of its own. For each, answer: what does it do, how is it
   used, what does it depend on? If you can't change a unit's internals
   without breaking its users, the boundary needs work. A file that keeps
   growing is usually doing too much. In an existing codebase, units
   follow the structure that is already there. Record them as a table:

   ```
   unit         | purpose (1 line)        | interface             | depends on | files
   auth-session | issue and check tokens  | issue(), verify()     | config     | src/auth/session.rs
   rate-limit   | per-user request quota  | check(user) -> Result | auth-session | src/limit.rs
   ```

   Under the table, give each unit two lines: how it fails and what proves
   it works. Failure behaviour is a design decision your human partner
   approves; left out, each implementer guesses and the guesses disagree.

   ```
   auth-session
     fails when: token expired → 401; store down → 503, no retry
     proven by:  expired-token test; store-down test; happy path
   ```

   Stay inside the work. Follow the patterns the codebase already uses,
   and don't propose refactoring that this work doesn't need. When
   existing code gets in the way of this work (a file that has grown too
   large, a tangled boundary), fix only what blocks it, and name each fix
   under the table so your human partner approves it with the design
   rather than finding it in the diff:

   ```
   Prep refactors (needed for this work):
   - split src/big.rs → src/big/{parse,emit}.rs — blocks auth-session
   ```

   Anything else you notice goes in the design document as a follow-up,
   not into this work.

2. **Select execution strategy and build the dependency graph.** Default
   to **Subagents**. Switch to **Agent teams** only if the user explicitly
   requested a coordinated team in this conversation. Inline-controller
   execution is reserved for the degraded path (no subagent support) and
   is not picked here. Do NOT ask the user to confirm. Announce it plainly:

   > "Selected execution strategy: **<Subagents | Agent teams>**. <N> tasks parallelisable, <M> sequential. Reason: <one line, e.g. 'Tasks 2 and 3 share files with Task 1; rest are independent'>."

   - **Subagents** (default): every task is implemented by a fresh dispatched agent. The executor batches independent tasks into parallel dispatches and chains dependent tasks sequentially.
   - **Agent teams** → `/team-feature` (persistent agents with tmux panes, shared task list, inter-agent messaging). Only when the user has explicitly requested a coordinated team for this feature.

   For each planned task, list the units it touches and its predecessor task IDs (or `none` if independent). Build the graph from the units table:
   - **Vertical-slice discipline:** every task must deliver a thin end-to-end behaviour cutting through every relevant layer (schema → logic → API → UI → tests), not a horizontal slice of one layer. A completed task must be independently demoable or verifiable. Reject horizontal layer tasks ("set up schema", "build endpoints", "wire UI") — collapse them into thin vertical features. Prefer many thin slices over few thick ones.
   - **HITL vs AFK tag:** mark each task `HITL` (requires a human checkpoint — architectural decision, design review) or `AFK` (fully autonomous — agent ships without human interaction). Prefer AFK; only use HITL when human judgement is genuinely required.
   - Tasks A and B are parallelisable iff they touch disjoint units (and so disjoint files), have no shared dependencies neither has produced yet, and neither needs to read the other's output. Tasks that share a unit are sequential.
   - A unit's interface is a contract: if a task changes it, every task touching a unit that depends on it comes after.
   - Tasks that depend on a previous task's artifacts (a generated type, a new file, a schema migration) are sequential — dispatch only after the predecessor's review passes.
   - Default to sequential when in doubt; parallelism only pays off when the independence is obvious.

3. **Assign agent types (heuristic, no ask).** For each task, pick an implementer agent type from the guide below based on its primary language/domain. Then add a final **Polish** line — the agent type that will run `post-implementation-polish` after all tasks finish. Default is `general-purpose`; only pick a specialist when the diff is uniformly in one domain (e.g. all Rust → `rust-engineer`). Do NOT present a table for approval. Announce assignments as a single block:

    ```
    Agent assignments (auto-selected):
      Task 1: Implement auth middleware → rust-engineer                  (Rust)
      Task 2: Add API endpoints         → systems-programming:golang-pro  (Go)
      Task 3: Update Nix config         → general-purpose                 (Nix)
      Polish:                           → general-purpose                 (mixed diff)
    ```

    | Domain / Language      | Agent Type                               |
    |------------------------|------------------------------------------|
    | Rust                   | rust-engineer                            |
    | Go                     | systems-programming:golang-pro           |
    | Python                 | python-development:python-pro            |
    | Bevy game / engine     | bevy-engineer                            |
    | Unity game / C#        | unity-csharp-engineer                    |
    | Solidity / Web3 / DeFi | blockchain-web3:blockchain-developer     |
    | General / other        | general-purpose (default)                |

    **Bevy detection (use `bevy-engineer`, not `rust-engineer`):** if the project's `Cargo.toml` (or any workspace member's) lists `bevy = ...` as a dependency, or imports/uses Bevy types (`bevy::prelude`, `App`, `Plugin`, `Query`, `Component`, `Resource`), the task is Bevy work. Pick `bevy-engineer` for any task touching ECS systems, plugins, schedules, render/asset code, or Bevy build profiles — even if the surface change looks like "plain Rust".

    **Unity detection (use `unity-csharp-engineer` for C# game work):** if the project has a `ProjectSettings/ProjectVersion.txt`, an `Assets/` + `Packages/manifest.json` layout, `.asmdef` files, or `.cs` files that use `UnityEngine`/`MonoBehaviour`/`ScriptableObject`, the task is Unity work. Pick `unity-csharp-engineer` for any task touching MonoBehaviours, ScriptableObjects, scenes/prefabs, gameplay systems, or Unity performance/GC — even plain-looking `.cs` edits inside a Unity project.

The software design doc MUST include these sections, filled from the
steps above. They are authoritative; writing-plans and the execution
skills read from them:

- `## Units` — the units table from step 1 with each unit's `fails when` / `proven by` lines, plus any `Prep refactors` lines
- `## Execution Strategy` — `Subagents` (default) or `Agent teams` (only on explicit user request), plus a one-paragraph reason
- `## Task Dependency Graph` — each task (a vertical slice tagged `HITL` or `AFK`) mapped to the units it touches and its predecessor task IDs (or `none`)
- `## Agent Assignments` — task → agent type → language/domain, plus the mandatory `Polish:` line

**ADR check** (after writing the doc, before the checks below): scan it for decisions that satisfy ALL THREE criteria:
1. **Hard to reverse** — cost of changing your mind later is meaningful (DB engine, public API contract, encryption scheme, persistence model)
2. **Surprising without context** — a future reader will wonder "why did they do it this way?" If the choice is the obvious default, skip
3. **Result of a real trade-off** — genuine alternatives existed and you picked one for specific reasons. If only one option was ever viable, no ADR

For each decision passing all three, offer to draft an ADR alongside the doc at `docs/adr/NNNN-<slug>.md` (next available number). If any of the three is missing, do NOT offer — most decisions don't need ADRs, and a noisy ADR folder trains readers to ignore it. Read existing ADRs in `docs/adr/` while exploring so the design doesn't re-litigate decisions already made.
