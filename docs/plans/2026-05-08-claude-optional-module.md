# Claude as Optional Module + Shared LLM Infra

Refactor the Claude footprint into one optional module gated by a single `custom.claude.enable` switch, while extracting tool-neutral data (MCP servers, rules, skills, agents, commands) into shared `custom.llm.*` options that future LLM tooling modules (Codex, Gemini, etc.) can consume.

Default `custom.claude.enable = false`. Set to `true` in `hosts/common.nix` so both hosts keep working unchanged.

## Goals

1. One switch turns Claude (CLI, plugins, settings, security hooks, sandboxed wrapper, shell aliases, MCP integration paths) on or off.
2. Shared content (skill/agent/command/rule markdown files, MCP server definitions) lives in tool-neutral `custom.llm.*` options so a future Codex/Gemini consumer reuses it without copying.
3. Forking the repo on a host that doesn't enable Claude leaves no Claude artifacts on disk.

## Non-Goals

- Removing the `claude-code-plugins` flake input, the `"claude-code"` entry in `allowUnfreePredicate`, or the `claude-*` flake checks. These are evaluated outside any host config and cost nothing when no host enables Claude. Gating them would require a flake-level boolean (separate refactor).
- Generating Codex/Gemini configs in this PR. The `custom.llm.*` options are exposed; consumers ship later.
- Reformatting skill/agent/command files to a tool-neutral format. They keep their Claude-Code YAML frontmatter. A future consumer either accepts that format or adds a transformation step.

## Layered Layout

```
modules/
  options.nix                  # adds custom.claude.enable + custom.llm.* options
  claude-security/             # unchanged — still HM module gated by its own enable

home/common/
  llm/                         # NEW — tool-neutral data layer (always evaluated)
    default.nix                # imports below
    skills.nix                 # populates custom.llm.skills
    agents.nix                 # populates custom.llm.agents
    commands.nix               # populates custom.llm.commands
    rules.nix                  # populates custom.llm.rules
  mcp.nix                      # exposes custom.llm.mcpServers (data) + per-client configs

  claude/                      # claude consumer — gated by custom.claude.enable
    default.nix                # imports below + claude-security wiring
    settings.nix               # ~/.claude/settings.json
    plugins.nix                # ~/.claude/plugins/ (claude marketplace format)
    skills.nix                 # reads custom.llm.skills → ~/.claude/skills/
    agents.nix                 # reads custom.llm.agents + .commands → ~/.claude/{agents,commands}/
    rules.nix                  # reads custom.llm.rules → ~/.config/claude-rules/ + direnv fn

config/                        # static markdown lives here
  llm/                         # NEW — tool-neutral content store
    skills/                    # was config/claude/skills/
    agents/                    # was config/claude/agents/
    commands/                  # was config/claude-commands/
    rules/                     # was config/claude-rules/
  claude/                      # claude-specific content stays
    CLAUDE.md
    agent-overrides/           # wshobson plugin overrides — claude-plugin-coupled
  claude-plugins/              # custom claude plugins (rust-development) — claude-coupled
  direnv/
    claude-rules.sh            # writes to .claude/rules/ — claude-specific delivery
```

## Option Surface

In `modules/options.nix`:

```nix
custom.claude = {
  enable = lib.mkEnableOption "Claude Code (CLI, plugins, settings, security, sandbox, aliases, MCP integration)";
  # enabledPlugins stays declared in home/common/claude/plugins.nix (read-only)
};

let
  llmContentEntry = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        description = "Path (literal or store-path string) to the content.";
      };
      kind = lib.mkOption {
        type = lib.types.enum ["file" "directory"];
        default = "file";
        description = "'file' = single markdown file. 'directory' = multi-file content tree (e.g. SKILL.md plus helpers).";
      };
    };
  };
in {
  custom.llm = {
    skills   = lib.mkOption { type = lib.types.attrsOf llmContentEntry; default = {}; };
    agents   = lib.mkOption { type = lib.types.attrsOf llmContentEntry; default = {}; };
    commands = lib.mkOption { type = lib.types.attrsOf llmContentEntry; default = {}; };
    rules    = lib.mkOption { type = lib.types.attrsOf llmContentEntry; default = {}; };
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Tool-neutral MCP server definitions. Per-client configs (claude desktop/code, codex, gemini) read this and transform.";
    };
  };
}
```

In `hosts/common.nix`:

```nix
custom.claude.enable = true;
```

## File-by-File Changes

### Tool-neutral data layer (always evaluated, no `home.file` writes)

**NEW `home/common/llm/skills.nix`** — moves skill source paths out of `home/common/claude/skills.nix` into `custom.llm.skills`:

```nix
custom.llm.skills = {
  humanizer.source = "${inputs.humanizer}/SKILL.md";
  napkin.source = "${inputs.napkin}/SKILL.md";
  concise.source = ../../../config/llm/skills/concise.md;
  post-implementation-polish.source = ../../../config/llm/skills/post-implementation-polish.md;
  improve-codebase-architecture = {
    source = "${patchedMattpocockSkills}/skills/engineering/improve-codebase-architecture";
    kind = "directory";
  };
};
```

`kind` defaults to `"file"`, so single-file entries stay terse with `name.source = …`. Only the Mattpocock skill (which ships as a tree) needs the explicit `kind = "directory"` override. Same shape applies to `agents`, `commands`, `rules` (all `file` today).

**NEW `home/common/llm/agents.nix`** — moves agent source paths out of `home/common/claude/rules.nix` into `custom.llm.agents`. The `bevyEngineerAgent` derivation (which appends the migration gist) stays here since it's content prep, not delivery.

**NEW `home/common/llm/commands.nix`** — populates `custom.llm.commands` with all 10 command files in `config/claude-commands/`. Today's `home/common/claude/rules.nix` only wires up 8; `forget.md` and `reflect.md` (ferrex slash-command wrappers added in `dc64a8b`) are unwired by oversight. The refactor delivers them.

**NEW `home/common/llm/rules.nix`** — populates `custom.llm.rules` with the 5 language rule files.

**NEW `home/common/llm/default.nix`** — imports the four files above.

`home/common/default.nix` adds `./llm` to its imports list (always-on, before claude consumer).

### Claude consumer (gated by `custom.claude.enable`)

**`home/common/claude/default.nix`** — wraps `programs.claude-code.security = { ... }` in `lib.mkIf cfg.enable`. Splits into smaller files: imports add `./skills.nix` and `./agents.nix` (both new — extracted from current `rules.nix`).

**`home/common/claude/skills.nix`** — replaces current contents. Branches on `kind` to handle the directory case:

```nix
{ config, lib, ... }: let cfg = config.custom; in {
  config = lib.mkIf cfg.claude.enable {
    home.file = lib.mapAttrs' (name: entry: {
      name =
        if entry.kind == "directory"
        then ".claude/skills/${name}"
        else ".claude/skills/${name}/SKILL.md";
      value.source = entry.source;
    }) cfg.llm.skills;
  };
}
```

The `kind` field is part of the shared schema so future Codex/Gemini consumers can read it without re-deriving file-vs-directory from disk. `improve-codebase-architecture` is the only `kind = "directory"` entry today.

**`home/common/claude/agents.nix`** — NEW, extracted from current `rules.nix`. Reads `custom.llm.agents` and `custom.llm.commands`, writes to `.claude/agents/<n>.md` and `.claude/commands/<n>.md`. Gated by `lib.mkIf cfg.claude.enable`.

**`home/common/claude/rules.nix`** — slimmed down. Reads `custom.llm.rules`, writes to `.config/claude-rules/<n>.md`. Keeps the direnv function file. Keeps `.claude/CLAUDE.md`. Gated.

**`home/common/claude/settings.nix`** — wraps both `.claude/settings.json` and `.claude/settings.local.json` writes in `lib.mkIf cfg.claude.enable`. The statusline script and parry hook references stay.

**`home/common/claude/plugins.nix`** — wraps the `config = { ... }` block in `lib.mkIf cfg.claude.enable`. The `custom.claude.enabledPlugins` option declaration stays unconditional and gains `default = {};` so a stray reader can't error when claude is disabled — the only consumer today (`settings.nix`) is itself gated, but the default is cheap insurance against a future reader that forgets to gate.

### Other consumers

**`home/common/packages.nix`** — wraps `pkgs.claude-code` and `pkgs.claude_formatter` with `lib.optionals cfg.claude.enable`.

**`home/common/shell.nix`** — moves the 6 claude aliases inside `lib.optionalAttrs config.custom.claude.enable (let claudeSandboxed = ...; in { ... })`. The let-binding lazy-evaluates so disabling claude doesn't error on the missing `sandboxedPackages.claude` attribute.

**`home/common/mcp.nix`** — extends with a tool-neutral `custom.llm.mcpServers` attrset (data only, no transforms). Gates only the per-client file writes (Claude Desktop's `claude_desktop_config.json` lives in `home/darwin/default.nix`; Claude Code's `managed-mcp.json` lives in `system/nixos/default.nix`). `commonPrograms`/`commonServers` definitions and the `desktopMcpServersConfig`/`codeMcpServersConfig` `readOnly` options stay always-evaluated and populated — `readOnly` options can't be conditionally assigned cleanly, and the cost of generating the JSON paths is zero unless they're delivered. The `~/.config/mcphub/servers.json` write is removed (dead — `mcphub.nvim` is not installed; see Pre-step).

**`home/darwin/sandboxed.nix`** — wraps `claudeDarwin` definition + assignment in `lib.mkIf cfg.claude.enable`. Other sandboxed packages unaffected.

**`home/linux/sandboxed.nix`** — same pattern.

**`home/darwin/default.nix`** — wraps the `~/Library/Application Support/Claude/claude_desktop_config.json` `home.file` entry in `lib.mkIf`.

**`system/darwin/activation.nix`** — branches on `hmCfg.claude.enable`. When enabled, runs the existing `mkdir -p` + `ln -sf` for `/Library/Application Support/{Claude,ClaudeCode}/`. When disabled, runs `rm -f` against both symlink paths so a host that previously enabled claude doesn't leak stale symlinks after toggling off (Home Manager's link-generation cleanup only covers `home.file`, not nix-darwin activation scripts).

**`system/darwin/homebrew.nix`** — gates the `"claude"` cask (Claude Desktop app) via `lib.optionals hmCfg.claude.enable ["claude"]`. Without this, disabling claude still installs `/Applications/Claude.app`, which violates Goal 3.

**`system/nixos/default.nix`** — wraps `environment.etc."claude-code/managed-mcp.json"` in `lib.mkIf hmCfg.claude.enable`. NixOS prunes obsolete `environment.etc` entries on activation, so no manual cleanup needed.

### File moves under `config/`

```
config/claude/skills/concise.md                     → config/llm/skills/concise.md
config/claude/skills/post-implementation-polish.md  → config/llm/skills/post-implementation-polish.md
config/claude/agents/bevy-engineer.md               → config/llm/agents/bevy-engineer.md
config/claude/agents/rust-engineer.md               → config/llm/agents/rust-engineer.md
config/claude/agents/solana-developer.md            → config/llm/agents/solana-developer.md
config/claude-commands/*.md  (10 files)             → config/llm/commands/*.md
config/claude-rules/*.md     (5 files)              → config/llm/rules/*.md
```

Stays put:
```
config/claude/CLAUDE.md                  # claude-specific path
config/claude/agent-overrides/*.md       # wshobson plugin overrides
config/claude-plugins/rust-development/  # claude plugin format
config/direnv/claude-rules.sh            # claude-specific delivery (.claude/rules/)
config/claude/hooks/                     # empty — delete
scripts/statusline.sh                    # claude-specific
```

`config/claude/hooks/` is empty — delete it.

Update all Nix references (`home/common/claude/{rules,skills}.nix` and the new `home/common/llm/*.nix`) to point at the new paths.

## What stays as-is (intentional)

- `flake.nix` — `claude-code-plugins` input, `"claude-code"` in `allowUnfreePredicate`, the `claude-security` / `claude-settings` / `claude_formatter.passthru.tests` checks. These are flake-eval-time and can't read host config. Cost is zero unless a host installs claude.
- `overlays/packages.nix` — `claude_formatter` overlay. Only built when referenced.
- `tests/claude-security.nix`, `tests/claude-settings.nix`, `tests/check-bash-matcher.nix`, `tests/xdg-config-paths.nix` — validate module logic independent of host enable state. (`xdg-config-paths.nix` only imports `options.nix` + `xdg.nix`.)
- `scripts/git-meta.sh` — references `.claude/` as a default sync path. Harmless when `.claude/` doesn't exist.

## Implementation Steps

Sequential — each step leaves the tree green (`just check` + `just switch` succeed).

0. **Pre-step: drop dead mcphub references.** `mcphub.nvim` is not installed (only references are the writer itself and a stale `bind_ro`). Delete:
   - `home.file."${config.xdg.configHome}/mcphub/servers.json"` write in `home/common/mcp.nix`.
   - `bind_ro "$HOME/.config/mcphub"` line in `home/linux/sandboxed.nix`.

   Separate commit, unrelated to the rest of the refactor. Verify `just switch` succeeds and `~/.config/mcphub/` is no longer linked.

1. **Move static content** under `config/`. Just `mv`. Update referencing Nix files in the same commit. Verify `just switch` still produces a byte-identical settings.json (no Nix logic changes yet).

2. **Add `custom.llm.*` options** to `modules/options.nix`. Just option declarations, no consumers yet. `just check` should pass.

3. **Create `home/common/llm/`** with skills/agents/commands/rules data files populating the new options. Add `./llm` to `home/common/default.nix` imports. The options are now populated but not consumed. Existing `home/common/claude/{skills,rules}.nix` still write the same files. `just switch` should still produce the same outputs.

4. **Migrate claude consumer to read `custom.llm.*`**. Refactor `home/common/claude/{skills,rules}.nix` to map over the option attrsets. Split `rules.nix` into `agents.nix` (agents+commands) and a slimmed `rules.nix` (language rules + direnv + CLAUDE.md). Verify byte-identical settings.json and identical file tree under `~/.claude/`.

5. **Add `custom.claude.enable` option** + set `true` in `hosts/common.nix`. No gates yet — option declared but unused. `just check` passes.

6. **Wire gates** across the consumer files: `home/common/claude/*`, `home/common/packages.nix`, `home/common/shell.nix`, `home/common/mcp.nix`, `home/{darwin,linux}/sandboxed.nix`, `home/darwin/default.nix`, `system/darwin/activation.nix`, `system/darwin/homebrew.nix`, `system/nixos/default.nix`. With `enable = true` set in common, `just switch` produces identical output.

7. **Verify the off path**: temporarily set `custom.claude.enable = false;` (don't commit), run `just switch` **on a fresh-state host** (or run twice — once to clear any previously-managed paths, then re-verify). Confirm:
   - No `~/.claude/` directory created.
   - No `~/.config/claude-rules/` directory.
   - No claude binary in `$PATH`.
   - No `a`/`ap`/`ar`/`au`/`aup`/`aur` aliases.
   - No `/Library/Application Support/Claude*` symlinks (macOS) — the activation script's `rm -f` branch removes these on toggle-off.
   - No `/Applications/Claude.app` (macOS) — Homebrew cask is gated.
   - No `/etc/claude-code/` (NixOS) — pruned automatically by NixOS activation.
   - `just check` still passes.
   Revert to `enable = true;`, commit.

8. **Add tests** (optional, follow-up): a flake check that evaluates the HM module with `custom.claude.enable = false` and asserts the resulting `home.file` set contains no `.claude/` or `.config/claude-rules/` keys.

## Risks / Trade-offs

- **Skills/agents/commands are Claude-Code-format-coupled.** YAML frontmatter (`name`, `description`, `tools`) is Claude Code's convention. A future Codex/Gemini consumer reading `custom.llm.skills` either accepts that format or adds a transform. Documented as a non-goal — abstraction is "shared file store," not "shared schema."
- **`custom.llm.*` content packaging mixes single-file and directory entries** (`improve-codebase-architecture` ships as a tree; everything else is single-file). Resolved via the shared `llmContentEntry` submodule (`source` + `kind = "file" | "directory"`). Alternative considered: keep `attrsOf (either path str)` and branch on `lib.pathIsDirectory` in each consumer — rejected because every future consumer (Codex, Gemini) would re-derive the same fact from disk; encoding it in the schema makes the data layer self-documenting and lets consumers pre-filter by `kind`.
- **Indirection cost.** Adds a data layer that today only Claude reads. About 5 small files (~50 LOC). Worth it given the user's stated intent to add Codex/Gemini consumers.
- **No flake-level toggle.** `claude-code-plugins` input + unfree allowlist + flake checks always evaluated. Acceptable per non-goals.

## Validation Checklist

- [ ] `just check` passes before and after.
- [ ] `just switch` on `burnedapple` produces byte-identical `~/.claude/settings.json` before and after the refactor (with `enable = true`).
- [ ] `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/commands/`, `~/.config/claude-rules/` contain the same files before and after.
- [ ] With `custom.claude.enable = false` (test only, don't commit), no claude artifacts land on disk. Specifically check: `~/.claude/`, `~/.config/claude-rules/`, `/Applications/Claude.app`, `/Library/Application Support/Claude*` symlinks, `/etc/claude-code/`, claude binary in `$PATH`.
- [ ] `nix flake check` passes (the existing `claude-security` and `claude-settings` checks still validate).
- [ ] `git meta diff` shows no unexpected changes to managed `.claude/` content.

## Execution Strategy

**Subagents** (default). Steps are sequential — each builds on the previous and depends on it for the green-tree invariant. Single-task plan, no parallelism opportunities.

## Task Dependency Graph

| Task | Predecessors | Tag |
|---|---|---|
| 0. Drop dead mcphub references | none | AFK |
| 1. Move static content under config/ | 0 | AFK |
| 2. Add custom.llm.* options | 1 | AFK |
| 3. Create home/common/llm/ data layer | 2 | AFK |
| 4. Migrate claude consumer to read custom.llm.* | 3 | AFK |
| 5. Add custom.claude.enable + set true in hosts/common.nix | 4 | AFK |
| 6. Wire gates across consumers | 5 | AFK |
| 7. Verify off path manually | 6 | HITL |
| 8. (optional) Add eval-time test | 6 | AFK |

## Agent Assignments

```
Task 0: Drop dead mcphub references       → general-purpose      (Nix)
Task 1: Move config/ content              → general-purpose      (Nix + file moves)
Task 2: Add custom.llm.* options          → general-purpose      (Nix)
Task 3: Create home/common/llm/           → general-purpose      (Nix)
Task 4: Migrate claude consumer           → general-purpose      (Nix)
Task 5: Add custom.claude.enable          → general-purpose      (Nix)
Task 6: Wire gates                        → general-purpose      (Nix)
Task 7: Verify off path                   → human                (manual check)
Task 8: Add eval test                     → general-purpose      (Nix)
Polish:                                   → general-purpose      (uniform Nix diff)
```
