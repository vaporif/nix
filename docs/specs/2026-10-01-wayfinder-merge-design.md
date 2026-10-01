# Wayfinder + superpowers merge: design

User-facing description of the resulting flow: [docs/ai-workflow.md](../ai-workflow.md). This spec
covers how to build it.

## Goal

Port zvolin's wayfinder-driven workflow into this repo and merge it with the existing superpowers
customizations. Wayfinder becomes the top-level driver for multi-session efforts; superpowers stays
the build pipeline it drives. Calling a superpowers skill directly, without a ticket, keeps today's
behaviour except for five deliberate changes: the new review gate, the "Asking the user" rules,
`subagent-driven-development` picking up a ticket from a plan's handoff block (see Phase handoff),
settling the `executing-plans` Inline-Degraded gate (T9; today's patch contradicts itself), and three
`finishing-a-development-branch` fixes (see Patch layout): its main root comes from
`wayfinder-ticket main-root`, since upstream's expression fails in `git bclone` repos; Discard of
a host-owned worktree stops before `git branch -D`, which upstream runs and which always fails there;
and Merge's `git pull` is skipped when there is no upstream or it can't fast-forward.

Success means:

- `/wayfinder` charts a map, works one ticket per session, and prints a copyable `/clear` trailer.
- Implementation tickets move through brainstorming → writing-plans → executing-plans with the phase
  recorded on the ticket and a trailer between phases (except brainstorming → writing-plans on the
  would-be Bounded path, which continues in the same session when the session is already in the
  ticket's worktree).
- **Local backend:** two sessions working one map never claim the same ticket, and a crashed
  session's claim becomes reclaimable without manual repair.
- **GitHub/GitLab backends:** the same commands work; claims are advisory (see Backends).
- It works inside `claude-sandboxed` sessions and Codex sessions started with the bypass flag
  (`o` / `or`; not `ox`, `codex-sandboxed exec` or a bare `codex-sandboxed`; see Sandboxes) on macOS and NixOS, in normal clones, linked worktrees,
  and `git bclone` repos.
- The patched superpowers and mattpocock outputs are byte-identical before and after the patch
  split (T1).

## Context

| | Here | zvolin |
|---|---|---|
| superpowers pin | v6.4.2 (`8ca22db`) | v6.1.1 (`d884ae0`) |
| mattpocock/skills pin | `c55ee46` | `9603c1c` (159 commits older) |
| superpowers patches | one 900-line `superpowers-customizations.patch` | seven per-skill patches |

His patches fail on our pins (36 failed hunks across superpowers, 23 across mattpocock), so nothing
is applied verbatim. Features are ported by hand onto our patches and onto upstream mattpocock
skills at our pin. Content copied from his repo comes from
`zvolin/nixos-config@27d4369c3512455d8a1ce83bd90bebc77fe890bd`:

- `modules/programs/ai-skills/dissent-review/files/` (SKILL.md, dissent-reviewer-prompt.md,
  adjudicator-prompt.md)
- `modules/programs/ai-skills/research/files/` (SKILL.md, reviewer-prompt.md,
  agents/{landscape-scout,coverage-reviewer,validation-reviewer}.md)
- `patches/mattpocock-handoff.patch`, `patches/mattpocock-wayfinder.patch`, and the
  `superpowers-*.patch` files as references for prose, not for application

Facts about this repo that the design depends on:

- Superpowers is installed for Claude only, as a plugin built in `claude/home/plugins.nix`
  (`patchedSuperpowers`). Codex gets `custom.llm.skills` entries but no superpowers.
- `custom.llm.skills` entries support `kind = "directory"` and reach both `~/.claude/skills/` and
  `~/.codex/skills/`. From mattpocock only `improve-codebase-architecture` is installed today
  (`home/common/llm/skills.nix`).
- `custom.llm.agents` reach Claude only through `~/.config/claude-agents/` plus per-project direnv
  detection (`claude/direnv-agents.sh`), which links nothing for most projects.
- `claude/overrides/CLAUDE.md` is installed as a static `.source` (`claude/home/rules.nix:22`).
- The ferrex MCP server is already off (`custom.qdrant.enable = false`); its prompt surface is not.
  `tests/codex.nix` is disabled because it greps for the ferrex server.
- The agent binaries run as `.claude-unwrapped` (`claude/package.nix`) and `codex-raw`
  (`pkgs/codex.nix`), not `claude`/`codex`.
- Both sandbox wrappers `exec` the agent directly and already expose `~/Repos`. The Linux Claude
  wrapper binds `$(dirname $(pwd))/{.bare,.git,.meta}`, which breaks from subdirectories; the Codex
  wrapper binds none of them.
- `tests/default.nix` has a common set (only `formatting`), a Darwin-only set and a Linux-only set.
- Claude Code treats `.git/` as a protected path: Edit/Write there asks for permission, which a
  background subagent cannot answer. All tracker writes therefore go through Bash.
- Our `executing-plans` is a router that hands off to `subagent-driven-development` (or
  `/team-feature`) and stops. Polish and `finishing-a-development-branch` (the user's merge / PR /
  keep choice) run inside `subagent-driven-development`. The exception is its Inline-Degraded path,
  which does its own polish and finish. Our patch is inconsistent about when that path runs: its
  gate requires both "no subagent support" and "user accepted", while its "When to Use" list and
  router rule 1 accept either. T9 settles it as OR: the path runs when the user explicitly asks
  for inline execution, or when no subagent tool is available and the user, told so, accepts. The
  gate's two bullets are rewritten to match, and so are the Post-Implementation Polish lines "You
  are inline because no subagent tool exists" and "If a subagent tool is in fact available, you
  should not be in this skill", which reject the user-asked branch; the rationalization row gains
  "and accepted". Router rule 1 already matches.
- `patchedSuperpowers` is a `let` binding in `claude/home/plugins.nix`. The overlay in `overlays/`
  only receives `vim-tidal` and `difftastic-src`, so flake inputs are not reachable from it.
- Inside sandnix on this Mac, `ps` can inspect the agent process. It is BSD `ps` (adv_cmds) either
  way: nixpkgs `procps` on Darwin via the Claude wrapper, `/bin/ps` under Codex. The script pins
  its own through `runtimeInputs`.
  A non-final `comm` column is cut to 16 characters; `ps -o comm= -p <pid>` alone prints the full path.

## Decisions

### Install the full mattpocock skill set wayfinder needs

Wayfinder calls `grilling`, `prototype`, `domain-modeling` and `research` by name and sends the user
to `setup-matt-pocock-skills`. Install all of these from the pinned input, plus `handoff`:
`wayfinder`, `setup-matt-pocock-skills`, `grilling`, `prototype`, `domain-modeling`, `research`,
`handoff`. Not installed: `to-tickets`, `triage`, `to-spec` and the rest; nothing in this flow calls
them.

Source paths in the pinned input differ: `skills/engineering/{wayfinder,setup-matt-pocock-skills,
prototype,domain-modeling,research}` and `skills/productivity/{grilling,handoff}`. The existing entry
in `home/common/llm/skills.nix` hard-codes `skills/engineering/`, so it can't be copied as-is for the
last two; the same goes for the `handoff` patch target.

`improve-codebase-architecture` (installed today) calls a `codebase-design` skill that is not
installed. Rather than install it, which would put one more skill description in every session on
both harnesses for a helper only this user-invoked skill uses, its `SKILL.md` (as
`CODEBASE-DESIGN.md`), `DEEPENING.md` and `DESIGN-IT-TWICE.md` are copied into the
`improve-codebase-architecture` directory in a `prePatch` step of the existing `applyPatches` call
(a new-file hunk would always apply, so upstream changes would drift silently) and then edited by
that skill's patch through context hunks, so drift fails the build. The six calls (three in `SKILL.md`,
three in `HTML-REPORT.md`) become "read `CODEBASE-DESIGN.md`" / "read `DESIGN-IT-TWICE.md`", the
copied files' `[SKILL.md](SKILL.md)` links are repointed, and `DESIGN-IT-TWICE.md`'s `CONTEXT.md`
reference moves to `docs/arch/glossary.md` with the rest of the glossary change.

### Tracker: pluggable, local maps in the git common dir

Keep upstream's tracker choice (local, GitHub, GitLab via `/setup-matt-pocock-skills`), but replace
the local backend. Upstream's local tracker is `.scratch/<effort>/` with `Status:`/`Type:`/
`Blocked by:` body lines. Ours stores maps in
`$(git rev-parse --path-format=absolute --git-common-dir)/wayfinder/<slug>/` with YAML frontmatter,
and every read and write goes through `wayfinder-ticket`.

- Pros: one location shared by every worktree of a clone; works in normal and bare clones; claims
  and phases are machine-checked.
- Cons: hidden from the editor tree; diverges from upstream's local format, so `issue-tracker-local.md` is replaced
  wholesale (T4: a short header naming the map location and `wayfinder-ticket`, then the rewritten
  "Wayfinding operations"; its `.scratch/` Conventions, publish and fetch sections serve only
  uninstalled skills), setup `SKILL.md`'s `.scratch/` mentions (the Explore bullet, the explainer,
  the "Local markdown" option) are repointed (T4), and the "Wayfinding operations" sections of
  `issue-tracker-{github,gitlab}.md` (T10) are rewritten to say "use `wayfinder-ticket`".
- Rejected: `.meta/wayfinder` (needs the bare layout); upstream `.scratch/` (per worktree, so
  parallel sessions in different worktrees diverge; no claim liveness).

**Backend selection** is machine-readable: `git config wayfinder.backend local|github|gitlab`,
default `local`. The patched `setup-matt-pocock-skills` sets it alongside writing the tracker doc;
the script never parses prose.

### References

Maps are referenced by slug, tickets by `<slug>#<id>` (e.g. `offline-sync#3`), on every backend.
Skills, trailers and phase handoffs carry only these references, never file paths, so the same
prose works for local, GitHub and GitLab. `wayfinder-ticket` resolves them: local to files under the
common dir; on remote backends the id is the issue number itself, and the slug is checked against
the issue's map membership (the remote form of "references escaping the map").

A slug matches `^[a-z0-9][a-z0-9-]*$` and an id matches `^[1-9][0-9]*$`. `map-new` and every
reference parse check both and reject before touching the filesystem; this is the rule the
"references escaping the map" tests assert.

### Invocation

`/wayfinder <arg>`: if `<arg>` matches a slug listed by `maps`, work that map; any other non-empty
argument is an idea and charts a new map (`map-new` still rejects an existing slug). Bare
`/wayfinder`: with 0 active maps, ask for an idea; with 1, work it; with 2 or more, list them and
ask which.

### Map model

`map.md` frontmatter: `slug`, `title`, `status` (`active`/`complete`), `created`. Body sections:
`## Destination`, `## Decisions so far`, `## Not yet specified`, `## Out of scope`, `## Notes`.
**Active** means `status: active`. A map is complete when it has no open tickets and an empty
"Not yet specified"; `map-complete` checks both and refuses otherwise. A section is empty when it
holds only whitespace; `map-new` creates every section except Destination empty. An empty frontier
is not completion: blocked or live-claimed tickets can still be open.

### Ticket model

Frontmatter: `id`, `type`, `title`, `status` (`open`/`closed`), `phase`, `blocked-by` (ids),
`claimed-by` (session id or empty), `spec`, `plan` (absolute paths locally, `<branch>:<repo-relative
path>` on remote backends), `branch` (set by `close`: the ticket branch after PR or keep, the default branch after a
Merge, from `--outcome`; either way dependents' merge check reads it correctly, see Phase
handoff), `superseded-by` (set by `drop --superseded-by`), `findings` (path inside the map dir locally, comment URL remotely). Body sections: `## Question`, `## Notes`, then `## Answer` or `## Verification evidence` when
closed. Nothing under the map dir is edited with Edit/Write; skills read through `show` and write
through the commands below.

| Type | Initial phase | Phases | Closed by |
|---|---|---|---|
| `research:fact` | — | — | `resolve` |
| `research:options` | `research` | `research` → `wayfinder:resolve` | `resolve` (from `wayfinder:resolve`) |
| `grilling`, `prototype`, `task` | — | — | `resolve` |
| `implementation` | `superpowers:brainstorming` | → `superpowers:writing-plans` → `superpowers:executing-plans` → `implemented` (set only by `close`) | `close` (from `superpowers:executing-plans`) |
| any | | | `drop` (out of scope) |

`advance` accepts only the forward arrows in the Phases column; types without phases reject every
`advance`, and nothing moves backward.

**When implementation tickets are created.** Upstream wayfinder says "plan, don't do": a map only
finds the route. We keep that for decision tickets and add one rule: when `resolve` closes a
decision whose answer is directly buildable, wayfinder runs
`new <slug> implementation <title> --question <f> [--blocked-by <id>…]` (blocked by nothing, by
other open decisions it depends on, or by open implementation tickets whose code it builds on,
passed in the same call so the ticket never sits unblocked on the frontier) and the build happens in the phase skills, never inside wayfinder. `<f>` names the
source decision by reference (`<slug>#<id>`) plus a one-line statement of what to build. In ticket
mode brainstorming runs `show` on each reference named in the Question and on every closed id in
its own `blocked-by` before exploring, and checks that every closed implementation blocker's
`branch` is merged (Phase handoff, brainstorming row). Wayfinder runs the same merge check before
working a decision ticket; for each unmerged or unknown blocker, unless Notes already carry the line,
it adds a Notes line (`blocker <id> branch <branch> not merged; answer assumes it lands as-is`),
tells the user, and proceeds. A decision
ticket has no worktree to stack on, and waiting would leave it on the frontier for the next session
to pick again. The exception is a resolved `prototype` ticket whose id is in
an open implementation ticket's `blocked-by` (a Spike; brainstorming's Spike step is the only path
that creates one): no new ticket is created, since the blocked ticket's brainstorming picks the
prototype's answer up through its `blocked-by`. A buildable decision that an implementation ticket
merely waits on still gets its own implementation ticket. When an open implementation ticket lists
the resolved decision in `blocked-by` and builds on that decision's code, wayfinder runs
`block <that ticket> <new id>` right after creating the new implementation ticket, so it stays off
the frontier until the code it builds on is closed (a live claim by another session makes this a
pending upkeep line, as for any `block`; if `block` rejects as a cycle, wayfinder adds a Notes line
to both tickets and tells the user instead).

Research findings are stored in the map dir (`findings/<id>.md`, via `attach`) and never go on a
git branch. Decision tickets write tracker files plus, whenever `domain-modeling` runs (charting,
grilling, or as wayfinder's default on any ticket), the glossary and ADRs in the working tree. Those
edits stay uncommitted for the user and are safe for parallel sessions in one checkout: Edit and
`apply_patch` refuse a stale base, so concurrent edits land one after the other. The worst case is
two ADRs with the same number. Grilling tickets therefore stay in the shared checkout, where the
glossary belongs.

Prototype tickets are overridden in the wayfinder patch (T8), with no patch to `prototype` itself.
Upstream writes the prototype next to the real code, commits it to a throwaway branch (in practice a
branch switch under every session sharing the checkout), and then folds validated decisions into the
real code, which is a build inside a decision ticket. In ticket mode, wayfinder tells it instead:
a logic prototype is a single file built in a scratch location and `attach`ed as findings; a UI
prototype goes in `git worktree add --detach` at
`$(wayfinder-ticket main-root)/.claude/worktrees/wayfinder-<slug>-<id>/`, with its path in the
ticket's Notes. It uses the main root, not the current toplevel, so a prototype never nests inside a
ticket worktree that the post-finishing restart line later removes. That location is chosen because Claude Code exempts `.claude/worktrees/` from its
`.git`-style protected-path check (so Edit/Write there doesn't depend on the bypass flags), the
global gitignore already covers `.claude`, and it is writable in both sandboxes and under Codex's
workspace-write mode. It is not `/tmp` (a private tmpfs under bwrap), a sibling path (unwritable
outside `~/Repos`), or the map dir (under `.git/` in a normal clone, and never edited with
Edit/Write). Cost: build or test tools that walk ignored directories may pick it up.
Before `resolve`, anything worth keeping is `attach`ed. Removal is script behaviour, not prose:
`resolve` and `drop` look for a worktree whose basename is `wayfinder-<slug>-<id>` in
`git worktree list --porcelain` (shared by every checkout of the clone) and, if one is registered,
run `git worktree remove --force <path>` and `git worktree prune` (safe for `drop`, which already
refuses a live foreign claim); `map-complete` sweeps leftovers with the same exact-basename lookup, once per ticket id in this map
(never a `wayfinder-<slug>-*` glob: slugs may contain hyphens, so `foo`'s glob would match map
`foo-bar`'s worktrees).
The path stays in Notes. Both upstream
steps ("commit to a throwaway branch", "fold into real code") are skipped, and the validated
decision becomes an implementation ticket when the ticket resolves (unless it is a Spike blocking an
existing implementation ticket; see the exception above). T12 checks the model follows
this; if it doesn't, patch `prototype` instead.

### `wayfinder-ticket` script

zvolin's lock/CAS/release rules are prose spread across five skills. Here they are one script the
skills call, packaged with `writeShellApplication` (shellcheck at build time) and installed through
`home.packages` (both sandboxes inherit the host `PATH` and see `/nix`). It is defined in
`pkgs/wayfinder-ticket.nix` and registered in `overlays/packages.nix` like every other local package
(it takes no flake inputs, so the overlay limit above doesn't apply); `home/common/packages.nix` and
the test use `pkgs.wayfinder-ticket`. The test stays a standalone common-set file rather than
`passthru.tests`, which `tests/default.nix` merges only into the Darwin set. `runtimeInputs`:
`git`, `flock` (`pkgs.flock`; macOS has no `flock(1)`), `yq-go`, `coreutils`, `procps` (`ps`),
`util-linux` on Linux (for `setsid`), `perl` on macOS (for `POSIX::setsid`), and `gh` for the GitHub
backend. `glab` is not pinned: it is installed only with `custom.gitlab.enable`, so the GitLab
backend looks it up on `PATH` at call time and fails with "gitlab backend needs glab; enable
custom.gitlab" when it is missing.

| Command | Effect | Rejected (non-zero, nothing written) when |
|---|---|---|
| `map-new <slug> <title> --destination <file>` | create map, `status: active` | slug exists |
| `maps` | list maps with status and open-ticket count | — |
| `map-edit <slug> <section> --file <f> --expect <sha>` | replace a map body section; `show-map` prints each section's hash for `--expect` | unknown section; Decisions so far (append-only, via `resolve`); `--expect` missing or ≠ current hash (re-run `show-map`, merge, retry) |
| `map-complete <slug>` | `status: complete` | open tickets remain; Not yet specified non-empty |
| `new <slug> <type> <title> [--question <f>] [--blocked-by <id>…]` | create ticket with next id and the type's initial phase; `blocked-by` written in the same `map.write` section | map missing or complete; unknown type; `--blocked-by` id not in map |
| `block <ref> <id>…` / `unblock` | edit `blocked-by` (second-pass wiring) | closed; live claim by another session; id not in map; `block` would create a cycle (including a self-block) |
| `show <ref>` / `show-map <slug>` | print ticket or map (frontmatter and body) and its path or URL | — |
| `edit <ref> <Question\|Notes\|Title> --file <f>` | replace that body section (Title: the `title` field) | closed; live claim by another session |
| `attach <ref> --findings <f>` | copy into `findings/<id>.md`, set `findings:` | not owner; closed |
| `claim <ref> [--phase <p>]` | acquire claim (see protocol) | map or ticket not found (distinct message; on remote backends includes failing the map-membership check); live claim by another session; closed; blocked; `phase` ≠ `<p>` (reports the actual phase); with `--phase`, a recorded `spec`/`plan` that can't be read from this checkout (names the worktree that holds it; claim protocol step 8); no agent process found |
| `release <ref> [--force]` | stop own holder, clear `claimed-by`; `--force` clears another session's claim (remote backends only) | not owner |
| `advance <ref> <from> <to> [spec=…] [plan=…]` | CAS `phase`, set fields; **keeps the claim** | phase ≠ from; not owner; illegal edge |
| `resolve <ref> --answer <f>` | write `## Answer`, close, append a pointer to Decisions so far, release | not owner; implementation ticket; `research:options` not in `wayfinder:resolve` |
| `close <ref> --evidence <f> --outcome merge\|pr\|keep` | write `## Verification evidence`, `phase: implemented`, `branch:` (the default branch for `merge`, otherwise the current branch), close, release | not owner; phase ≠ `superpowers:executing-plans`; evidence empty; `--outcome` missing |
| `drop <ref> --reason <text> [--superseded-by <id>]` | close, reason in `## Answer` and a line in the map's Out of scope, release; with `--superseded-by`, no Out of scope line, the answer points at the replacement, `superseded-by: <id>` is recorded (and printed by `status`), and in the same `map.write` section every open ticket whose `blocked-by` lists the old id gets the new id instead (closed tickets skipped; claims ignored, since this is bookkeeping and those tickets are blocked) | closed; live claim by another session; replacement id not in map; the rewiring would create a cycle (whole drop rejected) |
| `frontier <slug>` | own live claims first (marked `mine`, or `mine (blocked)` when a blocker was added after the claim; wayfinder reports those and does not route them), then open, unblocked (every `blocked-by` id closed), unclaimed-or-stale tickets in id order, with type and phase, marking a brainstorming-phase ticket whose Notes hold `waiting on merge:` as `waiting <branch>` | — |
| `status <ref>` | fields, the ticket's file path (local) or URL (remote), and whether the claim is live and whose | — |
| `main-root` | print the main root (see Main root) | no main root found |
| `merged <branch>` | print `merged local`, `merged origin`, `merged forge`, `unmerged` or `unknown`: `git merge-base --is-ancestor` against local `<default>` and, after a best-effort `git fetch origin <default>`, `origin/<default>` when that ref exists (finishing's Merge is local and unpushed; a fresh or offline `git bclone` may have no remote-tracking ref); a missing `<branch>` ref is `unknown`; on the GitHub/GitLab backends a failed ancestry check falls back to the forge (`gh pr list --head <branch> --state merged`, `glab mr list --merged --source-branch <branch>`; non-empty output is a hit, since both exit 0 on no match) | — |
| `base-ref <ref> [--stack <branch>]` | print the base for the ticket's worktree: `<branch>` with `--stack`; otherwise the first of local `<default>` and `origin/<default>` that contains every closed implementation blocker `merged` counts as merged (local preferred, so unpushed merges are kept; a `merged forge` hit needs `origin/<default>` and a fetch that succeeded); with no such blockers, local, or `origin/<default>` when strictly ahead of it | neither ref contains every merged blocker (names the missing ones) |
| `default-branch` | print the default branch as a bare name (`main`, never `origin/main`): `git symbolic-ref --short refs/remotes/origin/HEAD` with `origin/` stripped; failing that, when the common dir is bare, `git --git-dir="$(git rev-parse --git-common-dir)" symbolic-ref --short HEAD` (which `clone --bare` sets to the remote's default; a fresh `git bclone` has no `origin/HEAD` until its first fetch); failing that, whichever of `refs/heads/main`/`master` exists | none found |
| `trailer <next> [<ref or slug>] [--cd <dir> [--remove <worktree> [--discard]]]` | print the two-line trailer in the current harness's syntax; with `--cd`, always a restart line to `<dir>` instead, skipping the worktree resolution below; with `--remove`, that restart line runs `git worktree remove <worktree>` (never `--force`) and `git branch -d <its branch>` (`-D` with `--discard`) after the `cd` and before starting the new session, so the removal happens outside the session and its sandbox; for a phase trailer whose ticket's `spec` lives in another worktree (or, with `spec` unset, whose registered `wayfinder-<slug>-<id>-impl` worktree is not the current toplevel), a restart line with `cd <path>` instead (claim protocol step 8); on a remote backend, printing a restart line first `release`s the ticket, its only side effect | `<next>` not `wayfinder`, `brainstorming`, `writing-plans` or `executing-plans`; `wayfinder` given a `<slug>#<id>` rather than a slug; a phase `<next>` without a `<slug>#<id>`; no agent ancestor and no `WAYFINDER_HARNESS` |

`trailer` keeps harness detection out of skill prose: it inspects the agent process (step 2 below;
`WAYFINDER_HARNESS=claude|codex` overrides it for tests)
and prints `/clear` + `/wayfinder offline-sync` for Claude or `/clear` + `$wayfinder offline-sync`
for Codex; phase skills map to `/superpowers:<skill>` in Claude and `$<skill>` in Codex (there the
skills are plain copied directories, not a plugin; see Codex parity).

**Map upkeep without a claim.** `edit`, `drop` and `block`/`unblock` succeed on an open ticket that
this session owns, that is unclaimed, or whose claim is stale; they reject closed tickets and live
claims held by another session, and blocked status doesn't matter. Each holds `map.write` through
its liveness probe and write, so it serialises against `claim`: a claim that lands first makes the
upkeep command reject, one that lands second sees the new text. This is what lets wayfinder update
or delete tickets a decision invalidates (upstream "Work through the map" step 5) and apply dissent's "apply" findings.
`attach` stays owner-only, since it belongs to resolving a ticket you hold. No retype: `drop
--superseded-by` and `new` instead, because the type fixes the phase rules. Skills read a ticket
with `show` only after `claim`, so they never act on text edited in between (`frontier`'s
`waiting` marker is the one Notes-derived fact read before a claim, and only to skip).

**Pending upkeep.** When an upkeep command rejects because another session holds the ticket live
(an implementation ticket keeps its claim across phases, so this can last days), wayfinder appends
`pending: <ref> <edit|drop|block|unblock> <what>` to the map's Notes via `map-edit Notes --expect …` and
tells the user the holder and phase from `status`. `<what>` is a one-line intent plus the decision
reference that triggered it (e.g. "narrow Question to X per `offline-sync#7`"), not a stored
payload: the retry re-applies it to the ticket's text as it is then, so it merges with whatever
the holder changed meanwhile. On every map entry, before the state check
below, wayfinder retries each pending line whose ticket's claim is now free or stale and removes the
line once it succeeds. If the ticket was closed in the meantime, the retry can never succeed. If it has
`superseded-by`, wayfinder rewrites the line's `<ref>` to the replacement (following chains) and
retries it there. Otherwise, a
ticket was dropped when it is closed without `phase: implemented` and without an entry in Decisions
so far (`close` sets the first, `resolve` appends the second). If it was dropped, the pending action
is moot and wayfinder just removes the line; otherwise
wayfinder files a follow-up ticket with `new` (its Question cites the closed ticket and the pending
action) and removes the line.

**History is never reopened.** No command reopens a closed ticket, and Decisions so far stays
append-only. A correction to something already closed is a new ticket: a decision that turns out
wrong gets a new decision ticket whose Question cites the old one, and when it resolves its answer
says "supersedes `<slug>#<id>`". Open tickets created from the old decision are then `block`ed onto
the new id or `drop --superseded-by` it if the new answer makes them obsolete (both go through
pending upkeep if held live), and an implementation ticket that already closed gets a follow-up
ticket.

Wayfinder resumes `mine` tickets before claiming new ones, and routes an implementation ticket to
the phase skill its `phase:` names by printing that trailer; it never runs the phase itself.

A `research:options` ticket runs in-session instead. At `research`, wayfinder invokes
`research-options <ref>`, which attaches its findings, runs `advance … research wayfinder:resolve`
and returns without a trailer. At `wayfinder:resolve` (straight after, or when resuming a `mine`
ticket), wayfinder writes the answer and runs `resolve`. When `research-options` is invoked directly
on a ticket rather than from wayfinder, it ends with `trailer wayfinder <slug>`.

`research:fact` tickets are the one exception to one ticket per session. Wayfinder fires them as
background subagents; each runs `claim` → research → `attach` → `resolve` itself, which is legal
because subagents share the session id and agent process. This replaces upstream "Chart the map"
step 5's `research/<name>` branch: the subagent writes findings to a temp file and `attach`es them,
and `research` itself stays unpatched. Upstream `research` tells its caller to spin up a background
agent and save notes in the repo, so the wayfinder patch's subagent prompt overrides both: the
subagent follows `research`'s gathering steps itself (no nested agent) and writes only to a
`mktemp` file, never the working tree. Wayfinder waits for every subagent before running dissent,
before the upkeep pass that edits or drops tickets a decision invalidated (its own subagents share
its session id, so upkeep could otherwise pull a ticket out from under one), and before printing a
trailer; new `research:fact` subagents are fired after upkeep. The session order is therefore:

1. Map entry: pending-upkeep retry → re-fire any `research:fact` this agent process still holds as `mine` (stale ones from exited processes are picked up in step 4), left by an interrupted
   earlier session, and wait for them → state check (below).
2. Resume or claim the session's one ticket, skipping `research:fact` entries (step 4 fires them);
   work and resolve it, applying the
   implementation-ticket rule if the answer is directly buildable. If `claim` rejects because the
   ticket was live-claimed by another session, blocked, closed or dropped since `frontier` ran,
   re-run `frontier` and take the next routable entry (none left: the state check's "nothing
   workable" branch); any other rejection prints its reason and stops. Before claiming an entry
   `frontier` marks `waiting <branch>`, wayfinder runs `merged <branch>`: still unmerged, it skips
   the entry like a rejected claim; merged or unknown, it routes it normally. The marker applies
   only at the brainstorming phase, so a leftover line never strands a later phase.
3. Wait for all subagents → upkeep for every resolve since the last pass (the session's own and any
   subagent's) → dissent on each such resolve's changed region, applying "apply" findings through
   `wayfinder-ticket` and queueing "ask" findings.
4. Fire a subagent for every `research:fact` ticket now on the frontier (created this session,
   left by earlier sessions, or stale; a subagent whose `claim` rejects for the reasons in step 2
   exits without attaching or resolving) → wait for all of them → upkeep and dissent for their
   resolves (no further subagents are fired; anything newly needed stays on the frontier).
5. Show the queued "ask" findings → trailer.

No subagent is in flight while wayfinder reads `frontier` to pick its ticket, and "resume `mine`
first" never applies to a `research:fact` ticket, since step 1 has already re-fired and awaited
those. A `research:fact` subagent never runs upkeep or dissent itself, and a fact answer never
triggers the implementation-ticket rule; if a fact makes something buildable, that goes through a
decision ticket. For a routed implementation ticket there is nothing to resolve: after the claim
the session runs step 3 only for resolves from step 1's re-fired subagents (a no-op if there were
none), skips step 4, then runs step 5.

A session that charts (a new map via Invocation, or re-charting at the state check below) runs:
chart (`map-new` or `map-edit`, `new` for each ticket) → fire charting's `research:fact` subagents →
wait for all of them → upkeep for their resolves → whole-map dissent, applying "apply" findings and
queueing "ask" findings → show the "ask" findings → `trailer wayfinder <slug>`. It claims no ticket;
the next session enters at step 1.

On entering a map, wayfinder retries pending upkeep, then checks its state before claiming. No open tickets and an empty "Not
yet specified": run `map-complete` and report the map done. No open tickets but "Not yet specified"
non-empty: go back to charting from it, and ask the user if nothing can be graduated. Open tickets
but no routable frontier entry (the frontier is empty or lists only `mine (blocked)` and tickets
still `waiting on merge`; a frontier
whose only routable entries are `research:fact` skips step 2 and goes straight to step 4): print
"nothing workable" with the blockers and claim holders from `status`, and each waiting ticket
with its branch and `trailer brainstorming <ref>` so the user can re-decide (proceed, stack, or
delete a squash-merged branch so it reads `unknown`), and stop; `mine (blocked)`
claims are kept, since the guards re-check on resume. This runs on entry rather than after mutations because the last `close` of a map usually
happens in `subagent-driven-development`, not in wayfinder.

#### Main root

Ticket and prototype worktrees, finishing's merge and cleanup, and the sandbox binds all hang off one
directory, the main root, printed by `wayfinder-ticket main-root`:

- Common dir not bare (normal clones and their linked worktrees): upstream finishing's
  `git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel`, so behaviour there is
  unchanged.
- Common dir bare (`git bclone`): the worktree whose porcelain line in `git worktree list
  --porcelain` is `branch refs/heads/<default>`, with `<default>` from `default-branch`; failing that, the first non-bare worktree not under
  any `.claude/worktrees/`; failing that, exit non-zero.

It never resolves inside a ticket worktree, so one ticket's worktree can't nest inside another's and
be deleted with it.

#### Claim protocol (local backend)

1. **Session identity.** One `"AGENT_SESSION_ID"` entry in `sharedEnvNames`
   (`home/common/sandboxed.nix`) carries it through sandnix `env -i` and, via the existing
   `pass_env` loop that emits `--setenv`, through bwrap `--clearenv`. `pass_env` skips unset
   variables, so each wrapper generates and exports a fresh UUID before that point, overwriting any
   inherited value (an agent launched from another agent's tool shell must not take over its
   claims through the re-entrant path in step 4): the Darwin
   `darwinExtras.preHook`, both Linux bwrap scripts before the loop, and the Linux passthrough
   wrappers `claudePlain`/`codexPlain` (used when `custom.claude.sandbox = false`). Every tool
   subprocess inherits it and it survives `/clear`. With it unset, the script refuses to claim
   rather than inventing an identity. Plain `claude`/`codex` on PATH bypass the wrappers and
   inherit any id in their environment, so ticket mode is supported only through
   `claude-sandboxed`/`codex-sandboxed` (what `a`/`o` run).
2. **Agent process.** Walk the parent chain to the first process whose executable is
   `.claude-unwrapped`, `claude`, `codex-raw` or `codex`: `readlink /proc/<pid>/exe` on Linux
   (`comm` truncates to 15 characters); on macOS `ps -o comm= -p <pid>` queried on its own (as a
   non-final column it is cut to 16 characters), compared by basename. Identity is (PID, start
   time): `/proc/<pid>/stat` field 22 on Linux, `ps -o lstart=` on macOS. `WAYFINDER_AGENT_PID`
   overrides the walk and `WAYFINDER_AGENT_START` the start time; both exist for tests, which run
   without an agent ancestor and cannot force PID reuse. If the walk finds no agent process and
   `WAYFINDER_AGENT_PID` is unset, `claim` exits non-zero before taking `map.write`, naming the
   executables it looked for. Codex must run in-process: under its shared app-server daemon, tool
   commands would descend from the daemon, so every session would find one agent process that
   outlives them all and inherit the daemon's environment. The Codex wrappers therefore pass
   `--no-daemon` (which also skips a daemon that is already running). It is a top-level flag and
   must precede any subcommand (`codex exec --no-daemon` is rejected). sandnix ignores
   `cli.extraArgs` on Darwin, so there `program` (a `types.str`) becomes
   `lib.getExe (pkgs.writeShellScriptBin "codex-no-daemon" ''exec ${lib.getExe pkgs.codex} --no-daemon "$@"'')`
   (exec'ing the `codex` wrapper keeps `pkgs/codex.nix`'s env and leaves `codex-raw` for the
   process walk); on Linux it goes right after `${codex}` in the bwrap `exec` line and in
   `codexPlain`. and `codexConfig` sets
   `features.daemon_auto_start = false` for plain `codex`; this gives up `codex agents` session
   browsing. `tests/codex.nix` asserts `daemon_auto_start = false` in `config.toml` (T3 adds the
   assertion, T7's re-enable runs it); the Linux sandbox VM test asserts the stub receives
   `--no-daemon`; T13 checks the Darwin wrapper.
3. **Locks.** Each ticket has `<id>.claim` (held by the holder). The map has `map.write`, taken
   (blocking, short) by every mutating command and by liveness probes; files are written to a temp
   file and renamed.
4. **Acquire.** Under `map.write`: open fd 9 on `<id>.claim` and `flock -n 9`. On failure: if
   `claimed-by` equals our session id the claim is ours (re-entrant: continue to the guards, exit 0
   if they pass); otherwise exit non-zero. Probes in `frontier`/`status` also run under `map.write`, so they never race a claim.
   The order inside `claim` is fixed: flock (or, on failure, the ownership check) → guard checks
   (closed, blocked, `--phase`) → write `claimed-by` (temp file + rename) → spawn the holder last.
   The guards run on the re-entrant path too: since `advance` keeps the claim, that is the normal
   path for a phase skill after a trailer. A guard failure there exits non-zero and leaves
   `claimed-by` and the holder as they are. If anything fails before the spawn, `claim` exits non-zero and
   the lock is released when fd 9 closes, so a held lock with an empty `claimed-by` never exists.
5. **Holder.** Spawn a holder that inherits fd 9 and **nothing else**: the `map.write` fd is closed
   in the holder (otherwise it would keep the map locked for the agent's lifetime and every later
   command would block), and stdin/stdout/stderr go to `/dev/null` (otherwise the agent's tool call
   waits for the pipe). It runs in a new session (`setsid -f` on Linux,
   `perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV'` on macOS) so an interrupt does not kill it. Every
   child the holder starts (`sleep`, `ps`) runs with `9>&-`, so the lock dies with the holder.
   The holder runs its first liveness check before detaching and signals readiness by writing its
   PID file; `claim` waits briefly for that file and checks the holder with `kill -0`. If the
   holder is missing or already dead, `claim` clears `claimed-by` (still under `map.write`) and
   exits non-zero. Otherwise `claim` closes its own fd 9 and exits.
6. **Liveness.** The holder polls every 5 s and exits when the agent process is gone or its start
   time changed (PID reuse). Its PID and start time are kept in
   `${TMPDIR:-/tmp}/wayfinder-$AGENT_SESSION_ID/<slug>-<id>.pid` (one session can hold several
   claims across maps) and used only by the same session's `release`/`resolve`/`close`/`drop`.
   These check the start time before signalling, then confirm on the lock itself: they take
   `flock -w 2` on `<id>.claim` (the signalled holder releases fd 9 when it exits; the 5 s poll
   plays no part) and clear `claimed-by` only once that succeeds, so a
   re-claim right after `release` never races. A missing PID file is handled the same way; if the
   lock is still held when the timeout expires, the command fails loudly and leaves `claimed-by`
   as it is.
7. **Stale.** `claimed-by` is set but the lock is free. `claim` takes it over and reports it.
8. **Across phases.** `advance` keeps the claim; after the trailer's `/clear` the same process
   re-claims re-entrantly and `frontier` lists the ticket as `mine`. Moving to another terminal
   means `release` first. **One worktree per implementation ticket.** Ticket-mode brainstorming
   runs `superpowers:using-git-worktrees` once the Spike decision is past (a Spike never creates a
   worktree; exploration before that point only reads) and before writing the spec. Exploration,
   including reading the glossary and ADRs that grilling left uncommitted, therefore happens in
   the session's starting checkout, and the spec must quote any glossary terms or ADRs it relies
   on: later phases run in the worktree, which branches from committed history and doesn't see
   those edits. Upstream
   step 0 reuses any linked worktree without looking at its branch, and a fresh `git bclone` has
   exactly one, on the default branch, so in ticket mode the brainstorming patch narrows it to the
   ticket's own worktree: directory and branch `wayfinder-<slug>-<id>-impl` under the main root's
   `.claude/worktrees/`. The `-impl` suffix can't collide with a prototype's
   `wayfinder-<slug>-<id>`, whose basename ends in the id, so `resolve`/`drop`/`map-complete` never
   remove it. If the cwd is that worktree it is reused; if `git worktree list --porcelain` lists it
   elsewhere (an interrupted brainstorming, or a Codex session whose cwd stayed put), the session
   runs `trailer brainstorming <ref>`, shows its restart line and stops; otherwise it is created, in every layout (asking
   first; ticket mode requires it, so if the user declines, a Notes line, `release`,
   `trailer wayfinder <slug>` and stop, leaving the ticket at brainstorming), never as a `git wb` sibling
   (`scripts/git-worktree-new.sh` hard-codes `origin/main`, and a sibling lies outside the
   toplevel). Two tickets never share a worktree, and a closed ticket's kept or PR worktree is never
   reused. The new branch starts from `wayfinder-ticket base-ref <ref>` (`--stack <branch>` when the
   user chose to stack on an unmerged blocker; Phase handoff, brainstorming row), which never picks a
   ref lacking a blocker the merge check counted as merged: finishing's Merge is local and Claude
   can't push, so local and `origin` can each hold merges the other lacks. When `base-ref` rejects
   (they have diverged and neither holds every merged blocker), brainstorming asks the user to
   bring local `<default>` up to date themselves and re-run, to base on `origin/<default>` and
   lose the unpushed local merges, or to wait, and records the choice in Notes; it never merges
   into the user's default branch itself.
   On both harnesses the brainstorming patch creates it with
   `git worktree add -b <branch> <main root>/.claude/worktrees/<branch> <base>`, overriding
   `using-git-worktrees`' native-tool-first step: Claude's `EnterWorktree` takes only `name` or
   `path`, and its `name` form branches from the `worktree.baseRef` setting (`origin/<default>` by
   default) under the current toplevel, so it can neither stack on a blocker's branch nor target
   the main root from a linked worktree. On Claude the patch then calls `EnterWorktree path=<dir>`
   to move the session in, citing the ticket-mode request as the user's worktree consent (as
   upstream's Step 0 does); on Codex the restart line below does that. Both
   sandboxes can write there because the wrappers bind the main root (Sandboxes).
   direnv finds the main worktree's `.envrc` by walking up, so the dev shell loads there, but
   `use claude_rules`/`use claude_agents` link into `<main worktree>/.claude/`; T13 checks that a
   session in the ticket worktree sees those rules and agents, and if not, creation also symlinks
   the main worktree's `.claude/rules` and `.claude/agents` into it.
   Spec and plan are then written, uncommitted, to that worktree's `docs/`, every later phase runs
   there, and SDD's Setup detects the linked worktree and reuses it, so execution sees both files.
   A worktree created mid-session does not move the next session's cwd on its own: a Codex shell
   `cd` doesn't persist, and whether Claude's `EnterWorktree` cwd survives `/clear` is checked in
   T13. So `trailer <phase> <ref>` resolves the worktree holding the ticket's `spec` (locally
   `git -C "$(dirname <spec>)" rev-parse --show-toplevel`, never a prefix match; remotely the
   worktree whose `branch` in `git worktree list --porcelain` equals the recorded branch), or, while
   `spec` is unset (brainstorming before spec approval), the registered worktree whose basename is
   exactly `wayfinder-<slug>-<id>-impl` (same on every backend, since directory and branch share
   that name), and when it
   differs from the current toplevel it prints a restart line instead of a bare `/clear`: exit,
   `cd <path>`, start a new session there with `a` (Claude) or `o` (Codex), then the phase command. The new session has a
   new `AGENT_SESSION_ID`. On the local backend it takes the claim over as stale (step 7) once the
   old agent process has exited. Remote backends have no liveness, so there `trailer` `release`s the
   ticket before printing a restart line and says so; the new session's claim is then an ordinary
   fresh one, and the spec-ownership guard below keeps sessions in other checkouts out during the
   gap; "the same process re-claims" above holds only when the cwd already follows.
   After `close` or `drop`, `spec` and `plan` are historical pointers and may no longer resolve
   (the restart line after Merge or Discard removes the worktree); nothing reads them after close except re-file on discard,
   which already handles a missing file. The spec stays uncommitted by design (the plan is
   committed through SDD's checkbox commits), so on Merge or Discard finishing's Step 6 still
   runs its commit / move / delete prompt for the untracked spec before deferring removal (after a
   Merge, only move or delete, since a commit after the merge would make the restart line's
   `git branch -d` refuse), which
   leaves a clean tree for the restart line's non-forced `git worktree remove`; "move to the main
   root" keeps it.
   A sandboxed session in another worktree outside `~/Repos` cannot read the spec and plan. `claim --phase`
   rejects (nothing written) when a recorded `spec` or `plan` is missing, or when the worktree that
   owns it (`git -C "$(dirname <file>)" rev-parse --show-toplevel`, both sides canonicalised with
   `realpath`) is not the claiming checkout's toplevel, and names that owning worktree. Ownership is
   never decided by path prefix: ticket worktrees nest under the main root's
   `.claude/worktrees/`, so the main root's toplevel is a prefix of every ticket's spec path.
   That catches a later phase started from the wrong checkout on every
   backend, through the phase skills' existing "any other rejection: print the reason and stop"
   rule, with no backend-specific prose. The guards run before `claimed-by` is written, so a fresh
   session in the wrong checkout holds nothing; the owner's re-entrant claim stays held, and the
   user restarts in the named worktree. If the file is gone for good (worktree moved or deleted),
   the ticket can't pass the guard again; recovery is re-filing it and
   `drop <ref> --superseded-by <new-id>`, as for a discard.

#### Backends

`local` follows the protocol above. `github`/`gitlab` implement the same commands with `gh`/`glab`,
building on upstream's "Wayfinding operations" in `issue-tracker-{github,gitlab}.md`:

| Field | GitHub | GitLab |
|---|---|---|
| Map | issue labelled `wayfinder:map`; body starts with `<!-- wayfinder: slug=<slug> status=active\|complete -->`; slug resolved by listing `wayfinder:map` issues in all states; `map-complete` closes the issue | same |
| Ticket id | the issue number | the issue number |
| Membership | native sub-issue, falling back to `Part of #<map>` | `Part of #<map>` line (no sub-issues) |
| Type / phase | labels `wayfinder:<type>` and `wayfinder-phase:<phase>`, created idempotently (`gh label create --force`) before first use | same labels; GitLab creates them on use; never `::` (scoped labels) |
| Blocking | native dependencies, falling back to a `Blocked by:` line | `/blocked_by` where the tier has it, else a `Blocked by:` line |
| Claim | assignee plus a `wayfinder-session: <id>` comment; only the latest `wayfinder-session:` comment counts. "Held by another session" means it names a different id; free means there is none or the latest is `wayfinder-session: none`. `release` and `release --force` post `wayfinder-session: none` and unassign | same |
| Findings | a comment headed `<!-- wayfinder:findings -->`, its URL in `findings:`; `attach` fails loudly over the size limit | same |
| `spec`/`plan` | `<branch>:<repo-relative path>`; `advance` always takes an absolute path and derives both parts from the file's own worktree, not the cwd (a Codex session's cwd stays in its starting checkout after creating the ticket worktree): `git -C "$(dirname <path>)" branch --show-current` and the path relative to `git -C "$(dirname <path>)" rev-parse --show-toplevel`. It rejects a detached HEAD in that worktree, or a path in no worktree of this repository (its `--git-common-dir` differs from the cwd's); an uncommitted or unpushed file is accepted. To avoid that rejection landing after the user approved a spec, `claim --phase superpowers:brainstorming` rejects a detached HEAD up front ("check out a branch first"). Phase skills read the file at `$(git rev-parse --show-toplevel)/<path>`; `claim --phase` rejects when the current worktree isn't on that branch or the file is missing, the same guard as the local backend (claim protocol step 8) | same |

Metadata lives in hidden `<!-- -->` blocks that `edit`/`map-edit` preserve, since bodies render for
humans. There is no lock and no liveness signal, so claims are advisory, a stale claim needs
`release --force`, and `map-new`'s duplicate-slug check and `map-edit --expect` are best effort
(re-fetch, then write). The local success criteria do not apply.

### Review gate: dissent, then the existing loop capped at 3

Vendor `dissent-review` as a directory skill. In brainstorming and writing-plans, run it before the
existing finder/validator loop and lower that loop's cap from 10 to 3. On maps, dissent is advisory
and never writes tracker state: the wayfinder session runs it on the whole map after charting and on
the changed region after each `resolve`, applies the "apply" findings itself through
`wayfinder-ticket`, and shows only the "ask" findings to the user. A finding against a closed ticket
or an entry in Decisions so far is always "ask", whatever dissent labelled it; if the user agrees,
it is handled as described under "History is never reopened".

Changes from his copy of `dissent-review` (T5):

- Dispatch: `Agent` with `general-purpose` on Claude, `spawn_agent` on Codex (see the Codex note
  under Research).
- Map mode: wayfinder writes the bundle below to a `mktemp` file and passes it as `path`. The
  reviewer prompt's slots are filled as `DESTINATION` from `show-map`, `CLOSED_IDS` from the closed
  tickets in the bundle, `TRACKER_BINDINGS` as the backend plus the map slug, `REVIEW_SCOPE` as
  "whole map" or "changed region: `<ref>` plus the tickets its upkeep touched", and `CHART_STATE`
  as `charted` after charting and `re-chartered` after a resolve.
- Return section: "conformance lint, then `humanizer`" becomes "the surface runs its
  finder/validator loop (cap 3)"; the analogy to the uninstalled `review` skill is dropped.

Dissent gets one concatenated document as its artifact. **Whole map:** `show-map <slug>` plus `show`
of every open ticket. **Changed region after a `resolve`:** `show-map <slug>` (Destination and
Decisions so far as context) plus `show` of the resolved ticket, every open ticket created, edited,
blocked or unblocked by that resolve's upkeep pass, and every open ticket that cites the resolved
ticket's reference. Closed tickets in the bundle are context only; findings against them are "ask".

- Pros: dissent finds design blind spots and lets the author answer; the 2+2 loop still catches
  structural problems.
- Cons: 2 more agents per review (dissent reviewer + adjudicator; 1 when dissent finds the
  artifact sound) on top of 4×N, though with N now capped at 3 the worst case drops from 40 to 14.

### Phase handoff: `/clear` only in ticket mode

Each phase skill takes an optional ticket reference. Without one, behaviour is today's (chain in
one session). With one passed explicitly: if `claim --phase` rejects on a mismatch and the actual
phase is a `superpowers:*` phase, the skill prints `trailer <phase> <ref>`, where `<phase>` is the
ticket's actual phase with the `superpowers:` prefix stripped (e.g. a ticket still at
`superpowers:writing-plans` gets `trailer writing-plans <ref>`), and stops; on any other rejection, or a non-superpowers phase, it prints the
rejection reason and stops. A reference read from a plan's handoff block follows the rule below
that block instead.

| Skill | Ticket-mode steps |
|---|---|
| brainstorming | `claim --phase superpowers:brainstorming`; while running `show` on closed `blocked-by` ids, run `wayfinder-ticket merged <branch>` on each closed implementation blocker's `branch` (the merge check). If any is unmerged or unknown, ask the user ("Asking the user" format) to wait (a `waiting on merge: <blocker-id> <branch>` Notes line, `release`, `trailer wayfinder <slug>`; the ticket stays at brainstorming; choosing proceed or stack later removes those lines with `edit … Notes`), to proceed from the default branch (the blocker landed by squash or rebase, or its branch is gone; recorded in a Notes line so later entries don't ask again), or, when exactly one is unmerged, to stack the ticket's worktree on that branch (recorded as a `Stacked on: <branch>` Notes line, which finishing reads); once past the Spike decision, `superpowers:using-git-worktrees` (reuse or create the ticket's worktree; claim protocol step 8); always the Architectural path, so every implementation ticket gets a spec and a plan (executing-plans and `subagent-driven-development` are built around a plan file). Normal flow up to the user's spec approval; `advance … superpowers:writing-plans spec=<abs path>`. **Architectural:** `trailer writing-plans <ref>`. **Would-be Bounded:** the short design goes into a short spec; after approval, run `trailer writing-plans <ref>`; if it prints a restart line (the session isn't in the spec's worktree, e.g. Codex right after creating it), show it as for Architectural; otherwise ignore its output and invoke writing-plans in the same session (the claim is kept) instead of printing a trailer, which saves one `/clear`. **Spike** (an open feasibility question): `new <slug> prototype <title> --question <f>` (`<f>` holds the feasibility question), `block <ref> <new-id>`, a Notes line, `release`, `trailer wayfinder <slug>`; the ticket stays at brainstorming and returns to the frontier once the prototype resolves |
| writing-plans | `claim --phase superpowers:writing-plans`; normal flow through the plan review loop; then, in ticket mode only, ask the user once to approve the plan ("Asking the user" format). A change request revises the plan and re-runs the loop. On approval, `advance … superpowers:executing-plans plan=<abs path>`; `trailer executing-plans <ref>`. The approval comes before `advance` because phases only move forward: after it, a bad plan can't go back through writing-plans |
| executing-plans | `claim --phase superpowers:executing-plans`; route as today. Ticket mode always uses Subagents (an Agent-teams strategy in the plan, or a user request to run inline, is overridden and announced), so the work runs in `subagent-driven-development`. With no subagent tool at all it does not take the Inline-Degraded path: it writes a Notes line, `release`s and stops with "ticket needs a subagent tool; resume `<slug>#<id>` under a harness that has one" |
| subagent-driven-development | after polish and after the user's choice in `finishing-a-development-branch` has been carried out. SDD invokes finishing with an explicit `ticket=<ref>` (or `ticket=none` outside ticket mode), the same pattern `executing-plans` uses for SDD, and finishing's ticket-mode behaviour keys on it. Before invoking finishing, record the main root (`wayfinder-ticket main-root`). In ticket mode finishing never removes the worktree this session runs in: on Codex a deleted cwd makes every later command fail to spawn, and under bwrap the launch directory is a bind mountpoint that `git worktree remove` can't delete (EBUSY). So after a Merge, or a confirmed Discard, of a worktree under `.claude/worktrees/`, every call in this row still runs in the worktree, and the closing trailer becomes `trailer wayfinder <slug> --cd <main root> --remove <worktree>` (plus `--discard` for Discard), whose restart line removes the worktree and its branch from the user's shell before the next session starts. **Merge, PR or keep:** under Claude, whose security hook denies `git push`, finishing's ticket-mode PR option leaves the worktree as keep does and prints `git push -u origin <branch>` and the forge's PR-create command for the user; that counts as carried out, and the chosen option reads `PR (push left to user)`. Then write evidence (test command, exit status, polish summary, chosen option), `close <ref> --evidence <f> --outcome merge\|pr\|keep` (which records `branch:`, so a dependent can tell a PR or keep from a merge), then the trailer (`--remove` form after Merge, plain `trailer wayfinder <slug>` after PR or keep). **Discard:** after the confirmed discard, ask the user once: drop or re-file. **Drop:** `drop <ref> --reason <what was discarded and why>`. **Re-file:** `new <slug> implementation <title> --question <f>` (the question holds the discard reason, cites the old `<slug>#<id>`, copies the old Question's source-decision reference(s) verbatim so brainstorming still reaches them, and adds the spec's path in the main root if Step 6 moved it there), then `drop <ref> --superseded-by <new-id>`, which rewires every dependent onto the new id. Re-running the discarded plan is not offered: discard deletes its branch, its boxes are already ticked, and `spec`/`plan` can't be repointed. Either way, end with the `--remove … --discard` trailer |

The user's gates in ticket mode are therefore the spec approval, the plan approval (ticket mode
only; a direct writing-plans run still transitions without one, as today) and the merge / PR / keep
choice. Each spec and plan generated in ticket mode carries one `## Wayfinder ticket handoff`
block holding only the ticket reference (`Wayfinder ticket: <slug>#<id>`). It is a back-link for
humans and the fallback from which `subagent-driven-development` reads the reference when invoked
without one; the ticket's `phase:` stays the only record of the phase. Only
`subagent-driven-development` invoked directly reads the block; `executing-plans` without a
reference ignores it and passes none on, so its behaviour doesn't depend on which strategy it
routes to. To make "invoked directly" checkable even after context compaction, `executing-plans`
always passes an explicit skill argument when routing to SDD: its reference, or `ticket=none` when
it has none. SDD treats an argument token matching the reference grammar (References) as a
reference and `ticket=none` as an explicit non-ticket run; any other argument text, such as a plan
path, is neither. SDD reads the handoff block of the plan it executes only when its arguments
contain neither a reference nor `ticket=none`. A passed
reference is claimed re-entrantly, which is a no-op for the owner. A reference read from the block counts as ticket mode only after
`claim <ref> --phase superpowers:executing-plans` succeeds. If that claim rejects because the ticket
is closed, or because the map or ticket no longer exists, the skill warns and finishes as a non-ticket run, with no `close` and no trailer, so a
plan whose ticket is done gets today's behaviour. On a phase mismatch with a `superpowers:*` phase
(e.g. the plan was never approved, so the ticket is still at `superpowers:writing-plans`), it prints
that phase's trailer and stops, as for an explicit reference. On any other rejection (live claim by
another session, blocked, no agent process), it prints the rejection reason and stops rather than
running the plan with the ticket left open.

### Research: two skills, picked per ticket

- `research:fact` → upstream mattpocock `research` (AFK background agent, primary sources).
- `research:options` → zvolin's `/research`, vendored as `llm/shared/skills/research-options/`.
  Changes from his copy:
  - frontmatter `name: research-options` (his `name: research` collides with upstream);
  - Tavily tools first, `WebSearch`/`WebFetch` as fallback when Tavily is not configured (it is
    absent in the dev container);
  - output through `wayfinder-ticket attach` in ticket mode, `docs/research/` otherwise;
  - ticket mode rewritten against `wayfinder-ticket` (`claim`, `advance research wayfinder:resolve`,
    claim kept), dropping his "clear owner on advance";
  - its three agent definitions and `reviewer-prompt.md` become **co-located prompt files**,
    dispatched as `general-purpose` subagents with the model each agent file declares (`haiku` for
    the scout, `opus` for the coverage and validation reviewers) passed explicitly; their `effort:`
    and the scout's `tools: WebSearch, WebFetch` restriction are intentionally dropped (the Agent
    tool cannot set effort, and lifting the tool restriction is what lets the scout use Tavily first);
    `reviewer-prompt.md` declares none, so the draft reviewer inherits the session model, as
    upstream. They are not `llm.agents`, which Claude
    would only load in direnv-matched projects. On Codex (both this skill and `dissent-review`
    reach it through `custom.llm.skills`), dispatch with `spawn_agent` and map the scout to the
    cheap tier and the coverage and validation reviewers to the strong tier from the session's
    allowed models (the draft reviewer passes no model), never the literal `haiku`/`opus`.

Wayfinder's charting step assigns the subtype.

### Handoff and memory

Install upstream `handoff` patched to save to `docs/superpowers/handoffs/<timestamp>-<slug>.md`
(gitignored globally) instead of the OS temp dir, which is per-sandbox tmpfs under bwrap and would
be lost. Source for the change: zvolin's `mattpocock-handoff.patch`.

Gate ferrex's prompt surface on `custom.qdrant.enable`: the "Memory System" section and the
`/recall`/`/remember`/`/checkpoint`/`/docs`-ferrex lines of `claude/overrides/CLAUDE.md`, the five memory commands, the
ferrex step in `/docs`, the `mcp__ferrex__*` permission rules, and the `~/.ferrex` sandbox binds.
The ferrex lines in `CLAUDE.md` are spread over three sections today, so restructure first: move
the ferrex bullet from "Before Writing Code" and the whole "During Long Sessions" section (every
bullet there depends on ferrex, including the trailing "Especially before…" qualifier) into the
"Memory System" section, drop "ferrex" from the `/docs` line in the base and say "`/docs` also syncs to ferrex" in
that section instead. That section becomes the fragment; `claude/home/rules.nix` builds the file as
`base + lib.optionalString config.custom.qdrant.enable fragment` (`rules.nix` has no `cfg`
binding; its `claudeCfg` is `custom.claude`), switching the entry from the static `.source` to
`.text`.
The commands go through `custom.llm.commands`, whose `llmContentEntry` has only `source`/`kind`
(`modules/options.nix`), so the CLAUDE.md `.text` pattern doesn't carry over. In
`home/common/llm/commands.nix` (today a static `{...}:` module), add `config`, `lib` and `pkgs`,
move `checkpoint`, `forget`, `recall`, `reflect` and `remember` into
`lib.optionalAttrs config.custom.qdrant.enable { … }`, and build `/docs` as
`docs.source = pkgs.writeText "docs.md" (head + lib.optionalString config.custom.qdrant.enable ferrex + tail)`,
splitting `llm/shared/commands/docs.md` around its `**Ferrex**` block so the block keeps its place
above "Present a summary".
The permission rules are option defaults inside `claude/security/default.nix`, which the Linux
security tests evaluate without `modules/options.nix`; so they are filtered in `claude/home.nix`,
not by reading `custom.*` inside the module. Only `allowedTools` needs it: `claude/home.nix`
already replaces the `confirmBeforeWrite` default, so its ferrex entries are inactive. Filter with
`lib.mkIf (!cfg.qdrant.enable) (lib.filter (t: !lib.hasPrefix "mcp__ferrex__" t)
options.programs.claude-code.security.permissions.allowedTools.default)`, adding `options` to the
module's arguments. The `~/.ferrex` binds are
in `home/darwin/sandboxed.nix` (Claude and Codex) and the Linux Codex wrapper in
`home/linux/sandboxed.nix` (`mkdir` and `bind_rw`); the Linux Claude wrapper has none.
The flake input and MCP wrapper stay. Re-enable `tests/codex.nix` with the ferrex assertion
conditional.

### Glossary

Patch `domain-modeling` and `setup-matt-pocock-skills` so the glossary is `docs/arch/glossary.md`
instead of a root `CONTEXT.md`. Single-context only: the multi-context `CONTEXT-MAP.md` mode is
removed. In setup's `SKILL.md` that covers the "Domain docs" intro bullet, the Explore step's
`CONTEXT.md`/`CONTEXT-MAP.md` and monorepo-signals bullets, step 2's skip rule (drop "Section C when
there's no monorepo"), Section C (drop the multi-context offer), and the step-4 template line (drop the `"single-context" or "multi-context"` choice). In
`domain.md` it covers the read list, the file-structure trees, the glossary section, and the
"reached via `/grill-with-docs`" line, which is repointed to wayfinder and
`/improve-codebase-architecture` (`grill-with-docs` is not installed). Restore the glossary references in our
`improve-codebase-architecture` patch, pointing at the same path.

### Patch layout

One patch per upstream skill directory, so a bad bump fails one patch:

- `patches/superpowers/<skill>.patch` for `brainstorming` (including
  `spec-document-reviewer-prompt.md`), `writing-plans` (including a new
  `plan-document-reviewer-prompt.md`: our patch's review loop names it as its template, but
  upstream deleted it in v6.4.2; T9 restores it from v6.4.1 and updates it), `executing-plans`,
  `subagent-driven-development` (including `implementer-prompt.md`), `requesting-code-review`,
  `finishing-a-development-branch`. In every mode: `MAIN_ROOT` comes from
  `wayfinder-ticket main-root` instead of upstream's expression, which fails in a `git bclone` repo,
  and for a host-owned worktree (upstream's "Otherwise" branch) Discard stops before `git branch -D`
  and reports that the branch can't be deleted while that worktree exists, where upstream would run
  it and fail. Option 1's `git pull` runs as `git pull --ff-only` only when
  `git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds (a `git bclone` worktree has no
  upstream); with no upstream, or when the pull fails (e.g. local `<default>` holds unpushed
  merges and `origin` moved), finishing reports it and merges without pulling, never rebasing,
  resetting or forcing. In ticket mode only, keyed on SDD's `ticket=<ref>` argument: a worktree under the
  main root's `.claude/worktrees/` is ours on both harnesses, because ownership is decided by path
  as upstream does for `.worktrees/` and ticket mode only creates worktrees there; Step 6 (which
  upstream runs only for Merge and a confirmed Discard; PR and keep stay in the worktree) does not
  remove the worktree when it is this session's toplevel, which in ticket mode it always is: it
  reports that removal (and Discard's `git branch -D`) is deferred to the restart line SDD prints
  (SDD row), and keeps upstream's never-`--force` rule for that removal. Under
  Claude, PR prints the push and PR-create commands instead of pushing (SDD row). Finishing reads
  the ticket with `wayfinder-ticket show <ref>` (from its `ticket=` argument); if Notes record
  `Stacked on: <branch>`, it runs `wayfinder-ticket merged <branch>`. While the result is unmerged it offers only PR (against that
  branch) or keep, with the reason; merged or unknown, Merge into the default branch is offered as
  usual. Before Merge, if the main root is not on the default branch
  (`git -C <main root> symbolic-ref --short HEAD`), it offers only PR or keep, with the reason; it
  does not gate on a dirty tree, and a merge git refuses because of local changes is reported to
  the user, never forced or stashed. In every mode, Step 6 matches paths relative to the main root:
  owned means the relative path starts with `.worktrees/` or `worktrees/`, and `.claude/worktrees/`
  is host-owned unless `ticket=<ref>` is set, so outside ticket mode Claude's `EnterWorktree`
  worktrees stay host-owned, as upstream has them.
- `patches/mattpocock/<skill>.patch` for `improve-codebase-architecture` (including edits to the
  `codebase-design` files copied in by `prePatch`), `wayfinder`,
  `setup-matt-pocock-skills`, `domain-modeling`, `handoff`.

### Codex parity

Move `patchedSuperpowers` out of `claude/home/plugins.nix` into a new home-manager module,
`home/common/llm/superpowers.nix`, which declares a read-only `custom.llm.superpowersPackage` option
and sets it unconditionally (e.g. `default = patchedSuperpowers; readOnly = true;`). Unlike
`custom.claude.enabledPlugins` in `plugins.nix`, it is not set under
`lib.mkIf config.custom.claude.enable`: `tests/codex.nix` enables only Codex, and a gated
definition would fail there with "used but not defined"; laziness already keeps an unreferenced
derivation from building. Claude's plugin list and
Codex both read it, so they share one derivation, and neither `flake.nix` nor the overlay changes.
Codex gets each skill directory as `~/.codex/skills/<skill>/` through its own `home.file` entries in
`home/common/codex/default.nix`, not through `custom.llm.skills` (which would also install a second
copy under `~/.claude/skills/`). Pinned superpowers does ship a Codex plugin
(`.codex-plugin/plugin.json`), but installing it is interactive and writes to Codex's own cache;
copying the directories keeps the install declarative and on the same `patchedSuperpowers`
derivation. Copied skills carry no `superpowers:` prefix, so `trailer` emits `$<skill>` and the
`superpowers:<skill>` mentions in skill prose resolve by bare name.

### "Asking the user" rules

Port his "Asking the user" section into brainstorming, writing-plans, executing-plans and wayfinder:
restate the context, name 2-3 options with their cost, recommend one, end with one short question.

### Sandboxes

Both bwrap wrappers resolve `git rev-parse --show-toplevel`,
`git rev-parse --path-format=absolute --git-common-dir` and the main root
(`${lib.getExe pkgs.wayfinder-ticket} main-root`, skipped when it fails) and bind each read-write
when it is outside the working directory (`--chdir` stays the cwd). The main-root bind lets a
session in a nested ticket worktree run finishing's Merge (checkout and merge in the main root) and
lets any linked worktree create ticket worktrees under the main root's `.claude/worktrees/`; the
common dir is already writable (including its hooks), so it adds little exposure. `.meta` is resolved the way `git meta` resolves
it, as `$(dirname <common-dir>)/.meta`, not from the cwd's parent, so the `git bclone` `.meta` bind
survives from subdirectories and from nested `.claude/worktrees/` worktrees; `.bare` (and, in a normal
clone, `.git`) is the common dir itself, so the common-dir bind covers it; the bclone root's `.git`
file is never read from inside a worktree. The current `worktree_parent="$(dirname "$(pwd)")"`
binds of `.bare`, `.git` and `.meta` in `home/linux/sandboxed.nix` are removed. This
covers bare clones, linked worktrees of normal clones, and starting in a subdirectory. Bind order
is two-pass. bwrap applies mounts in order, and today `bind_ro "$HOME/.config/nix-darwin"` shadows
`--bind $(pwd)`, leaving this repo read-only on the VMs and its common-dir `wayfinder/` unwritable.
So every read-write workspace bind (cwd, toplevel, common dir, main root, `.meta`) is emitted after
all `bind_ro` calls and the `~/.ssh` copies, and then each of those read-only binds is emitted again
unless its path equals or contains a workspace path (compared after `realpath`). That intentionally
makes `~/.config/nix-darwin` writable when the agent is launched from it, matching the macOS `"."`
rwx grant, while a launch from `$HOME` keeps `~/.config/git` and the other protected paths
read-only and keeps the user-owned `~/.ssh/config` copy that OpenSSH accepts. On macOS
sandnix has no binds, and it defines `add_paths` only after the `preHook` runs, so the hook can't
call it. Instead it resolves the same three directories with `realpath` and, for each one that exists,
appends `file-read*`, `file-write*`, `file-ioctl` and `process-exec` `(subpath …)` rules to
`$PROFILE_FILE` (what `add_paths rw` emits, plus exec so git hooks in the common dir still run, as
they do today under the `"."` rwx grant), the way the existing hook in `home/darwin/sandboxed.nix`
already writes rules. It calls git as `${lib.getExe pkgs.git}` and only when
`git rev-parse … 2>/dev/null` succeeds; outside a repo it adds nothing, since
`writeShellApplication`'s errexit would otherwise abort the launch. Repos under `~/Repos` already
work. Both wrappers set `AGENT_SESSION_ID` as described
in the claim protocol. If the macOS profile denies `ps` on the agent process, T13 finds out and T3's
follow-up adds the narrowest `process-info` allowance.

Codex started without `--dangerously-bypass-approvals-and-sandbox` (`ox`, `codex-sandboxed exec`,
or a bare interactive `codex-sandboxed`) runs Codex's own `workspace-write` sandbox with a read-only
`.git`, since `home/common/codex/default.nix` sets no `sandbox_mode`; ticket writes fail there. Only
`o`/`or` pass the bypass flag. Documented, not changed.

To make the Linux wrappers testable, their bind logic moves into a shared function that takes the
program to exec; the VM test instantiates it with a stub program. The Darwin `preHook` is covered
by T13.

## Out of scope

- His `skill-codex-safe-invocation`, `review`, `cleanup` and `threat-modeling-expert` skills.
- His `sdd-per-plan-ledger` (scopes the `.superpowers/sdd/progress.md` ledger per plan; our pin
  already does this via `sdd-workspace` → `.superpowers/sdd/<plan-basename>/progress.md`, and our
  patch's plan-file checkboxes complement it), `superpowers-task-brief-identifiers`
  (non-numeric task ids; ours are numeric) and `superpowers-implementer-prompt` (depends on a
  `**Rules:**` plan field we do not have).
- Ticket mode with the Agent-teams strategy (ticket mode always uses Subagents).
- mattpocock `to-tickets`, `triage`, `to-spec` and other skills wayfinder does not call.
- Migrating existing ferrex data; removing the ferrex flake input.
- Liveness for GitHub/GitLab claims.

## Risks

| Risk | Mitigation |
|---|---|
| macOS sandbox denies `ps` on the agent process | T13 checks in the real sandbox on both machines; fix is a narrow `process-info` rule in the sandnix profile |
| Holder hangs the tool call or dies on interrupt | Protocol step 5; T13 checks a real tool call, an Esc interrupt, and agent exit |
| Prompt bloat in phase skills | Ticket mode is one section per skill that mostly says "call `wayfinder-ticket …`" |
| Upstream mattpocock churn | Per-skill patches; script behaviour is covered by fixture tests, independent of prose |

## Testing

- **Build:** every patch applies (`applyPatches` fails otherwise).
- **Patch split:** `diff -r` of the patched superpowers and mattpocock trees before and after T1
  is empty.
- **`tests/wayfinder-ticket.nix`** (common set, both platforms; agent identity via
  `WAYFINDER_AGENT_PID`/`WAYFINDER_AGENT_START` pointing at a test-owned `sleep`, harness via
  `WAYFINDER_HARNESS`): fixture maps; map lifecycle; concurrent
  claims (exactly one wins); re-entrant claim by the owner; owner process killed then reclaim; PID
  reuse (start time mismatch) treated as stale; re-claim immediately after `release` succeeds;
  `frontier` ordering with `mine`; a blocker added to an owned live claim listing it as
  `mine (blocked)`; `new --blocked-by` writing `blocked-by` atomically and rejecting an unknown id;
  `resolve` and `drop` removing a registered proto worktree; a plan whose handoff-block map was
  removed (`claim` reports not found); `edit` and `block` on a ticket this session holds live
  (allowed, claim kept); upkeep commands on an unclaimed blocked ticket and a stale claim
  (allowed) and on a live foreign claim or a closed ticket (rejected); `drop --superseded-by`
  writing no Out of scope line, rewiring open dependents (closed ones untouched) and rejecting the
  whole drop when the rewiring would create a cycle; every guard rejecting without writing, including self-block and
  A→B→A cycles in `block`, `map-edit` with a stale `--expect` or a missing one on any
  section, and `claim --phase` on a mismatch, including on the re-entrant path (rejects, claim
  stays held); a ticket at `superpowers:executing-plans` whose holder's agent process has exited,
  claimed with `--phase superpowers:executing-plans` under a new `AGENT_SESSION_ID` (succeeds,
  reports the takeover), then `close --evidence <f> --outcome keep` from that session succeeding; that same claim
  against a closed ticket, an earlier phase (rejects, reports the actual phase) and a live claim by
  another session (rejects, nothing written); a failed
  `claimed-by` write leaving the lock free; `claim --phase` from a checkout that doesn't hold the recorded `spec` (rejects, names the right worktree, nothing written), including from the main root for a spec in a nested `.claude/worktrees/<b>/` (local and remote backends); on the remote backend, `advance` run with cwd in the main root recording `<b>:docs/...`, not `main:.claude/worktrees/<b>/docs/...`; `claim` with no agent ancestor and
  with `WAYFINDER_AGENT_PID` pointing at an exited process (rejected, `claimed-by` empty); `trailer`
  with no harness; malformed frontmatter
  and references escaping the map; `trailer` output per harness, its restart line when the
  ticket's `spec` lies in another worktree and, with `spec` unset, when its `-impl` worktree is
  registered elsewhere (no restart line when that worktree is the current toplevel), and its rejection of a phase `<next>` without a ticket
  reference; `trailer wayfinder <slug> --cd <dir>` printing a restart line to `<dir>` per harness
  (on a remote backend, releasing nothing); `map-complete` on map `foo` leaving a registered `wayfinder-foo-bar-<id>` worktree of
  map `foo-bar` in place; `main-root` in a normal clone, from a nested `.claude/worktrees/`
  worktree, and in a `git bclone` (the default-branch worktree, then with `main/` switched away the
  first worktree not under `.claude/worktrees/`), including a bclone with `origin/HEAD` set after a
  fetch and a `git wb` sibling listed before the default worktree; `default-branch` returning a bare
  name in a normal clone, a fresh bclone and a fetched bclone; `base-ref` after a local, unpushed Merge of a blocker printing the
  local default (which contains the blocker's commit), after a blocker landed only on `origin`
  printing `origin/<default>`, and rejecting when the two have diverged with one merged blocker
  each; `merged` for an ancestor of local only, of `origin` only, a missing ref (`unknown`) and no
  `origin` ref at all (T10 adds the forge cases); `close --outcome merge` recording the default branch and `--outcome pr|keep` the current one;
  `trailer … --cd <dir> --remove <wt> [--discard]` output per harness; `frontier` marking
  `waiting <branch>` for a brainstorming-phase ticket and not for one at a later phase;
  `base-ref --stack <b>` printing `<b>`; `base-ref` with no merged blockers printing
  `origin/<default>` only when strictly ahead. T10 adds its
  remote-backend cases to this same file against a `gh` stub injected with `.override`
  (`writeShellApplication` puts `runtimeInputs` ahead of `$PATH`, so a stub on PATH would lose to the
  pinned binary) and a `glab` stub on `PATH`, including a restart-line flow in which `trailer`
  releases the ticket and the new session's `claim --phase superpowers:writing-plans` succeeds, and
  the GitLab backend failing clearly with no `glab` on `PATH`.
- **`tests/llm-skills.nix`** (common set): home-manager evaluation in the style of `tests/codex.nix`,
  but importing more: `modules/options.nix`, `home/common/llm`, `home/common/codex`,
  `home/common/packages.nix`, `home/common/mcp.nix` (declares `codexMcpServers`),
  `claude/home.nix` and `home/common/lspmux.nix` (which `claude/home/plugins.nix` reads), with
  `claude.enable`, `codex.enable`, `qdrant.enable = false` and stub
  `custom.sandboxedPackages.{claude,codex}` (e.g. `pkgs.writeShellScriptBin "claude-sandboxed" ""`),
  which `packages.nix` reads and only the platform sandbox modules set.
  Asserts: every new skill (with co-located prompt files) exists under both `.claude/skills/` and
  `.codex/skills/`; the built setup skill contains no `.scratch/`; `wayfinder-ticket` is in `home.packages` (a package check, not per harness);
  ferrex is absent from the generated `.claude/CLAUDE.md`, the installed commands, the
  `settings.json` permissions and the Codex `config.toml`, which must still list another server
  (e.g. `context7`) so the check can't pass on an empty config. A second evaluation of the same
  modules with `qdrant.enable = true` asserts the opposite (the "Memory System" fragment in
  `.claude/CLAUDE.md`, the five memory commands, `mcp__ferrex__*` in the allow list, and
  `hm.config.custom.codexMcpServers ? ferrex` checked at eval time; this evaluation's Codex
  `config.toml` is not grepped, since building it would compile the uncached ferrex package during
  `nix flake check`), so a gate that always strips ferrex fails; T7 adds it.
- **Sandbox VM test** (Linux set): the shared wrapper function instantiated with a stub program
  that, from a subdirectory of a bare-clone worktree and of a linked worktree outside `~/Repos`,
  asserts `git status --porcelain` is empty, reads `docs/`, resolves `.envrc` through `.meta`,
  writes to the common-dir `wayfinder/`, and claims a ticket while a second stub contends. Each
  stub runs under its own wrapper invocation (so each gets a distinct `AGENT_SESSION_ID`, including one launched with `AGENT_SESSION_ID`
  already set in its environment; the Codex wrapper's stub also asserts it received `--no-daemon`) and,
  inside the sandbox, starts a background `sleep` and exports `WAYFINDER_AGENT_PID`/
  `WAYFINDER_AGENT_START` for it before calling `claim`; set outside, `--clearenv` would drop them.
  A further case starts the stub with its cwd inside a `bind_ro` path (a fake
  `$HOME/.config/nix-darwin` repo) and asserts it can write to the cwd and `<common-dir>/wayfinder`.
  Another starts it in a nested `.claude/worktrees/` worktree of that repo and asserts it can check
  out and merge in the main root. A last one starts it with cwd `$HOME` and asserts
  `~/.config/git` stays read-only and `~/.ssh/config` is the user-owned copy.
- **Re-enabled `tests/codex.nix`**, including the `daemon_auto_start = false` assertion T3 adds.
- **Manual checklist** (T12), in [docs/ai-workflow.md](../ai-workflow.md#testing). Adds: SDD
  invoked directly with no reference reads the plan's handoff block, runs as a non-ticket run when
  the ticket is closed and stops on a live foreign claim; after a prototype ticket resolves or is
  dropped, `git worktree list` shows no proto worktree; a brainstorming Spike creates a prototype
  ticket and blocks the implementation ticket, and when the prototype resolves no new implementation
  ticket appears and the blocked ticket's brainstorming reads the prototype's answer; resolving a
  buildable decision creates an implementation ticket whose Question names the source decision;
  a UI prototype lands in `.claude/worktrees/wayfinder-<slug>-<id>/` and edits there don't prompt;
  in a normal clone, ticket-mode brainstorming creates the worktree under `.claude/worktrees/`
  before the spec and SDD reuses it; in a `git bclone` repo, two tickets brainstormed from `main/`
  get two separate worktrees, neither on the default branch; Discard of a ticket in
  `.claude/worktrees/` removes the worktree and deletes the branch once the user runs the restart
  line; on Codex in a normal clone, a ticket goes brainstorming →
  writing-plans → SDD with the user following the restart line `trailer` prints; on Codex, Merge
  of a ticket from a restart-line session closes the ticket and prints a restart line that removes
  the worktree and branch from the main root, and Discard → drop does the same with `-D`; on the
  NixOS VM the same Merge leaves no half-removed worktree; a dissent "apply" finding against a just-resolved ticket is shown to the user, not applied;
  an upkeep `drop` against a ticket another session holds is recorded as `pending:` in the map's
  Notes and applied on a later entry once the claim is free; a ticket closed on PR makes its
  dependent's brainstorming ask to wait, proceed or stack before creating a worktree, while on the
  GitHub/GitLab backends a squash-merged blocker does not ask (forge fallback); on the local
  backend it asks, and "proceed from the default branch" records a Notes line so re-entry does not
  ask again; after "wait", the next wayfinder session routes a different frontier ticket, or
  reports "nothing workable" if that was the only one; under Claude, PR prints the push and PR-create commands and
  the ticket closes with `branch:` recorded; a stacked ticket whose blocker is unmerged is offered
  only PR or keep; a ticket claimed by another session between `frontier` and `claim` makes
  wayfinder take the next entry; a brainstorming
  interrupted after creating its worktree resumes in that worktree; after decision A resolves,
  an implementation ticket built on A's code is blocked by A's new implementation ticket and stays
  off the frontier until that ticket closes; two sessions brainstorming
  different tickets from one non-default worktree get two worktrees; a charting session claims no
  ticket and ends with `trailer wayfinder <slug>`.

## Execution Strategy

**Subagents.** Thirteen tasks. T1 and T2 have no predecessors and touch disjoint files, so they
form the first parallel batch. Files edited by several tasks get a single owner or a strict order:
`home/common/llm/skills.nix` (T1 → T4 → T5 → T6 → T8), `tests/default.nix` (T2 → T3 → T4 → T7),
`tests/llm-skills.nix` (T4 → T5 → T6 → T7 → T11), `tests/wayfinder-ticket.nix` and the script
(T2 → T13 → T10), `patches/mattpocock/setup-matt-pocock-skills.patch` (T4 → T10), sandbox wrappers
(T3 → T13 → T7), `home/common/codex/default.nix` (T3 → T11), `tests/codex.nix` (T3 → T7), `claude/overrides/CLAUDE.md` (T7 → T12), `claude/home/plugins.nix` and `home/common/llm/default.nix` (T1 → T11), `home/common/llm/superpowers.nix` and
`patches/superpowers/*.patch` (T1 → T9, after T13; T11 only reads `custom.llm.superpowersPackage`). T1 does
not touch `home/common/packages.nix`; T2 is its only editor.

## Task Dependency Graph

| ID | Task | Tag | Depends on |
|---|---|---|---|
| T1 | Split superpowers and mattpocock patches per skill directory; move `patchedSuperpowers` into `home/common/llm/superpowers.nix` (`custom.llm.superpowersPackage`); verify byte-identical output | AFK | none |
| T2 | `wayfinder-ticket` local backend in `pkgs/wayfinder-ticket.nix`: references, map and ticket model, every command (incl. upkeep guards, `new --blocked-by`, `drop --superseded-by` with dependent rewiring, and proto worktree removal in `resolve`/`drop`/`map-complete`), `main-root`, `default-branch`, `merged`, `base-ref`, `close --outcome`, claim protocol, `trailer` (incl. `--cd`, `--remove`, `--discard`), `frontier`'s `waiting` marker; add to `home.packages`; `tests/wayfinder-ticket.nix` in the common set | AFK | none |
| T3 | Sandbox wrappers: shared bind function taking the program to exec, common-dir and main-root binds, two-pass bind order, `AGENT_SESSION_ID` (one `sharedEnvNames` entry; generated fresh in the Darwin `preHook`, both bwrap scripts and the Linux passthrough wrappers), Codex `--no-daemon` and `daemon_auto_start = false`; Linux VM test with a stub program | AFK | T2 |
| T4 | Install `wayfinder`, `setup-matt-pocock-skills`, `grilling`, `prototype`, `domain-modeling`, `research`, `handoff` (source paths per Decisions); patches for handoff location, glossary path (domain-modeling incl. `CONTEXT-FORMAT.md`, setup `SKILL.md` (intro, Explore, step-2 skip rule, Section C, step-4 template), `domain.md` (incl. the `/grill-with-docs` pointer), improve-codebase-architecture), `codebase-design` files vendored into improve-codebase-architecture, `issue-tracker-local.md` replaced wholesale, setup's `.scratch/` mentions repointed, and `wayfinder.backend` in setup; `tests/llm-skills.nix` asserts the built setup skill contains no `.scratch/`; create `tests/llm-skills.nix` | AFK | T1, T3 |
| T5 | Vendor `dissent-review` as a directory skill with the changes listed under Review gate; extend `tests/llm-skills.nix` | AFK | T4 |
| T6 | Vendor `research-options` with the changes listed under Research; extend `tests/llm-skills.nix` | AFK | T5 |
| T7 | Ferrex gating (CLAUDE.md split, commands, `/docs`, permission filter in `claude/home.nix`, `~/.ferrex` binds); re-enable `tests/codex.nix`; extend `tests/llm-skills.nix` | AFK | T6, T13 |
| T8 | Wayfinder patch: all tracker access via `wayfinder-ticket`, references, ticket types and research subtypes, map upkeep without a claim, pending upkeep and its retry on entry, "history is never reopened" corrections, prototype override (`.claude/worktrees/` location), background subagents only for `research:fact`, implementation-ticket rule, resume `mine` first, map-state check on entry (incl. `map-complete`), `research:fact` subagents `attach` instead of upstream's `research/<name>` branch, routing by phase, trailers via `trailer`, charting-session order, the unmerged-blocker check before decision tickets (note and proceed), lost claim races (next frontier entry), dissent hook, "Asking the user"; register the patch in `skills.nix` | HITL | T6 |
| T9 | Superpowers patches: ticket mode per the Phase handoff table (brainstorming incl. the ticket's named worktree via using-git-worktrees, the unmerged-blocker check and stacking, Architectural-only and Spike/Bounded handling, writing-plans incl. ticket-mode plan approval, executing-plans, subagent-driven-development incl. drop-or-re-file on discard and the `ticket=` argument to finishing), review gate (dissent then loop cap 3; findings against closed tickets always "ask"), finishing-a-development-branch (`main-root`, host-owned Discard stop, guarded `git pull`, ticket-mode removal deferred to the restart line; Patch layout), restore `plan-document-reviewer-prompt.md`, reconcile the executing-plans Inline-Degraded gate, its Post-Implementation Polish lines and rationalization row with the OR rule (see Context), "Asking the user" | HITL | T1, T2, T5, T13 |
| T10 | GitHub/GitLab backends in `wayfinder-ticket` per the Backends mapping (advisory claims, `release --force`, `trailer` releasing before a restart line, `merged`'s forge fallback (`gh pr list` / `glab mr list`), `glab` looked up on `PATH`), cases added to `tests/wayfinder-ticket.nix`; rewrite the GitHub/GitLab "Wayfinding operations" sections in the setup patch | AFK | T4, T13 |
| T11 | Codex parity: superpowers skill directories into `~/.codex/skills/` via `home/common/codex/default.nix`; extend `tests/llm-skills.nix` | AFK | T7, T9 |
| T12 | Manual end-to-end checklist (normal clone, linked worktree, bare clone; Claude and Codex; macOS and NixOS VM; a prototype ticket follows the T8 override; on Claude, ticket-mode brainstorming actually calls `EnterWorktree path=`, and only if the model refuses, T12 adds a narrowly scoped `claude/overrides/CLAUDE.md` line); update `docs/ai-workflow.md` status, repo `CLAUDE.md` and README | HITL | T6, T8, T10, T11, T13 |
| T13 | Real-sandbox check of the claim protocol after `just switch` on the Mac and the NixOS VM: process discovery, holder detaching, Esc interrupt, agent exit frees the lock, Codex keeps its process across `/clear`, whether Claude's `EnterWorktree` cwd survives `/clear` (if not, `trailer` prints the restart line for Claude too), whether `EnterWorktree path=` enters a ticket worktree made by `git worktree add`, whether a session there sees the main worktree's project rules and agents; fix in T2/T3 files if needed (the rules/agents symlink fallback lands in T9's brainstorming patch) | HITL | T3 |

T8 and T9 are HITL because their skill prose needs a human read before it ships. T12 and T13 are
HITL because they need interactive sessions on both machines.

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
  T12: End-to-end verification       → general-purpose   (manual)
  T13: Real-sandbox claim check      → general-purpose   (manual)
  Polish:                            → general-purpose   (mixed diff)
```
