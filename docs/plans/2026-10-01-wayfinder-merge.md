# Wayfinder + superpowers merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or `/team-feature` to implement this plan task-by-task, per the Execution Strategy below. Steps use checkbox (`- [ ]`) syntax — these are **persistent durable state**, not visual decoration. The executor edits the plan file in place: `- [ ]` → `- [x]` the instant a step verifies, before moving on. On resume (new session, crash, takeover), the executor scans existing `- [x]` marks and skips them — these steps are NOT redone. TodoWrite mirrors this state in-session; the plan file is the source of truth across sessions.

**Goal:** Make `/wayfinder` the driver for multi-session work in this repo. It charts maps, hands out one ticket per session through a locking `wayfinder-ticket` script, and routes implementation tickets through the patched superpowers phase skills on Claude and Codex.

**Architecture:** One shell script (`wayfinder-ticket`) owns all tracker state and every rule that can be machine-checked: references, claims, phases, worktree lookup and trailers. Skills reach the tracker only through it. Skill prose comes from per-skill patches against the pinned superpowers and mattpocock inputs, plus two vendored skills (`dissent-review`, `research-options`). The sandbox wrappers bind the git common dir and the main root, and they give each session an `AGENT_SESSION_ID`.

**Tech Stack:** Nix (home-manager, nix-darwin, NixOS VM tests), Bash via `writeShellApplication`, `yq-go`, `flock`, `git`, `gh`/`glab`, Markdown patches applied with `pkgs.applyPatches`.

**Spec:** `docs/specs/2026-10-01-wayfinder-merge-design.md`. The spec is the authority on behaviour, and every task names the spec sections it implements, so read those sections before starting a task. The plan adds what the spec leaves open: file layout, exact CLI output, exit codes, test names and verification commands. User-facing description: `docs/ai-workflow.md`.

## Execution Strategy

**Subagents.** Thirteen tasks. T1 and T2 have no predecessors and touch disjoint files, so they
form the first parallel batch. Files edited by several tasks get a single owner or a strict order:
`home/common/llm/skills.nix` (T1 → T4 → T5 → T6 → T8), `tests/default.nix` (T2 → T3 → T4 → T9 → T7),
`tests/llm-skills.nix` (T4 → T5 → T6 → T7 → T8 → T11), `tests/wayfinder-ticket.nix` and the script
(T2 → T13 → T10), `patches/mattpocock/setup-matt-pocock-skills.patch` (T4 → T10), sandbox wrappers
(T3 → T13 → T7), `home/common/codex/default.nix` (T3 → T11), `tests/codex.nix` (T3 → T7), `claude/overrides/CLAUDE.md` (T7 → T12), `claude/home/plugins.nix` and `home/common/llm/default.nix` (T1 → T11), `home/common/llm/superpowers.nix` and
`patches/superpowers/*.patch` (T1 → T9, after T13; T11 only reads `custom.llm.superpowersPackage`). T1 does
not touch `home/common/packages.nix`; T2 is its only editor. `tests/wayfinder-commands.nix` is created by T2; T8 and T9 only import it.

## Task Dependency Graph

| ID | Task | Tag | Depends on |
|---|---|---|---|
| T1 | Split superpowers and mattpocock patches per skill directory; move `patchedSuperpowers` into `home/common/llm/superpowers.nix` (`custom.llm.superpowersPackage`); verify byte-identical output | AFK | none |
| T2 | `wayfinder-ticket` local backend in `pkgs/wayfinder-ticket.nix`: references, map and ticket model, every command (incl. upkeep guards, `new --blocked-by`, `drop --superseded-by` with dependent rewiring, and proto worktree removal in `resolve`/`drop`/`map-complete`), `main-root`, `default-branch`, `merged`, `base-ref`, `close --outcome`, claim protocol, `trailer` (incl. `--cd`, `--remove`, `--discard`), `frontier`'s `waiting` marker; add to `home.packages`; `tests/wayfinder-ticket.nix` in the common set | AFK | none |
| T3 | Sandbox wrappers: shared bind function taking the program to exec, common-dir and main-root binds, two-pass bind order, `AGENT_SESSION_ID` (one `sharedEnvNames` entry; generated fresh in the Darwin `preHook`, both bwrap scripts and the Linux Claude passthrough wrapper), Codex `--no-daemon` and `daemon_auto_start = false`; Linux VM test with a stub program | AFK | T2 |
| T4 | Install `wayfinder`, `setup-matt-pocock-skills`, `grilling`, `prototype`, `domain-modeling`, `research`, `handoff` (source paths per Decisions); patches for handoff location, glossary path (domain-modeling incl. `CONTEXT-FORMAT.md`, setup `SKILL.md` (intro, Explore, step-2 skip rule, Section C, step-4 template), `domain.md` (incl. the `/grill-with-docs` pointer), improve-codebase-architecture), `codebase-design` files vendored into improve-codebase-architecture, `issue-tracker-local.md` replaced wholesale, setup's `.scratch/` mentions repointed, and `wayfinder.backend` in setup; `tests/llm-skills.nix` asserts the built setup skill contains no `.scratch/`; create `tests/llm-skills.nix` | AFK | T1, T3 |
| T5 | Vendor `dissent-review` as a directory skill with the changes listed under Review gate; extend `tests/llm-skills.nix` | AFK | T4 |
| T6 | Vendor `research-options` with the changes listed under Research; extend `tests/llm-skills.nix` | AFK | T5 |
| T7 | Ferrex gating (CLAUDE.md split, commands, `/docs`, permission filter in `claude/home.nix`, `~/.ferrex` binds); re-enable `tests/codex.nix`; extend `tests/llm-skills.nix` | AFK | T6, T9, T13 |
| T8 | Wayfinder patch: all tracker access via `wayfinder-ticket`, references, ticket types and research subtypes, map upkeep without a claim, pending upkeep and its retry on entry, "history is never reopened" corrections, prototype override (`.claude/worktrees/` location), background subagents only for `research:fact`, implementation-ticket rule, resume `mine` first, map-state check on entry (incl. `map-complete`), `research:fact` subagents `attach` instead of upstream's `research/<name>` branch, routing by phase, trailers via `trailer`, charting-session order, the unmerged-blocker check before decision tickets (note and proceed), lost claim races (next frontier entry), dissent hook, "Asking the user"; register the patch in `skills.nix` | HITL | T6, T7 |
| T9 | Superpowers patches: ticket mode per the Phase handoff table (brainstorming incl. the ticket's named worktree via using-git-worktrees, the unmerged-blocker check and stacking, Architectural-only and Spike/Bounded handling, writing-plans incl. ticket-mode plan approval, executing-plans, subagent-driven-development incl. drop-or-re-file on discard and the `ticket=` argument to finishing), review gate (dissent then loop cap 3; findings against closed tickets always "ask"), finishing-a-development-branch (`main-root`, host-owned Discard stop, guarded `git pull`, ticket-mode removal deferred to the restart line; Patch layout), restore `plan-document-reviewer-prompt.md`, reconcile the executing-plans Inline-Degraded gate, its Post-Implementation Polish lines and rationalization row with the OR rule (see Context), "Asking the user" | HITL | T1, T2, T5, T13 |
| T10 | GitHub/GitLab backends in `wayfinder-ticket` per the Backends mapping (advisory claims, `release --force`, `trailer` releasing before a restart line, `merged`'s forge fallback (`gh pr list` / `glab mr list`), `glab` looked up on `PATH`), cases added to `tests/wayfinder-ticket.nix`; rewrite the GitHub/GitLab "Wayfinding operations" sections in the setup patch | AFK | T4, T13 |
| T11 | Codex parity: superpowers skill directories into `~/.codex/skills/` via `home/common/codex/default.nix`; extend `tests/llm-skills.nix` | AFK | T7, T8, T9 |
| T12 | Manual end-to-end checklist (normal clone, linked worktree, bare clone; Claude only, since Codex is disabled on every host; macOS and NixOS VM; a prototype ticket follows the T8 override; on Claude, ticket-mode brainstorming actually calls `EnterWorktree path=`, and only if the model refuses, T12 adds a narrowly scoped `claude/overrides/CLAUDE.md` line); update `docs/ai-workflow.md` status, repo `CLAUDE.md` and README | HITL | T6, T8, T10, T11, T13 |
| T13 | Real-sandbox check of the claim protocol after `just switch` on the Mac and the NixOS VM: process discovery, holder detaching, Esc interrupt, agent exit frees the lock, the session id survives `/clear`, whether Claude's `EnterWorktree` cwd survives `/clear` (if not, `trailer` prints the restart line for Claude too), whether `EnterWorktree path=` enters a ticket worktree made by `git worktree add`, whether a session there sees the main worktree's project rules and agents; fix in T2/T3 files if needed (the rules/agents symlink fallback lands in T9's brainstorming patch) | HITL | T3 |

T8 and T9 are HITL because their skill prose needs a human read before it ships. T12 and T13 are
HITL because they need interactive sessions on both machines. T2, T3, T7 and T10 stay AFK except for
their `aarch64-linux` build steps, which are foreground stop points on the VM (see below).

**HITL execution.** These steps override SDD's "Rulings, not stalls": the controller never rules on them and a subagent never flips their boxes. T8 Steps 1–4 and T9 Steps 1–6 are dispatched as usual; T8 Step 5 and T9 Step 7 are stop points the controller runs in the foreground with the user. T12 and T13 are not dispatched at all; the controller and user run them in the foreground (T13 can run while T4's subagent works in Batch 3). Linux build steps in T2, T3, T7 and T10 run on the personal-nixos VM, so each of those tasks ends with a VM stop point (T2 Step 17, T3 Step 7, T7 Step 6, T10 Step 7). A VM stop point is always the task's last step and comes after its commit, so a push carries everything it builds: the subagent does every Mac-side step (including `nix eval … .drvPath`, which needs no Linux builder), commits, reports `STOPPED at <task> Step <n>` and returns. The controller names the branch to push (the task's isolation branch when it has a worktree, otherwise the integration branch); the user pushes it and checks it out on the VM; the controller and user run the step there in the foreground, and the controller flips its box (on the task branch if the task has one, else on the integration branch). Per-task review runs after the stop point passes. A fix, for a VM failure or a review finding, goes into the task's existing worktree, or the integration tree when the task has none (dispatch without `isolation` with a prompt that names the worktree's absolute path and requires absolute paths into it, or continue the same agent via SendMessage), never a fresh isolated worktree; any commit after the stop point that touches files the step builds makes the controller reopen its box (a `plan: …` commit under the same rule), and the controller pushes and re-runs the step before merging. Controller flips are committed at once (see Isolation). Before `just switch`, the user pushes the branch and checks it out on each VM that step switches (both NixOS VMs in T12, personal-nixos in T13).

**Isolation for parallel tasks.** Each task in a batch with more than one task runs in its own git worktree (`isolation: "worktree"` on the Agent dispatch), branched from the integration branch after the previous batch merged. The controller merges each task's branch back once its review passes. Commit this plan, the spec and the `codexPlain` TODO in `home/linux/sandboxed.nix` before Batch 1 so every worktree has them. Implementers flip each step's box in their worktree as the step verifies, and the flip rides with that step's commit; it reaches the integration branch when the controller merges the task. The controller flips only boxes still open after review, and VM stop points (see HITL execution). Every box the controller flips is committed at once as its own commit (`plan: tick <task> Step <n>`), on the task branch when the task has a worktree, otherwise on the integration branch, so the plan file is never left dirty for a later merge. On resume, the controller first runs `git worktree list` and checks for unmerged task branches; for each, it reads that branch's checkboxes and continues from there (re-review and merge, or re-dispatch only the open steps into that existing worktree), never from the integration branch's unchecked boxes. Flakes build from the dirty working tree, so a shared tree would let one task's deliberate red step (or half-done edit) fail a neighbour's check. T13 runs `just switch` only from its own clean worktree, never from a tree that another task is editing. T13 is not dispatched, so the controller creates that worktree by hand (`git worktree add -b t13 <path> <integration>` after Batch 2 merges), the user pushes `t13` for the VM checkout, and the controller merges `t13` with T4 at the end of Batch 3.

Batches derived from the table:

- Batch 1: T1, T2
- Batch 2: T3
- Batch 3: T4, T13 [HITL]
- Batch 4: T5, T10
- Batch 5: T6, T9 [HITL]
- Batch 6: T7
- Batch 7: T8 [HITL]
- Batch 8: T11
- Batch 9: T12 [HITL]

Deviation from the spec's graph: T8 also appends to `tests/llm-skills.nix`, which the spec's order (T4 → T5 → T6 → T7 → T11) leaves out. The table above therefore adds T7 → T8 → T11 to the dependencies, so the order is T4 → T5 → T6 → T7 → T8 → T11. Likewise T9 edits `tests/default.nix`, which the spec's order (T2 → T3 → T4 → T7) leaves out, so the table adds T9 → T7.

## Agent Assignments

```
Agent assignments (auto-selected):
  T1:  Split patches                 → general-purpose   (Nix, patches)
  T2:  wayfinder-ticket + tests      → general-purpose   (Bash, Nix)
  T3:  Sandbox wrappers              → general-purpose   (Nix, Bash)
  T4:  Install mattpocock skills     → general-purpose   (Nix, Markdown patches)
  T5:  dissent-review                → general-purpose   (Markdown, Nix)
  T6:  research-options              → general-purpose   (Markdown, Nix)
  T7:  Ferrex gating                 → general-purpose   (Nix, Markdown)
  T8:  Wayfinder patch               → general-purpose   (Markdown patch)
  T9:  Superpowers ticket mode       → general-purpose   (Markdown patch)
  T10: gh/glab backends              → general-purpose   (Bash)
  T11: Codex parity                  → general-purpose   (Nix)
  T12: End-to-end verification       → controller + user (not dispatched)
  T13: Real-sandbox claim check      → controller + user (not dispatched)
  Polish:                            → general-purpose   (mixed diff)
```

## Global Constraints

- Pins stay as they are: superpowers v6.4.2 (`8ca22db`), mattpocock/skills `c55ee46`. Content copied from zvolin comes from `zvolin/nixos-config@27d4369c3512455d8a1ce83bd90bebc77fe890bd` and nowhere else.
- No zvolin patch is applied verbatim. Features are ported by hand onto our patches.
- Every patch must apply under `pkgs.applyPatches`. A patch that fails to apply fails the build, and that is the drift detector, so never turn a hunk into a new-file hunk to make it apply.
- Slug regex `^[a-z0-9][a-z0-9-]*$`, id regex `^[1-9][0-9]*$`, checked before any filesystem access.
- Nothing under a map dir is written with Edit/Write. Every tracker write goes through `wayfinder-ticket` via Bash.
- Local map location: `$(git rev-parse --path-format=absolute --git-common-dir)/wayfinder/<slug>/`.
- Backend selection: `git config wayfinder.backend local|github|gitlab`, default `local`.
- Worktree names: prototype `wayfinder-<slug>-<id>`, implementation `wayfinder-<slug>-<id>-impl`, both under `<main root>/.claude/worktrees/`. Lookups match the exact basename and never use a glob.
- Never `git worktree remove --force` on an implementation worktree, and never rebase, reset, stash or force-push on the user's default branch. (Prototype worktrees are removed with `--force` by `resolve`/`drop`/`map-complete`, as the spec says.)
- GitLab labels never contain `::`.
- Nix style: `lib.getExe` over `${pkg}/bin/x`, no `with lib;`, `lib.mkIf`/`lib.optional*` over `if`, clean under `alejandra`, `statix` and `deadnix`. Shipped Bash and the test stubs are built with `writeShellApplication`, which enforces `shellcheck` at build time, except the bwrap sandbox wrappers, which stay on `writeShellScriptBin` (see T3; errexit would abort on the `bind_ro`/`bind_rw` helpers). The test harness and case files (`tests/wayfinder-ticket/*.sh`) are not shellchecked.
- Every new test file goes into `tests/default.nix` in the set the spec names: common for `wayfinder-ticket.nix`, `llm-skills.nix` and `codex.nix`, Linux-only for the sandbox VM test.
- Commit messages are one short line with no Co-Authored-By trailer (the user's global instruction overrides the harness default).
- Run `git add -N <file>` on every new file before any `nix build .#…`, `nix eval .#…` or `builtins.getFlake` call. A flake built from a git tree can't see untracked files, so without it a red step fails on a missing path and not on the test.
- `aarch64-linux` builds (`.#checks.aarch64-linux.*` and the T3/T7 `nixosConfigurations.personal-nixos` toplevel build) run on the personal-nixos VM from a pushed checkout of the committed task or integration branch (see HITL execution). The Mac has no Linux builder and its daemon ignores `--builders` from an untrusted user, so a Linux build run there fails on the platform, not on the test.
- `just check` and the touched checks must pass before a task is done. Full `nix flake check` runs in T12.

## Review Focus

1. **Titles and file contents with YAML-special characters** (`:`, `#`, quotes, a leading `-`, non-ASCII): a person writes `new offline-sync task "Fix: sync #2 – retry"` and expects the title back verbatim with valid frontmatter. Test `test_title_yaml_special_chars` in T2.
2. **Commands run from a subdirectory or a linked worktree, or outside any repo:** a person runs `wayfinder-ticket frontier foo` from `src/lib/` of a ticket worktree and expects the same map as from the main root. Outside a repo they expect a one-line error, not a yq/git trace. Tests `test_from_subdir_and_linked_worktree` and `test_outside_repo` in T2.
3. **Paths with spaces** in the main root or worktree: a person pastes the restart line and it works. Test `test_trailer_quotes_paths_with_spaces` in T2.
4. **Concurrent mutating commands on one map** (two `new` at once, or `map-edit` racing `new`): each ticket gets a unique id and no write is lost. Test `test_concurrent_new_unique_ids` in T2.
5. **`claim` called from a tool call whose stdout is a pipe:** the call returns at once and the holder doesn't hold the pipe open. Test `test_claim_returns_with_piped_stdout` in T2, plus the real-harness check in T13.

---

## Shared interface: `wayfinder-ticket` CLI contract

T2 defines this, and T3, T8, T9, T10 and T13 consume it. The spec's command table is the behaviour. This section pins what the spec leaves open.

**Files (local backend)** under `$common/wayfinder/<slug>/`: `map.md`, `<id>.md`, `<id>.claim`, `map.write`, `findings/<id>.md`. The next id is the highest existing id + 1, taken under `map.write`. `new` also creates the empty `<id>.claim` file, so `claim` never has to create a file in the map dir before its first write. Frontmatter is YAML, read and written with `yq --front-matter=process`. `blocked-by` is a YAML list of integers, and empty fields are `""` (never omitted).

**Sections (all backends):** Body sections are `## <Name>` headings in the order the spec gives. Only the spec's fixed headings are section boundaries (map: `Destination`, `Decisions so far`, `Not yet specified`, `Out of scope`, `Notes`; ticket: `Question`, `Notes`, `Answer`, `Verification evidence`); any other `## ` line is ordinary content. `section_set` rejects input containing a line exactly equal to one of the reserved headings for that file (exit 1, reason `content contains section heading: ## <Name>`). Files and bodies are LF-normalised on read, before `yq` and any section parsing or hashing: `section_get`, `section_set` (on both the stored body and the new input) and the `show-map` hash strip `\r` first, and every write stores LF. Forge web UIs return edited issue bodies with CRLF, and a `## Notes\r` line would otherwise not match its heading.

**Exit codes:** `0` success; `1` generic rejection; `2` usage error; `3` map or ticket not found; `4` ticket closed; `5` phase mismatch; `6` live claim by another session; `7` blocked. A "not owner" rejection (`attach`, `release`, `advance`, `resolve`, `close`) is `6` when another session holds a live claim, otherwise `1` with reason `not owner of <ref>`. `3` applies only to the command's own `<slug>`/`<ref>`; an id passed as an argument (`--blocked-by`, `block`/`unblock`, `--superseded-by`) that is not in the map is `1` with reason `id <n> not in map`. Any non-zero exit means nothing was written. Every rejection prints exactly one line to stderr: `wayfinder-ticket: <reason>`. Skill patches (T8, T9) branch on exit codes, never on message text.

Pinned rejection reasons (tests assert these substrings):
- unknown command (exit 2): `unknown command: <name>`
- not found: `not found: <ref>`
- phase mismatch: `phase is <actual>, expected <p>`
- live claim: `claimed by another session (<session-id>)`
- blocked: `blocked by <id>[,<id>…]`
- no agent: `no agent process found (looked for .claude-unwrapped, claude, codex-raw, codex)`
- wrong checkout: `<spec|plan> lives in worktree <path>; restart there`
- missing session: `AGENT_SESSION_ID is not set; start the agent through claude-sandboxed or codex-sandboxed`

**Output formats** (tab-separated where shown):
- `maps`: one line per map, `<slug>\t<status>\t<open-count>`, sorted by slug.
- `new`: the bare new id (`^[1-9][0-9]*$`) as its only stdout line. `map-new` prints nothing.
- `frontier <slug>`: one line per entry, `<id>\t<type>\t<phase or ->\t<marker>`. The marker is `mine`, `mine (blocked)`, `waiting <branch>[ <branch>…]` (one branch per `waiting on merge:` Notes line, in Notes order; wayfinder routes the entry only when every branch is `merged` or `unknown`) or empty. `mine*` entries come first, then the rest in id order.
- `status <ref>`: `key: value` lines in this order: `ref`, `type`, `status`, `phase`, `blocked-by` (comma-joined ids, empty when none), `claimed-by`, `claim` (`live`, `stale` or `none`; remote backends: `held` or `none`, see T10), `superseded-by`, `branch`, `path`.
- `show <ref>`: first line `path: <file or URL>`, then the file verbatim. `show-map <slug>` does the same, then prints one `section-hash\t<Section Name>\t<sha256>` line per body section. The hash is the `sha256sum` of the section's bytes (after LF normalisation, see Sections) between its heading line and the next reserved section heading (or EOF); that is the value `map-edit --expect` takes.
- `claim` taking over a stale claim prints `took over stale claim from <old-session-id>` on stdout and exits 0.
- `merged <branch>` prints exactly one of `merged local`, `merged origin`, `merged forge`, `unmerged`, `unknown`.
- `main-root`, `default-branch` and `base-ref` print a single line.

**Trailer output.** `<next>` is a bare name (`wayfinder`, `brainstorming`, `writing-plans`, `executing-plans`); callers strip `superpowers:` from a `phase:` value. Stdout is always exactly two lines. On remote backends, when a restart line is printed, `trailer` first writes one stderr line `wayfinder-ticket: released <slug>#<id>` (exit 0; the one stderr line that is not a rejection). Arguments are quoted with `printf %q`.

| Case | Line 1 | Line 2 |
|---|---|---|
| Claude, same toplevel | `/clear` | `/wayfinder <slug>` or `/superpowers:<phase> <slug>#<id>` |
| Codex, same toplevel | `/clear` | `$wayfinder <slug>` or `$<phase> <slug>#<id>` |
| restart (phase worktree differs) | `exit, then run: cd <path> && <a\|o>` | the phase command as above |
| `--cd <dir>` | `exit, then run: cd <dir> && <a\|o>` | `/wayfinder <slug>` / `$wayfinder <slug>` |
| `--cd <dir> --remove <wt> [--discard]` | `exit, then run: cd <dir> && git worktree remove <wt> && git branch -d\|-D <branch> && <a\|o>` | as above |

`<branch>` in the `--remove` form is the branch checked out in `<wt>`, read from `git worktree list --porcelain`.

**Agent identity.** `WAYFINDER_AGENT_PID` overrides the process walk and `WAYFINDER_AGENT_START` overrides the agent start time everywhere it is read: at claim, in the holder's pre-detach check and in `release`. Unset, the value is the raw `/proc/<pid>/stat` field 22 on Linux and the `ps -o lstart= -p <pid>` string on Darwin. The internal `wayfinder-ticket __agent-pid` prints the result of the process walk (exit 1 if no agent process is found), and `wayfinder-ticket __agent-start <pid>` prints the start-time value, so the T3 VM stub can export a correct override. `WAYFINDER_HARNESS=claude|codex` overrides harness detection. The holder's PID file is `${TMPDIR:-/tmp}/wayfinder-$AGENT_SESSION_ID/<slug>-<id>.pid`, containing three lines: holder PID, agent PID, agent start time. On every poll the holder re-reads the agent start time from that file, which is how `test_pid_reuse_is_stale` simulates reuse without a real PID wraparound.

---

### Task 1: Split patches per skill and move `patchedSuperpowers`

Spec: Patch layout; Codex parity (first paragraph); Success criterion "byte-identical".

**Files:**
- Create: `patches/superpowers/{brainstorming,writing-plans,executing-plans,subagent-driven-development,requesting-code-review}.patch` (the directories today's patch touches; confirm with `grep '^diff --git' patches/superpowers-customizations.patch`)
- Create: `patches/mattpocock/improve-codebase-architecture.patch` (`git mv` of `patches/mattpocock-skills-customizations.patch`, unchanged: it has no `diff --git` headers and a single target, confirmed with `grep '^+++' patches/mattpocock-skills-customizations.patch`)
- Create: `home/common/llm/superpowers.nix`
- Delete: `patches/superpowers-customizations.patch` (the mattpocock patch is moved, not deleted)
- Modify: `claude/home/plugins.nix:20-24` (drop the `let` binding, read `config.custom.llm.superpowersPackage`), `home/common/llm/default.nix` (import `./superpowers.nix`), `home/common/llm/skills.nix:6-10` (`patchedMattpocockSkills.patches` → `map (n: ../../../patches/mattpocock + "/${n}") ["improve-codebase-architecture.patch"]`; T4/T8 append names to this list)

**Interfaces:**
- Produces: option `custom.llm.superpowersPackage` (`lib.types.package`, `readOnly = true`, set unconditionally to the `applyPatches` result named `superpowers-patched`). The patch lists are spelled out explicitly, never globbed with `builtins.readDir`, so a new patch shows up in review as a list change.
- Produces: `home/common/llm/skills.nix` keeps a `patchedMattpocockSkills` binding that T4–T8 extend.

- [ ] **Step 1: Record the pre-split trees**

Run:
```bash
nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.aarch64-darwin; in p.applyPatches { name = "superpowers-patched"; src = f.inputs.superpowers; patches = [./patches/superpowers-customizations.patch]; }' > /tmp/sp-before
nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.aarch64-darwin; in p.applyPatches { name = "mattpocock-skills-patched"; src = f.inputs.mattpocock-skills; patches = [./patches/mattpocock-skills-customizations.patch]; }' > /tmp/mp-before
```
Expected: two store paths.

- [ ] **Step 2: Split the superpowers patch by `diff --git` header into per-directory files; `git mv` the mattpocock patch to `patches/mattpocock/improve-codebase-architecture.patch`**

For the superpowers patch, use `filterdiff -i '*/skills/<dir>/*'` from `patchutils` (`nix shell nixpkgs#patchutils`), once per directory. Every hunk must land in exactly one output file. Check this by comparing `grep -c '^@@'` across the outputs with the original.

- [ ] **Step 3: Add `home/common/llm/superpowers.nix` and rewire `plugins.nix` and `skills.nix`**

The module takes `{inputs, lib, pkgs, ...}`. Do not wrap it in `lib.mkIf config.custom.claude.enable`, because `tests/codex.nix` enables only Codex (spec, Codex parity).

- [ ] **Step 4: Verify byte-identical output**

Run:
```bash
diff -r "$(cat /tmp/sp-before)" "$(nix build --no-link --print-out-paths .#darwinConfigurations.burnedapple.config.home-manager.users.vaporif.custom.llm.superpowersPackage)"
A='.#darwinConfigurations.burnedapple.config.home-manager.users.vaporif.home.file.".claude/skills/improve-codebase-architecture".source'
drv=$(nix eval --raw "$A" --apply 's: builtins.head (builtins.attrNames (builtins.getContext s))')
nix build --no-link "$drv^out"
diff -r "$(cat /tmp/mp-before)/skills/engineering/improve-codebase-architecture" "$(nix eval --raw "$A")"
```
If `/tmp/sp-before` or `/tmp/mp-before` is missing (a resumed session skips the ticked Step 1, or `/tmp` was cleared), rebuild them from `HEAD`, which is still the pre-split commit until Step 6. Step 1's commands no longer work at this point, because Step 2 moved the patch files:
```bash
f="builtins.getFlake \"git+file://$PWD?rev=$(git rev-parse HEAD)\""
nix build --no-link --print-out-paths --impure --expr "let f = $f; p = f.inputs.nixpkgs.legacyPackages.aarch64-darwin; in p.applyPatches { name = \"superpowers-patched\"; src = f.inputs.superpowers; patches = [ (f + \"/patches/superpowers-customizations.patch\") ]; }" > /tmp/sp-before
nix build --no-link --print-out-paths --impure --expr "let f = $f; p = f.inputs.nixpkgs.legacyPackages.aarch64-darwin; in p.applyPatches { name = \"mattpocock-skills-patched\"; src = f.inputs.mattpocock-skills; patches = [ (f + \"/patches/mattpocock-skills-customizations.patch\") ]; }" > /tmp/mp-before
```
Expected: no output and exit 0 from both diffs. The mattpocock check reads the subtree the rewired `skills.nix` actually installs; the `.source` is a subpath string, so its derivation is built from the string context first.

- [ ] **Step 5: Lint and evaluate**

Run: `just check && nix build --no-link .#darwinConfigurations.burnedapple.system`
Expected: both succeed.

- [ ] **Step 6: Commit** — `git commit -m "split superpowers/mattpocock patches per skill"`

---

### Task 2: `wayfinder-ticket` local backend

Spec: Tracker; References; Invocation (slug listing); Map model; Ticket model (incl. the type/phase table and "When implementation tickets are created" for worktree removal); `wayfinder-ticket` script (entire command table, Map upkeep without a claim, History is never reopened); Main root; Claim protocol (local backend) steps 1–8; Testing → `tests/wayfinder-ticket.nix` (local cases).

**Files:**
- Create: `pkgs/wayfinder-ticket.nix`, a `writeShellApplication` with `text = lib.concatMapStrings builtins.readFile [ ./wayfinder-ticket/lib.sh ./wayfinder-ticket/model.sh ./wayfinder-ticket/git.sh ./wayfinder-ticket/claim.sh ./wayfinder-ticket/commands.sh ./wayfinder-ticket/trailer.sh ./wayfinder-ticket/main.sh ]`
- Create: `pkgs/wayfinder-ticket/{lib,model,git,claim,commands,trailer,main}.sh`
- Create: `tests/wayfinder-ticket.nix`, `tests/wayfinder-ticket/run.sh`, `tests/wayfinder-ticket/fixtures.sh`, `tests/wayfinder-ticket/local.sh`, `tests/wayfinder-commands.nix` (a Nix list of the public command names from the spec's command table, imported by the T8 and T9 allowlist checks; `test_usage_unknown_command`'s sibling `test_command_list_matches_dispatcher` asserts every name in it is dispatched by `main.sh`; both are written in Step 1)
- Modify: `overlays/packages.nix` (add `wayfinder-ticket = final.callPackage ../pkgs/wayfinder-ticket.nix {};`), `home/common/packages.nix` (add `pkgs.wayfinder-ticket` to `home.packages`), `tests/default.nix` (common set: `wayfinder-ticket = import ./wayfinder-ticket.nix {inherit pkgs;};`)

The script is split into several source files and concatenated. One file would pass review as well, but at roughly 1,000 lines of Bash it would be hard to keep in context. The split keeps each file to one concern, and T10 adds `backend-github.sh` and `backend-gitlab.sh` beside them. The cost is that shellcheck line numbers refer to the concatenated text.

`runtimeInputs`: `git flock yq-go coreutils procps util-linux gh` on both platforms (nixpkgs `util-linux` ships `setsid` on Darwin too, so the holder uses `setsid -f` everywhere). Declare `gh` as a `callPackage` argument so T10's test can `.override { gh = stub; }`.

**Test harness.** `tests/wayfinder-ticket.nix` is a `runCommand` with `nativeBuildInputs = [bash git coreutils procps flock util-linux]` that runs `run.sh` with `WT=${lib.getExe pkgs.wayfinder-ticket}`, `BCLONE=${../scripts/git-bare-clone.sh}` and `WT_COMMANDS="${lib.concatStringsSep " " (import ./wayfinder-commands.nix)}"`. `run.sh` exports `HOME=$TMPDIR` and `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`/`GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL`, and compares paths only after `realpath`, because Darwin temp dirs sit behind symlinks. `run.sh` sources `fixtures.sh` and every `*.sh` case file. It runs each `test_*` function in its own subshell, inside a fresh `$TMPDIR/case-<name>`, prints `ok`/`FAIL <name>` per case and exits non-zero if any case failed. `run.sh <pattern>` runs only the matching cases.

Fixtures (`fixtures.sh`), with stable names because later tasks reuse them:
- `mk_origin` creates a bare `origin.git` with one commit on `main` and `HEAD → main`.
- `mk_clone` makes a normal clone of it at `./repo` and `cd`s there.
- `mk_bclone` runs `bash "$BCLONE" file://$PWD/origin.git` (the script's `/usr/bin/env` shebang doesn't resolve in the Linux build sandbox) and `cd`s into `origin/main`.
- `new_session` exports a fresh `AGENT_SESSION_ID` (`test-$RANDOM-$RANDOM`), starts `sleep 600 >/dev/null 2>&1 &` and exports `WAYFINDER_AGENT_PID=$!`. Each case's subshell sets `trap 'kill $(jobs -p) 2>/dev/null; for f in "${TMPDIR:-/tmp}"/wayfinder-*/*.pid; do [ -e "$f" ] && kill "$(head -1 "$f")" 2>/dev/null; done' EXIT` (nixpkgs `procps` on Darwin has no `pkill`). Darwin builds have no PID namespace, so a stray background process holding the log pipe would keep the build open.
- `kill_agent` kills that sleep.
- `wait_unlocked <slug> <id>` polls `flock -n` on the claim file for up to 8 s.
- `mk_map <slug>` calls `map-new` and echoes the slug; `mk_ticket <slug> <type> [args…]` echoes `new`'s stdout (the id).
- `assert_eq`, `assert_contains`, `assert_exit <code> <cmd…>`, `assert_unchanged <dir> <cmd…>` (hashes the map dir before and after a rejected command).

Fast local loop:
```bash
WT=$(nix build --no-link --print-out-paths --impure --expr '(builtins.getFlake (toString ./.)).darwinConfigurations.burnedapple.pkgs.wayfinder-ticket')/bin/wayfinder-ticket BCLONE=$PWD/scripts/git-bare-clone.sh bash tests/wayfinder-ticket/run.sh <pattern>
```
Full check: `nix build -L .#checks.aarch64-darwin.wayfinder-ticket`. Under an agent's Bash tool the fast loop has a real agent ancestor, so `run.sh` skips `test_claim_no_agent_ancestor`, the no-harness case of `test_trailer_rejections` and the harness-detection asserts whenever `wayfinder-ticket __agent-pid` (with `WAYFINDER_AGENT_PID` unset) finds one (printing `skip`). Only the `nix build` run is authoritative for those cases.

**Interfaces:**
- Produces: the CLI contract in "Shared interface" above. Internally, `lib.sh` exports `die <code> <msg>`, `parse_ref <ref>` (sets `SLUG`, `ID`), `common_dir`, `map_dir <slug>`, `with_map_lock <slug> <fn> [args…]`, `fm_get <file> <key>`, `fm_set <file> <key> <yaml-value>` (temp file + rename), `section_get`/`section_set <file> <name>`. T10 dispatches on `backend` (`git config --default local wayfinder.backend`) at the top of each command entry point (`commands.sh`, `claim.sh`, `git.sh`, `trailer.sh`), so each command body is a `local_<cmd>` function.

Each stage below is one red/green cycle. Write the listed tests, see them fail, implement, see them pass, then commit. The spec's command table gives the behaviour. The test names give the cases, and each case's assertions are the spec's "Rejected when" column plus the Testing bullet text it mirrors.

- [x] **Step 1: Scaffold the package, test harness and `tests/default.nix` entry; create `tests/wayfinder-commands.nix` from the spec's command table; write two tests: `test_usage_unknown_command` (`assert_exit 2 $WT bogus` and stderr contains `unknown command: bogus`) and `test_command_list_matches_dispatcher` (for each name in `$WT_COMMANDS`, stderr of `$WT <name>` does not contain `unknown command:`; it asserts no exit code, since a known command with missing args is also exit 2)**

Run: `nix build -L .#checks.aarch64-darwin.wayfinder-ticket`
Expected: `test_usage_unknown_command` FAILS (the script is a stub that exits 0). `test_command_list_matches_dispatcher` passes vacuously on the stub and only becomes meaningful once Step 2's dispatcher exists.

- [x] **Step 2: Make them pass (dispatcher in `main.sh` with a case for every name in `wayfinder-commands.nix`, each unimplemented one calling `die` with a "not implemented" message; `die`; usage) and commit, including `tests/wayfinder-commands.nix`** — `wayfinder-ticket: scaffold`

- [x] **Step 3: Stage A tests (references, maps, tickets, sections).** Write `test_ref_rejects_bad_slug` (`../x`, `A`, `-x`, `x/y`), `test_ref_rejects_bad_id` (`0`, `01`, `1a`), `test_map_new_and_maps`, `test_map_new_rejects_existing`, `test_new_assigns_next_id_and_initial_phase` (one case per type, phases per the spec's type table), `test_new_rejects_unknown_type`, `test_new_blocked_by_atomic` (the file already holds `blocked-by` when `new` returns; an unknown id is rejected with exit 1 and nothing written), `test_show_and_show_map_hashes`, `test_map_edit_expect` (a stale `--expect` → 1, missing `--expect` → 2, `Decisions so far` → 1, unknown section → 1, all `assert_unchanged`), `test_edit_sections_and_title`, `test_malformed_frontmatter_rejected`, `test_title_yaml_special_chars`, `test_from_subdir_and_linked_worktree`, `test_outside_repo` (exit 1, a one-line message), `test_concurrent_new_unique_ids` (20 background `new`, ids 1..20 each exactly once), `test_section_text_with_h2_roundtrips` (map: `map-edit <slug> Notes` with a file containing `## Option A`; `show-map` shows it inside Notes and the other four sections' `section-hash` lines are unchanged; ticket: `edit <ref> Notes` with the same file; `show` shows it under `## Notes` and Question is byte-identical), `test_section_text_rejects_reserved_heading` (`map-edit`, `edit`, `new --question` and `map-new --destination` with a `## Notes` line → 1, `assert_unchanged`, and for `new`/`map-new` nothing is created; the same guard in `resolve`/`close`/`drop` is tested in Stage D), `test_section_crlf_normalised` (a `map.md` rewritten with `\r\n`: `show-map` hashes equal those of the LF file, `map-edit` succeeds, and the file has no `\r` afterwards)

- [x] **Step 4: Run Stage A, expect FAIL on all of them**

- [x] **Step 5: Implement Stage A in `lib.sh`, `model.sh` and `commands.sh` (`map-new`, `maps`, `map-edit`, `new`, `show`, `show-map`, `edit`)**

- [x] **Step 6: Run Stage A, expect PASS; commit** — `wayfinder-ticket: maps and tickets`

- [x] **Step 7: Stage B tests (git helpers).** Write `test_main_root_normal_clone`, `test_main_root_from_nested_claude_worktree`, `test_main_root_bclone_default_worktree`, `test_main_root_bclone_main_switched_away` (the first worktree not under `.claude/worktrees/`), `test_main_root_bclone_origin_head_after_fetch`, `test_main_root_bclone_wb_sibling_listed_first`, `test_default_branch_bare_name` (normal clone, fresh bclone, fetched bclone: all print `main`), `test_merged_local_only`, `test_merged_origin_only`, `test_merged_missing_ref_unknown`, `test_merged_no_origin_ref`, `test_base_ref_stack`, `test_base_ref_no_blockers_origin_strictly_ahead`

- [x] **Step 8: Run Stage B, expect FAIL; implement `git.sh` (`main-root`, `default-branch`, `merged`, and `base-ref`'s blocker-free and `--stack` paths; the closed-blocker path is tested in Stage D, once `close` exists); run, expect PASS; commit** — `wayfinder-ticket: git helpers`

- [x] **Step 9: Stage C tests (claim protocol).** Write `test_claim_requires_session_id`, `test_claim_no_agent_ancestor` (unset `WAYFINDER_AGENT_PID`, exit 1, no-agent message, `claimed-by` empty), `test_claim_agent_pid_exited` (same assertions), `test_concurrent_claims_one_wins` (two sessions in parallel, exactly one exit 0, the other exit 6), `test_claim_reentrant_owner`, `test_owner_killed_then_reclaim` (`kill_agent`, `wait_unlocked`, new session claims, stdout has `took over stale claim`), `test_pid_reuse_is_stale` (rewrite line 3 of the PID file, `wait_unlocked` succeeds), `test_reclaim_right_after_release`, `test_claim_phase_mismatch` (exit 5, reports the actual phase; on the re-entrant path the claim stays held), `test_claim_blocked` (7), `test_claim_failed_write_leaves_lock_free` (make the ticket file read-only by making its directory non-writable, claim fails, `wait_unlocked` succeeds at once), `test_claim_returns_with_piped_stdout` (`timeout 5 $WT claim … | cat` exits 0)

- [x] **Step 10: Run Stage C, expect FAIL; implement `claim.sh` (`claim`, `release`, agent walk, holder, liveness, PID file) exactly in the order of claim protocol steps 2–7 (step 8's `--phase` spec/plan guard lands in Stage D with its tests); run, expect PASS; commit** — `wayfinder-ticket: claim protocol`

The holder is a re-exec of the script itself (`wayfinder-ticket __hold <slug> <id>`), so it stays shellchecked and shares the agent-walk code. Close the `map.write` fd before spawning it, redirect all three standard streams to `/dev/null`, and give every holder child `9>&-`.

- [x] **Step 11: Stage D tests (lifecycle and upkeep).** Write `test_advance_legal_edges_keep_claim`, `test_advance_illegal_edge_and_phase_cas`, `test_advance_rejects_non_owner` (live foreign claim → 6, unclaimed or stale → 1, both `assert_unchanged`), `test_attach_owner_only`, `test_resolve_writes_answer_and_decision_pointer`, `test_resolve_rejects_implementation_and_options_not_at_resolve`, `test_close_outcome_merge_records_default_branch`, `test_close_outcome_pr_keep_records_current_branch`, `test_close_rejects_empty_evidence_missing_outcome_wrong_phase`, `test_drop_adds_out_of_scope`, `test_drop_superseded_by_rewires_open_dependents` (closed dependents unchanged, no Out of scope line, `status` shows `superseded-by`), `test_drop_superseded_by_cycle_rejects_whole_drop`, `test_block_self_and_cycle_rejected` (self, A→B→A), `test_upkeep_on_own_live_claim_keeps_claim` (`edit` and `block`), `test_upkeep_allowed_unclaimed_blocked_and_stale`, `test_upkeep_rejected_live_foreign_and_closed` (6 and 4), `test_resolve_and_drop_remove_proto_worktree` (register `.claude/worktrees/wayfinder-foo-1` with `git worktree add --detach`, gone after `resolve`; same for `drop`), `test_map_complete_guards` (open tickets / non-empty Not yet specified → 1), `test_map_complete_spares_other_map_worktree` (map `foo` leaves `wayfinder-foo-bar-1` in place), `test_handoff_map_removed_claim_not_found` (`rm -r` the map dir, `claim` → 3), and the cases moved here because their setup needs Stage D commands: `test_new_rejects_complete_map`, `test_base_ref_after_local_merge` (prints `main`), `test_base_ref_blocker_on_origin_only` (prints `origin/main`), `test_base_ref_diverged_rejects` (exit 1, names both blockers), `test_claim_closed` (4), `test_claim_phase_wrong_checkout` (spec in `.claude/worktrees/b/docs/s.md`, claim from the main root → exit 1, names that worktree, `assert_unchanged`; the same claim inside the worktree passes), `test_claim_phase_spec_missing`, `test_takeover_at_executing_plans_then_close` (the spec's exact sequence: kill agent, new session, `claim --phase superpowers:executing-plans` → takeover message, then `close --evidence f --outcome keep` → 0), `test_resolve_close_drop_reject_reserved_heading` (`resolve --answer` and `close --evidence` files containing `## Notes`, and `drop --reason $'x\n## Notes'`, each → 1 with `assert_unchanged`)

- [x] **Step 12: Run Stage D, expect FAIL; implement the remaining commands in `commands.sh`, `base-ref`'s closed-blocker path, and claim protocol step 8's `--phase` guard in `claim.sh` (missing `spec`/`plan` file, or owning toplevel ≠ claiming toplevel by `realpath`, naming the owning worktree; run among step 4's guard checks, before `claimed-by` is written); run, expect PASS; commit** — `wayfinder-ticket: lifecycle and upkeep`

- [x] **Step 13: Stage E tests (frontier, status, trailer).** Write `test_frontier_order_and_mine`, `test_frontier_mine_blocked`, `test_frontier_waiting_only_at_brainstorming`, `test_frontier_waiting_lists_all_branches`, `test_frontier_skips_live_foreign_includes_stale`, `test_status_fields` (incl. a ticket with two blockers and one with none), `test_trailer_per_harness` (each `<next>` under both harnesses, per the trailer table), `test_trailer_rejections` (unknown `<next>`; `wayfinder` given `slug#id`; a phase without a ref; no agent ancestor and no `WAYFINDER_HARNESS` → 1), `test_trailer_restart_when_spec_in_other_worktree`, `test_trailer_restart_impl_worktree_registered_elsewhere`, `test_trailer_no_restart_in_impl_worktree`, `test_trailer_cd`, `test_trailer_cd_remove_discard` (`-d` vs `-D`, branch read from the porcelain listing), `test_trailer_quotes_paths_with_spaces`

Harness detection uses the same agent walk as `claim`: a match on `.claude-unwrapped`/`claude` means Claude, `codex-raw`/`codex` means Codex.

- [x] **Step 14: Run Stage E, expect FAIL; implement `frontier`, `status` and `trailer.sh`; run, expect PASS; commit** — `wayfinder-ticket: frontier, status, trailer`

- [x] **Step 15: Add `pkgs.wayfinder-ticket` to `home.packages` in `home/common/packages.nix`, then run full verification**

Run: `nix build -L .#checks.aarch64-darwin.wayfinder-ticket && just check && nix build --no-link .#darwinConfigurations.burnedapple.system && nix path-info -r .#darwinConfigurations.burnedapple.system | grep -q wayfinder-ticket`
Expected: every case prints `ok`; lint and build succeed, and the system closure includes `wayfinder-ticket`.

- [x] **Step 16: Commit** — `wayfinder-ticket: add to home.packages`

- [ ] **Step 17: VM stop point (see HITL execution)** — on personal-nixos: `nix build -L .#checks.aarch64-linux.wayfinder-ticket`. Expected: every case prints `ok`.

---

### Task 3: Sandbox wrappers

Spec: Claim protocol step 1 (session id) and step 2 (Codex `--no-daemon`); Sandboxes (all); Testing → Sandbox VM test, `tests/codex.nix` `daemon_auto_start`.

**Files:**
- Create: `home/linux/bwrap-wrapper.nix`, a function `{lib, pkgs, sandboxShared}: {name, program, programArgs ? [], agentBinds}: <writeShellScriptBin>` (`sandboxShared` carries `sharedEnvNames`, `secretPreload` and `ghTokenPreload`, which both wrappers inline today). Keep `writeShellScriptBin`, as today: under `writeShellApplication`'s errexit, the existing `bind_rw() { [[ -e "$1" ]] && …; }` helpers return 1 on a missing path and would abort the launch. `agentBinds` is a Bash snippet of the agent-specific setup: `mkdir`/`bind_ro`/`bind_rw` calls, the `CLAUDE_SANDBOX`/`CODEX_SANDBOX` export, and any agent-only `args+=(…)` such as Claude's `--symlink /etc/static/claude-code /etc/claude-code`. The function owns `bind_ro`/`bind_rw`/`pass_env`, the `AGENT_SESSION_ID` generation, the workspace binds and the two-pass ordering.
- Create: `home/linux/sandbox-agents.nix`, a function `{lib, pkgs, ferrex ? true}: {claude = {agentBinds, programArgs}; codex = {…};}` holding the real per-agent binds and args (Codex `programArgs = ["--no-daemon"]`; today's `~/.ferrex` lines kept behind `ferrex`). Both `home/linux/sandboxed.nix` and the test import it.
- Create: `tests/sandbox-wrapper.nix` (Linux set, built with `tests/run-vm-test.nix`)
- Modify: `home/linux/sandboxed.nix` (Claude lines ~10–132 and Codex lines ~134–241 become two calls of the function; delete the `worktree_parent` binds at lines 72–75; `claudePlain` at 245 exports a fresh `AGENT_SESSION_ID`; `codexPlain` at 248 is left unchanged, because no config reaches it (the containers set `codex.enable = false`) and an edit there could not be verified; keep the TODO above it naming the missing `AGENT_SESSION_ID` export and `--no-daemon`)
- Modify: `home/darwin/sandboxed.nix` (`preHook` at line 16 generates and exports `AGENT_SESSION_ID` and appends the three `(subpath …)` rule sets; Codex `program` at line 115 becomes the `codex-no-daemon` wrapper given verbatim in the spec)
- Modify: `home/common/sandboxed.nix:130` (`"AGENT_SESSION_ID"` in `sharedEnvNames`)
- Modify: `home/common/codex/default.nix` (`codexConfig.features.daemon_auto_start = false`)
- Modify: `tests/codex.nix` (add `grep -q '^daemon_auto_start = false$'` under `[features]`; the test stays disabled until T7), `tests/default.nix` (Linux set: `sandbox-wrapper`)

**Interfaces:**
- Consumes: `wayfinder-ticket main-root` (T2), invoked as `${lib.getExe pkgs.wayfinder-ticket} main-root`. When it fails, the main-root bind is skipped.
- Produces: `home/linux/bwrap-wrapper.nix` and `home/linux/sandbox-agents.nix` (T7 passes `ferrex = config.custom.qdrant.enable`). Every sandboxed session has a fresh `AGENT_SESSION_ID`.

Generate the id with `cat /proc/sys/kernel/random/uuid` on Linux and `uuidgen` on Darwin. Inside the function, `bind_ro` also appends its path to `ro_paths`. Pass 2 re-emits each `ro_paths` entry unless its `realpath` equals or contains a workspace path. Workspace paths are the cwd, the toplevel, the common dir, the main root and `$(dirname <common-dir>)/.meta`, each bound only when it exists and lies outside the cwd. Every resolution (`git rev-parse …`, `wayfinder-ticket main-root`) is written as `if x=$(… 2>/dev/null); then …; fi`, in the bwrap function and in the Darwin `preHook` alike. A bare `x=$(…)` would abort the launch under errexit when run outside a repo or when `main-root` fails.

- [ ] **Step 1: Write `tests/sandbox-wrapper.nix`, add it to the Linux set in `tests/default.nix`, and `git add -N` it**

It instantiates `bwrap-wrapper.nix` twice, with the real Claude and Codex `{agentBinds, programArgs}` imported from `home/linux/sandbox-agents.nix` and only `program` replaced by the stub. That way the `--no-daemon` and `cwd HOME` cases check the shipped config and not a copy of it. The stub is a `writeShellScript` that runs the assertion script passed in `$STUB_CASE`, starts `sleep`, exports `WAYFINDER_AGENT_PID`/`WAYFINDER_AGENT_START` inside the sandbox and calls `wayfinder-ticket`. The test passes a stub `sandboxShared = { secretPreload = ""; ghTokenPreload = ""; sharedEnvNames = ["AGENT_SESSION_ID" "CLAUDE_SANDBOX" "CODEX_SANDBOX" "STUB_CASE"]; }`, since the real value only exists inside a Home Manager evaluation (`home/common/sandboxed.nix`). Under `--clearenv` a name missing from `sharedEnvNames` never reaches the program, so the stub must list `AGENT_SESSION_ID`, and `STUB_CASE` for the same reason (passing the case as an argument would collide with the `codex no-daemon` case's `$1`). Cases, one `subtest` each, all as a non-root `testuser`:
- `bare-clone subdir`: from `~/proj/main/src` (a bclone), `git status --porcelain` is empty, `docs/` is readable, `.meta/.envrc` resolves, and `<common>/wayfinder` is writable.
- `linked worktree outside Repos`: the same assertions from `/home/testuser/work/wt/src`.
- `contended claim`: stub A claims and then waits on a barrier file in a directory both sandboxes bind read-write (the cwd or under `~/Repos`; never `/tmp` or an unbound `$HOME` path, which are per-sandbox tmpfs). Stub B, launched while A is still alive, claims the same ticket and must exit 6. Only then does the test create the barrier so A exits. This matters because `--unshare-pid --die-with-parent` kills A's holder when A exits, so stubs run one after the other would never contend.
- `fresh session id`: a launch with `AGENT_SESSION_ID=parent` set sees a different, non-empty value.
- `codex no-daemon`: the Codex stub's `$1` is `--no-daemon`.
- `cwd inside bind_ro`: a fake `~/.config/nix-darwin` repo; writes to the cwd and `<common>/wayfinder` succeed.
- `nested ticket worktree`: from `<root>/.claude/worktrees/b`, `git -C <root> checkout main && git -C <root> merge b` succeeds.
- `cwd HOME`: `~/.config/git` is not writable, and `stat -c %U ~/.ssh/config` is `testuser`.

- [ ] **Step 2: Run on the Mac, expect FAIL** — `nix eval --raw .#checks.aarch64-linux.sandbox-wrapper.drvPath`. The error must be a missing-path error naming `home/linux/bwrap-wrapper.nix` (or `home/linux/sandbox-agents.nix`, depending on evaluation order); any other error (such as the attribute missing from `checks`) means Step 1's wiring is wrong.

- [ ] **Step 3: Implement `bwrap-wrapper.nix` and move both Linux wrappers onto it, putting every existing per-agent line in `sandbox-agents.nix` except the `worktree_parent` trio**

- [ ] **Step 4: Run on the Mac, expect the eval to succeed** — `nix eval --raw .#checks.aarch64-linux.sandbox-wrapper.drvPath` prints a `.drv` path. The VM test itself runs in Step 7.

- [ ] **Step 5: Darwin changes (`preHook` id + rules, `codex-no-daemon`), `sharedEnvNames`, `daemon_auto_start`, `tests/codex.nix` assertion**

Run on the Mac: `just check && nix build --no-link .#darwinConfigurations.burnedapple.system && nix eval --raw .#homeConfigurations.container.activationPackage.drvPath && nix eval --raw .#homeConfigurations.devcontainer.activationPackage.drvPath && nix eval --raw .#nixosConfigurations.personal-nixos.config.system.build.toplevel.drvPath`
Expected: all succeed. The container configs set `claude.sandbox = false` and `codex.enable = false`, so they reach `claudePlain` only; no config reaches `codexPlain`, and `nix flake check` does not evaluate `homeConfigurations`. Then `grep -cE 'AGENT_SESSION_ID=.*uuidgen' $(nix build --no-link --print-out-paths .#darwinConfigurations.burnedapple.config.home-manager.users.vaporif.custom.sandboxedPackages.claude)/bin/claude-sandboxed` prints ≥ 1.

- [ ] **Step 6: Commit** — `sandbox: common-dir/main-root binds, AGENT_SESSION_ID, codex --no-daemon`

- [ ] **Step 7: VM stop point (see HITL execution)** — on personal-nixos: `nix build -L .#checks.aarch64-linux.sandbox-wrapper && nix build --no-link .#nixosConfigurations.personal-nixos.config.system.build.toplevel`. Expected: every subtest passes and the toplevel builds.

---

### Task 4: Install the mattpocock skill set, glossary and local tracker patches; create `tests/llm-skills.nix`

Spec: Install the full mattpocock skill set; Tracker (Cons bullet: what is replaced or repointed; Backend selection); Handoff and memory (first paragraph); Glossary; Patch layout (mattpocock list); Testing → `tests/llm-skills.nix` (build `mkHm` from `tests/codex.nix`: `extraSpecialArgs = {inherit inputs;}`, its `home.*` and `custom.user`/`system`/`configPath` block, plus the spec's enables and `sandboxedPackages` stubs).

**Files:**
- Modify: `home/common/llm/skills.nix`: `patchedMattpocockSkills` gains a `prePatch` that copies `skills/engineering/codebase-design/{SKILL.md→CODEBASE-DESIGN.md,DEEPENING.md,DESIGN-IT-TWICE.md}` into `skills/engineering/improve-codebase-architecture/`, and its patches list adds `setup-matt-pocock-skills`, `domain-modeling` and `handoff`. Add `kind = "directory"` entries for `wayfinder`, `setup-matt-pocock-skills`, `prototype`, `domain-modeling` and `research` from `skills/engineering/`, and `grilling` and `handoff` from `skills/productivity/`. Verify each path first with `p=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.mattpocock-skills.outPath' 2>/dev/null); ls -d "$p"/skills/*/*/` (the flake exposes no `inputs` output); if upstream lays things out differently, follow upstream and note it in the commit.
- Create: `patches/mattpocock/{setup-matt-pocock-skills,domain-modeling,handoff}.patch`
- Modify: `patches/mattpocock/improve-codebase-architecture.patch` (the six `codebase-design` calls, the copied files' `[SKILL.md](SKILL.md)` links, glossary references → `docs/arch/glossary.md`, and a context hunk that removes the YAML frontmatter (`name: codebase-design`, `description:`) from the copied `CODEBASE-DESIGN.md`, since it is now a reference file and no longer a skill)
- Create: `tests/llm-skills.nix`; modify `tests/default.nix` (common set)

**Interfaces:**
- Consumes: `custom.llm.superpowersPackage` (T1, only so `claude/home.nix` evaluates), `pkgs.wayfinder-ticket` (T2), `custom.sandboxedPackages` stubs.
- Produces: in `tests/llm-skills.nix`, the shape every later test extension follows: a function `mkHm = {qdrant ? false}: home-manager.lib.homeManagerConfiguration {…}` over the module list the spec gives (`modules/options.nix`, `home/common/llm`, `home/common/codex`, `home/common/packages.nix`, `home/common/mcp.nix`, `claude/home.nix`, `home/common/lspmux.nix`), plus a `skillFiles` list and a `runCommand` whose script has one block per task. Each later task appends its skills to `skillFiles` and its greps to the script. The wayfinder patch slot is filled by T8.
- Produces: in the setup patch, `issue-tracker-local.md` contains a `## Wayfinding operations` section that T8 refers to by name. The `wayfinder.backend` instruction in setup `SKILL.md` runs `git config wayfinder.backend <local|github|gitlab>` right after the tracker doc is written.

`issue-tracker-local.md` gets replaced wholesale. Write its new contents as a full-file replacement hunk against upstream's text, so that any upstream edit to the file fails the patch. Its contents: a short header naming the map location and `wayfinder-ticket`, then a rewritten "Wayfinding operations" that maps each upstream operation to the matching `wayfinder-ticket` command. Drop `.scratch/` Conventions, publish and fetch.

- [ ] **Step 1: Write `tests/llm-skills.nix` (add it to the common set in `tests/default.nix` and `git add -N` it) asserting the T4 skills (with `SKILL.md`) under both `.claude/skills/<n>/` and `.codex/skills/<n>/`, that `wayfinder-ticket` is in `home.packages` (`lib.any (p: (p.pname or p.name or "") == "wayfinder-ticket") hm.config.home.packages`), that `grep -r '\.scratch/'` over the built setup skill is empty, that `grep -rE 'CONTEXT(-MAP)?\.md'` over setup, domain-modeling and improve-codebase-architecture is empty, and that `grep -r codebase-design` over improve-codebase-architecture is empty**

- [ ] **Step 2: Run, expect FAIL** — `nix build -L .#checks.aarch64-darwin.llm-skills`

- [ ] **Step 3: Write the four patches and the `skills.nix` changes. Generate each patch by editing a writable copy of the pinned tree and running `diff -ru` against the pristine one, with paths rewritten to `a/skills/...` / `b/skills/...` (any single leading component works, since `applyPatches` applies with `-p1`). For `improve-codebase-architecture.patch` the baseline is upstream plus the `prePatch` copy, not pristine upstream: run the exact `prePatch` commands from `skills.nix` in `base/`, copy `base/` to `work/`, make every edit (T1's existing hunks and the new ones) in `work/`, and diff `base` against `work`. Check that no patch contains a `--- /dev/null` hunk**

- [ ] **Step 4: Run, expect PASS; then `just check && nix build --no-link .#darwinConfigurations.burnedapple.system`**

- [ ] **Step 5: Commit** — `llm: install wayfinder's mattpocock skills; glossary + local tracker patches`

---

### Task 5: Vendor `dissent-review`

Spec: Review gate (Changes from his copy; bundle definitions; Map mode slot filling).

**Files:**
- Create: `llm/shared/skills/dissent-review/{SKILL.md,dissent-reviewer-prompt.md,adjudicator-prompt.md}`, copied from zvolin at the pinned commit (`modules/programs/ai-skills/dissent-review/files/`), then edited
- Modify: `home/common/llm/skills.nix` (`dissent-review = { source = ../../../llm/shared/skills/dissent-review; kind = "directory"; };`), `tests/llm-skills.nix`

**Interfaces:**
- Produces: a skill named `dissent-review` that takes a `path` to the artifact. In map mode the caller fills `DESTINATION`, `CLOSED_IDS`, `TRACKER_BINDINGS`, `REVIEW_SCOPE` and `CHART_STATE`. Its result is a list of findings labelled `apply` or `ask`. T8 and T9 call it by these names.

- [ ] **Step 1: Extend `tests/llm-skills.nix`: all three files exist under both skill roots; `SKILL.md` contains `spawn_agent`, `general-purpose` and `cap 3`, and contains neither `humanizer` nor `conformance lint`**

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Copy the files with `curl -fsSL https://raw.githubusercontent.com/zvolin/nixos-config/27d4369c3512455d8a1ce83bd90bebc77fe890bd/<path>` (no auth needed, unlike `gh api`, which fails when `GH_TOKEN` is stale; same pattern as T9), then apply the three listed edits**

- [ ] **Step 4: Run, expect PASS; `just check`; commit** — `llm: vendor dissent-review`

---

### Task 6: Vendor `research-options`

Spec: Research (the bullet list of changes, incl. model mapping and Codex dispatch).

**Files:**
- Create: `llm/shared/skills/research-options/{SKILL.md,reviewer-prompt.md,landscape-scout-prompt.md,coverage-reviewer-prompt.md,validation-reviewer-prompt.md}` from zvolin's `modules/programs/ai-skills/research/files/` (the `agents/*.md` files become `*-prompt.md` with their frontmatter removed; the model each declared moves into the dispatch line in `SKILL.md`)
- Modify: `home/common/llm/skills.nix`, `tests/llm-skills.nix`

**Interfaces:**
- Consumes: `wayfinder-ticket claim|attach|advance|trailer` (T2).
- Produces: a skill `research-options` taking `<slug>#<id>` (ticket mode) or a free-text question. In ticket mode it ends after `advance <ref> research wayfinder:resolve` and prints no trailer, except when it was invoked directly, in which case it ends with `trailer wayfinder <slug>`. "Invoked from wayfinder" is signalled by the argument `from=wayfinder`, which T8's patch passes. The spec leaves that signal open. An explicit argument was chosen over guessing from context because it is checkable after compaction, the same reasoning as SDD's `ticket=none`.

- [ ] **Step 1: Extend the test: all five files under both roots; `SKILL.md` has `name: research-options`, `tavily`, `wayfinder-ticket attach`, `advance`, `from=wayfinder`, `docs/research/`, `model: haiku`/`opus` dispatch lines and `spawn_agent`; no file in the directory contains `tools: WebSearch` or `effort:`**

- [ ] **Step 2: Run, expect FAIL; copy (same `curl` command as T5 Step 3) and edit per the spec; run, expect PASS; `just check`; commit** — `llm: vendor research-options`

---

### Task 7: Ferrex gating; re-enable `tests/codex.nix`

Spec: Handoff and memory (second paragraph onward); Testing → `tests/llm-skills.nix` second evaluation, re-enabled `tests/codex.nix`.

**Files:**
- Modify: `claude/overrides/CLAUDE.md`: move the line-34 bullet and the whole "During Long Sessions" section (lines 36–~39) into "Memory System" (line 50), and change line 44 to `- Run \`/docs\` to update documentation (CLAUDE.md, auto memory)`.
- Split it into `claude/overrides/CLAUDE.md` (base) and `claude/overrides/CLAUDE-memory.md` (the "Memory System" section, now carrying "`/docs` also syncs to ferrex").
- Modify: `claude/home/rules.nix:22` → `".claude/CLAUDE.md".text = builtins.readFile ../overrides/CLAUDE.md + lib.optionalString config.custom.qdrant.enable (builtins.readFile ../overrides/CLAUDE-memory.md);`
- Modify: `home/common/llm/commands.nix` per the spec. Split `llm/shared/commands/docs.md` into `docs-head.md`, `docs-ferrex.md` (the `**Ferrex**` block, line 22 onward to just before "Present a summary") and `docs-tail.md`, and delete `docs.md`.
- Modify: `claude/home.nix` (add `options` to the arguments; the `allowedTools` filter, verbatim from the spec)
- Modify: `home/darwin/sandboxed.nix` (the two `"$HOME/.ferrex"` entries in the `cli.rw` lists of the Claude and Codex sandboxes, gated with `lib.optionals config.custom.qdrant.enable`) and `home/linux/sandboxed.nix` (passes `ferrex = config.custom.qdrant.enable` to `sandbox-agents.nix`)
- Modify: `tests/codex.nix` (the test runs with qdrant off, so `grep -q '^\[mcp_servers.ferrex\]$'` becomes `! grep -q '^\[mcp_servers.ferrex\]$'`), `tests/default.nix` (uncomment `codex` and drop the TODO), `tests/llm-skills.nix` (`mkHm {qdrant = true;}` evaluation)

- [ ] **Step 1: Extend `tests/llm-skills.nix`. With qdrant off: `ferrex` is absent from the generated `.claude/CLAUDE.md`, from every installed command file and from the `settings.json` permissions; the Codex `config.toml` has no `[mcp_servers.ferrex]` but has `[mcp_servers.context7]`; none of `checkpoint`/`forget`/`recall`/`reflect`/`remember` is installed. With qdrant on: `.claude/CLAUDE.md` contains `## Memory System`, all five commands are present, the allow list contains an `mcp__ferrex__` entry, and `assert hm.config.custom.codexMcpServers ? ferrex` holds (evaluated, not built)**

- [ ] **Step 2: Run, expect FAIL** — `nix build -L .#checks.aarch64-darwin.llm-skills`

- [ ] **Step 3: Implement the gating, then re-enable `codex` in `tests/default.nix`**

- [ ] **Step 4: Run, expect PASS** — `nix build -L .#checks.aarch64-darwin.llm-skills .#checks.aarch64-darwin.codex && just check && nix build --no-link .#darwinConfigurations.burnedapple.system`. Then, on the Mac, evaluate both NixOS hosts (`nix eval --raw .#nixosConfigurations.personal-nixos.config.system.build.toplevel.drvPath && nix eval --raw .#nixosConfigurations.work-nixos.config.system.build.toplevel.drvPath`) and both standalone container configs (`nix eval --raw .#homeConfigurations.container.activationPackage.drvPath && nix eval --raw .#homeConfigurations.devcontainer.activationPackage.drvPath`, the only qdrant-off standalone Home Manager path), since `home/linux/sandboxed.nix` changed and the VM test does not evaluate it.

- [ ] **Step 5: Commit** — `gate ferrex prompt surface on qdrant.enable; re-enable codex test`

- [ ] **Step 6: VM stop point (see HITL execution)** — on personal-nixos: `nix build --no-link .#nixosConfigurations.personal-nixos.config.system.build.toplevel`. Expected: builds. This is the first build of the ferrex-off wrapper (`qdrant.enable` defaults to false); the `sandbox-wrapper` test imports `sandbox-agents.nix` with the default `ferrex = true`, so it would not exercise T7's change.

---

### Task 8: Wayfinder patch [HITL]

Spec: Invocation; Map model; Ticket model ("When implementation tickets are created", research findings, decision tickets and the glossary, prototype override); `wayfinder-ticket` script (Map upkeep, Pending upkeep, History is never reopened, the resume and routing paragraphs, research subtypes, the 5-step session order, the charting-session order, the map-state check); Review gate (map mode, "ask" for closed tickets and Decisions so far); "Asking the user" rules.

**Files:**
- Create: `patches/mattpocock/wayfinder.patch`
- Modify: `home/common/llm/skills.nix` (append the patch), `tests/llm-skills.nix`

**Interfaces:**
- Consumes: the CLI contract (T2) and its exit codes. Wayfinder treats exits 4, 6 and 7 from `claim` as "lost race, take the next frontier entry" (spec, session order step 2) and any other non-zero exit as "print and stop". Upkeep calls (`edit`/`drop`/`block`/`unblock`/`map-edit`): exit 6 → write a `pending:` upkeep line; exit 4 → history rules (never reopen); exit 1 from the post-resolve `block <ticket> <new id>` → cycle: Notes line on both tickets and tell the user; anything else → print and stop. It also consumes `dissent-review` (T5), `research-options <ref> from=wayfinder` (T6), and the `research`, `grilling`, `prototype` and `domain-modeling` skills (T4).
- Produces: wayfinder prose that routes implementation tickets with `wayfinder-ticket trailer <phase without superpowers:> <ref>` and never runs a phase itself.

Write the patch section by section against upstream's `SKILL.md` (and any reference files it reads), so that each spec paragraph maps to a hunk. Keep the ticket-mode text in its own sections, as the spec's Risks row "Prompt bloat" requires: mostly "run `wayfinder-ticket …`". Order of new or rewritten sections: Invocation → Tracker access → Ticket types → Session order (map entry, steps 1–5) → Charting session → Upkeep and pending upkeep → Corrections → Prototype tickets → Research tickets → Review (dissent) → Asking the user. Text the prose passes to `--answer`, `--evidence`, `--question`, `--destination`, `--reason`, `edit` and `map-edit` uses `###` or deeper headings, since a reserved `## ` heading is rejected. Refer to the tool in prose as `` `wayfinder-ticket` `` (backticked, no trailing word) so the Step 1 allowlist check sees only invocations. Every `wayfinder-ticket` invocation in the prose must use a command and flags that exist in the T2 contract. The test below checks command names mechanically; flags are checked against the contract in the Step 5 human read.

- [ ] **Step 1: Extend `tests/llm-skills.nix`: the built `wayfinder/` contains no `.scratch/` and no `research/<` branch instruction; every line matching `wayfinder-ticket [a-z-]+` names a command from the spec's `wayfinder-ticket` command table (extract with `grep -oE 'wayfinder-ticket [a-z-]+' | sort -u` and compare with an allowlist of those names, imported from `tests/wayfinder-commands.nix`, which T2 created); it contains `trailer wayfinder`, `pending:`, `.claude/worktrees/wayfinder-`, `from=wayfinder`, `dissent-review` and `## Asking the user`**

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Write the patch and register it in `skills.nix`**

- [ ] **Step 4: Run, expect PASS; `just check`**

- [ ] **Step 5: Human read.** Show the user the rendered `wayfinder/SKILL.md` diff (`diff -ru <upstream>/skills/engineering/wayfinder <built>/wayfinder`) and ask for approval in the "Asking the user" format. Apply any change requests and repeat Step 4.

- [ ] **Step 6: Commit** — `wayfinder: drive tracker through wayfinder-ticket`

---

### Task 9: Superpowers ticket mode, review gate and finishing fixes [HITL]

Spec: Goal (the five deliberate changes); Context (the executing-plans Inline-Degraded paragraph); Claim protocol step 8 (worktree creation, `base-ref`, `EnterWorktree path=`, the rules/agents symlink fallback if T13 found it necessary); Phase handoff (the entire section and table); Review gate; Patch layout (finishing paragraph); "Asking the user" rules.

**Files:**
- Create: `patches/superpowers/finishing-a-development-branch.patch` (T1 does not create it, because today's patch doesn't touch that skill), and register it in `home/common/llm/superpowers.nix`
- Modify: `patches/superpowers/brainstorming.patch` (incl. `spec-document-reviewer-prompt.md`), `writing-plans.patch` (incl. a new-file hunk for `plan-document-reviewer-prompt.md`, restored from upstream v6.4.1 with `curl -fsSL https://raw.githubusercontent.com/obra/superpowers/v6.4.1/skills/writing-plans/plan-document-reviewer-prompt.md` (the flake input is a tarball with no `.git`) and then edited; a new-file hunk is acceptable here because upstream deleted the file and there is nothing to drift from), `executing-plans.patch`, `subagent-driven-development.patch` (incl. `implementer-prompt.md` only if a ticket-mode line belongs there)
- Unchanged: `requesting-code-review.patch` (T1's path rewrite only; no spec change touches it)
- Create: `tests/superpowers-patches.nix` (common set), taking `{pkgs, home-manager, inputs}`: it evaluates a minimal `home-manager.lib.homeManagerConfiguration` over `modules/options.nix` and `home/common/llm` (`extraSpecialArgs = {inherit inputs;}`) and runs a `runCommand` with structural greps over its `config.custom.llm.superpowersPackage`. It does not extend `tests/llm-skills.nix`, which T6 edits in the same batch. Modify `tests/default.nix` (`superpowers-patches = import ./superpowers-patches.nix {inherit pkgs home-manager inputs;};`)

**Interfaces:**
- Consumes: the CLI contract and exit codes (T2): on a `claim --phase` exit 5, read the actual phase from the `phase:` line of `wayfinder-ticket status <ref>`. If it is a `superpowers:*` phase, print `trailer <phase without superpowers:> <ref>` and stop. Otherwise print the rejection reason and stop. exit 4/3 on a handoff-block reference → warn and run as a non-ticket run; `base-ref` exit 1 → local and origin diverged: ask the user (update local / base on origin / wait) and record the choice in Notes; anything else → print and stop. Also consumes `dissent-review` (T5), and T13's findings recorded in `docs/ai-workflow.md` ("Sandbox check results"): whether Claude needs a restart line, and whether the symlink fallback is needed.
- Text the patched prose passes to `close --evidence`, `drop --reason` and `new --question` uses `###` or deeper headings, since a reserved `## ` heading is rejected (exit 1).
- Produces: `executing-plans` → SDD argument `ticket=<ref>` or `ticket=none`; SDD → finishing argument `ticket=<ref>` or `ticket=none`; the plan and spec block `## Wayfinder ticket handoff` with the single line `Wayfinder ticket: <slug>#<id>`.

Each ticket-mode addition is a separate `## Ticket mode` section near the top of its skill, triggered by a reference argument. Non-ticket text changes only where the spec lists a deliberate change: review gate cap 3 and the dissent step, Asking the user, the Inline-Degraded OR rule (gate bullets, the two Polish lines, the rationalization row "and accepted"), and the three finishing fixes.

- [ ] **Step 1: Write `tests/superpowers-patches.nix` with these greps on the built tree:**
  - `brainstorming/SKILL.md` and `writing-plans/SKILL.md` contain `dissent-review`, the loop cap `3` (and no `10 iterations`), `## Asking the user` and `Wayfinder ticket handoff`.
  - brainstorming, writing-plans, executing-plans, subagent-driven-development and finishing-a-development-branch each contain `## Ticket mode`.
  - brainstorming contains `base-ref`, `merged`, `Stacked on:`, `waiting on merge:`, `EnterWorktree path=`, `-impl` and `new <slug> prototype`.
  - writing-plans contains `superpowers:executing-plans plan=` and `writing-plans/plan-document-reviewer-prompt.md` exists.
  - executing-plans contains `ticket=none`, `ticket needs a subagent tool` and `## Asking the user`, and the file no longer contains `You are inline because no subagent tool exists` or `If a subagent tool is in fact available, you should not be in this skill` (the Post-Implementation Polish lines the OR rule rewrites).
  - SDD contains `ticket=`, `--outcome`, `--remove`, `--superseded-by` and `main-root`.
  - finishing contains `wayfinder-ticket main-root`, `--ff-only`, `@{u}` and `Stacked on:`, and no longer contains `git rev-parse --git-common-dir)/..`.
  - Every `wayfinder-ticket <cmd>` across the tree is in the allowlist imported from `tests/wayfinder-commands.nix` (same check as T8).

- [ ] **Step 2: Run, expect FAIL** — `nix build -L .#checks.aarch64-darwin.superpowers-patches`

- [ ] **Step 3: Update `brainstorming.patch` and `writing-plans.patch` (review gate, Asking the user, ticket mode, plan approval, restored reviewer prompt)**

- [ ] **Step 4: Update `executing-plans.patch` (ticket mode, `ticket=` routing, Inline-Degraded OR rule, Asking the user) and `subagent-driven-development.patch` (handoff-block fallback, close/drop/re-file, trailers)**

- [ ] **Step 5: Update `finishing-a-development-branch.patch` (all-mode fixes, ticket-mode ownership, deferred removal, the Claude PR fallback, the stacked-branch and default-branch gates)**

- [ ] **Step 6: Run, expect PASS; `just check && nix build --no-link .#darwinConfigurations.burnedapple.system`**

- [ ] **Step 7: Human read.** Show the user `diff -ru` of upstream vs built for each of the six skills (brainstorming, writing-plans, executing-plans, subagent-driven-development, requesting-code-review (path-only, unchanged since T1), finishing-a-development-branch), one skill at a time, and get approval in the "Asking the user" format. Apply change requests and repeat Step 6.

- [ ] **Step 8: Commit** — `superpowers: ticket mode, dissent gate, finishing fixes`

---

### Task 10: GitHub/GitLab backends

Spec: Backends (the table and the paragraph after it); `merged` forge fallback; `trailer` releasing on remote backends; `wayfinder-ticket` `runtimeInputs` paragraph (`glab` on `PATH`); Testing → T10 remote cases.

**Files:**
- Create: `pkgs/wayfinder-ticket/backend-github.sh`, `pkgs/wayfinder-ticket/backend-gitlab.sh` (added to the concat list ahead of `main.sh`), and `tests/wayfinder-ticket/remote.sh`, `tests/wayfinder-ticket/stubs/{gh,glab}`. The stubs are Bash scripts that implement the subset of `gh`/`glab` the backends call, keeping issue state as JSON files under `$STUB_STATE`. `tests/wayfinder-ticket.nix` builds each one with `writeShellApplication` (`text = builtins.readFile ./wayfinder-ticket/stubs/gh`), so they are shellchecked like the shipped code.
- Modify: `pkgs/wayfinder-ticket.nix` (concat list gains `backend-github.sh`, `backend-gitlab.sh` before `main.sh`), `pkgs/wayfinder-ticket/commands.sh` (backend dispatch), `pkgs/wayfinder-ticket/git.sh` (`merged` forge fallback; `base-ref`'s forge-hit rule), `pkgs/wayfinder-ticket/claim.sh` (dispatch for `claim`/`release`; `release --force` remote-only), `pkgs/wayfinder-ticket/trailer.sh` (release before a restart line on remote backends), `tests/wayfinder-ticket.nix` (a second `WT_GH` built with `pkgs.wayfinder-ticket.override { gh = ghStub; }`; the `glab` stub prepended to `PATH` for GitLab cases), `patches/mattpocock/setup-matt-pocock-skills.patch` (the "Wayfinding operations" sections of `issue-tracker-{github,gitlab}.md` → "use `wayfinder-ticket`")

**Interfaces:**
- Consumes: the `local_<cmd>` functions and helpers from T2. Remote backends implement `github_<cmd>`/`gitlab_<cmd>` with the same output formats and exit codes. The one exception is `status`'s `claim` field, which can only be `held` or `none` there. They fetch the body, apply `section_get`/`section_set` to it and write it back, so the Sections rules hold unchanged; fallback lines (`Part of #<map>`, `Blocked by: #<id>…`) are visible plain lines at the top of the ticket body, after any leading `<!-- … -->` metadata block and before the first reserved `## ` heading, never inside a comment or a section. Each backend's single body-fetch helper strips `\r` (see Sections).
- Produces: no new commands. `release --force` is accepted only on remote backends; on local it is a usage error.

Write down which `gh`/`glab` subcommands the backend uses, near the top of each backend file. The stubs implement exactly that list and fail loudly on anything else, so drift between the two shows up as a test failure.

- [ ] **Step 1: Write `remote.sh` cases, each run for both backends unless noted:** `test_remote_map_new_and_resolve_slug`, `test_remote_ticket_membership_check` (a ticket from another map → 3), `test_remote_labels_no_scoped` (GitLab: no `::`), `test_remote_claim_advisory_latest_comment_wins`, `test_remote_release_force`, `test_remote_attach_size_limit`, `test_remote_advance_records_branch_path_from_file_worktree` (cwd in the main root, spec in `.claude/worktrees/b/docs/s.md` → `b:docs/s.md`), `test_remote_advance_rejects_detached_and_foreign_repo`, `test_remote_claim_brainstorming_rejects_detached_head`, `test_remote_claim_phase_wrong_checkout`, `test_remote_trailer_restart_releases_then_new_session_claims` (the spec's flow ending in `claim --phase superpowers:writing-plans` → 0; stdout is exactly two lines and stderr is `wayfinder-ticket: released <ref>`), `test_remote_trailer_cd_releases_nothing`, `test_merged_forge_fallback` (squash-merged → `merged forge`), `test_gitlab_without_glab_fails_clearly` (exact message from the spec), `test_remote_map_edit_expect_and_reserved_heading` (`show-map` hashes match the local definition, a stale `--expect` → 1, a `## Notes` line in the content → 1; the stub's `Part of #<map>` line is outside any `<!-- -->` block, before the first `## ` heading, and survives an `edit` round trip; the map's leading `<!-- wayfinder: … -->` block survives `map-edit`), `test_remote_crlf_body_sections_and_hash` (a stub body stored with `\r\n`: `section_get` finds the sections, `show-map` hashes equal those of the LF equivalent, a `## Notes` line in the content is still rejected, and the written-back body has no `\r`)

- [ ] **Step 2: Run, expect FAIL** — `nix build -L .#checks.aarch64-darwin.wayfinder-ticket`

- [ ] **Step 3: Implement both backends and the dispatch; local cases must stay green**

- [ ] **Step 4: Rewrite the setup patch's GitHub/GitLab "Wayfinding operations" and rebuild `llm-skills`**

- [ ] **Step 5: Run, expect PASS** — `nix build -L .#checks.aarch64-darwin.wayfinder-ticket .#checks.aarch64-darwin.llm-skills && just check`

- [ ] **Step 6: Commit** — `wayfinder-ticket: github and gitlab backends`

- [ ] **Step 7: VM stop point (see HITL execution)** — on personal-nixos: `nix build -L .#checks.aarch64-linux.wayfinder-ticket`. Expected: every case prints `ok`. This is the first Linux run of T10's changes and of any T13 fix to `claim.sh` or `trailer.sh`, which would otherwise wait for T12. If T13 changed `home/linux/bwrap-wrapper.nix`, also run `nix build -L .#checks.aarch64-linux.sandbox-wrapper` here.

---

### Task 11: Codex parity

Spec: Codex parity (second paragraph onward).

**Files:**
- Modify: `home/common/codex/default.nix` (the `home.file =` attrset inside `config = lib.mkIf cfg.codex.enable`, next to the `toSkillFile`/`toAgentFile` merges, gains `lib.mapAttrs'` over the directory names in `builtins.readDir "${inputs.superpowers}/skills"`, each `.codex/skills/<name>` with `source = "${config.custom.llm.superpowersPackage}/skills/<name>"`. The names come from the unpatched input, a plain source path, so evaluation never builds the patched tree. Reading the derivation instead would be import-from-derivation and would need an aarch64-linux build while the Mac evaluates the NixOS configs. Add `inputs` to the module's arguments.)
- Modify: `claude/home/plugins.nix` only if it still has a leftover reference
- Modify: `home/common/llm/default.nix` only if T1 left it inconsistent (owned per the spec's file order)
- Modify: `tests/llm-skills.nix`

**Interfaces:**
- Consumes: `custom.llm.superpowersPackage` (T1, patched by T9).

- [ ] **Step 1: Extend the test: the patched tree's `skills/` directory names equal the unpatched input's (patching adds no skill directory); for `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development` and `finishing-a-development-branch`, `.codex/skills/<n>/SKILL.md` exists and contains `## Ticket mode`; `.codex/skills/using-git-worktrees/SKILL.md` and `.codex/skills/requesting-code-review/SKILL.md` exist; `.claude/skills/brainstorming` does not exist (no second copy)**

- [ ] **Step 2: Run, expect FAIL; implement; run, expect PASS; `just check && nix build --no-link .#darwinConfigurations.burnedapple.system`; commit** — `codex: install patched superpowers skills`

---

### Task 12: End-to-end verification and docs [HITL]

Spec: Testing → Manual checklist; Success criteria; Sandboxes (Codex without the bypass flag is documented, not changed).

**Files:**
- Modify: `docs/ai-workflow.md` ("Testing → Manual, once per upstream bump": the checklist as checkboxes; the status lines), `CLAUDE.md` (Architecture tree: `pkgs/wayfinder-ticket*`, `patches/{superpowers,mattpocock}/`; Key Patterns: a `wayfinder-ticket` bullet, a sandbox `AGENT_SESSION_ID`/main-root bind bullet, and the ferrex gate), `README.md` (update the existing `### Workflow` paragraph to mention `/wayfinder`; do not add a new one)
- Modify, only if the check fails: `claude/overrides/CLAUDE.md` (a single line allowing `EnterWorktree path=` for ticket-mode worktrees)

- [ ] **Step 0: Merge the spec's Testing → Manual checklist "Adds:" items into `docs/ai-workflow.md` ("Manual, once per upstream bump") and turn every item into a checkbox. Items that need a real GitHub/GitLab repo (the forge-fallback case) are marked skipped when no throwaway forge repo is at hand**

- [ ] **Step 1: `just switch` on the Mac and on both NixOS VMs; `nix flake check` on the Mac and on one VM. Expected: all succeed**

- [ ] **Step 2: Walk the spec's manual checklist item by item in `docs/ai-workflow.md#testing` (Codex items are marked skipped: Codex is disabled on every host), ticking each one with the date, machine, harness and layout. List any failure under the checklist and report it to the user; don't fix in place**

- [ ] **Step 3: Check that ticket-mode brainstorming on Claude calls `EnterWorktree path=`; only if the model refuses, add the override line and re-test**

- [ ] **Step 4: Update `CLAUDE.md`, `README.md` and the status in `docs/ai-workflow.md`; `just check`; commit** — `docs: wayfinder workflow`

---

### Task 13: Real-sandbox claim check [HITL]

Spec: Claim protocol steps 2, 5, 6, 8; Risks rows 1–2; the T13 row of the dependency table.

**Files:**
- Modify: `docs/ai-workflow.md` (a new "Sandbox check results" subsection under Testing: one row per check per machine, with result and date). T9 reads this.
- Modify, only on failure: T2 files (`pkgs/wayfinder-ticket/claim.sh`, `trailer.sh`), T3 files (`home/darwin/sandboxed.nix` for a narrow `process-info` allowance, `home/linux/bwrap-wrapper.nix`), each fix with a regression case in `tests/wayfinder-ticket/local.sh` or `tests/sandbox-wrapper.nix` when it can be expressed there

Setup on each machine: `just switch`, then in a scratch repo `wayfinder-ticket map-new t13 "T13" --destination <(echo probe)` and `wayfinder-ticket new t13 task probe`. For Step 4, also create `<main>/.claude/rules/t13.md` and `<main>/.claude/agents/t13-probe.md`, each with a distinctive marker, and leave both untracked (add them to `.git/info/exclude`): committed files would be checked out into the worktree and pass the check trivially, while real rules and agents are untracked direnv symlinks.

**Codex is out of scope here.** `custom.codex.enable` is `false` on every host and stays that way, so there is no `o` to run. Codex behaviour is covered only by the Nix tests: `tests/codex.nix` (`daemon_auto_start = false`), `tests/llm-skills.nix` (`.codex/skills`) and the sandbox VM test's `codex no-daemon` case. The Darwin `codex-no-daemon` wrapper and Codex across `/clear` stay unverified on real hosts; record that in the results.

- [ ] **Step 1: Process discovery.** In `a` (Claude) on the Mac and the NixOS VM, ask the agent to run `wayfinder-ticket claim t13#1` and then `wayfinder-ticket status t13#1`. Expected: exit 0, `claim: live`, and the tool call returns at once (holder detached).

- [ ] **Step 2: Interrupt and exit.** Press Esc during a later tool call, then check `status` again. Expected: still `live`. Quit the agent and run `status` from a plain shell. Expected: `stale` within 10 s.

- [ ] **Step 3: Across `/clear`.** Relaunch the agent and claim `t13#1`. Expected: `took over stale claim` (the Step 2 leftover). `/clear`, then claim again. Expected: exit 0, no takeover message, `claimed-by` unchanged in `status` (the same `.claude-unwrapped` process).

- [ ] **Step 4: `EnterWorktree`.** On Claude, `git worktree add -b t13-impl <root>/.claude/worktrees/t13-impl main`, ask the agent to `EnterWorktree path=<that dir>`, then `/clear` and ask it for `pwd`. Record whether the cwd survived. If it did not, change `trailer.sh` so Claude also gets the restart line (with a test) and note it for T9. Control first: in a session started in the main worktree, confirm the `t13.md` rule and `t13-probe` agent are visible; if they are not, record "inconclusive", not "fallback needed". Then, in the `EnterWorktree` session, check that both are visible. If not, record "symlink fallback needed" for T9.

- [ ] **Step 5: Launches outside a repo.** Launch `a` from `/tmp` (outside any repo) on the Mac and on the VM. Expected: it starts.

- [ ] **Step 6: Record results and commit** — `docs: T13 sandbox check results` (plus any fix commits, each `fix(t13): <what>`)
