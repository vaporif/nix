{
  config,
  pkgs,
  inputs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  claudePluginsBase = ".claude/plugins/marketplaces";
  nixPluginsPath = "${claudePluginsBase}/nix-plugins";

  patchPlugin = name:
    pkgs.runCommand "claude-plugin-${name}" {} ''
      cp -r ${inputs.claude-code-plugins}/plugins/${name} $out
      chmod -R u+w $out
      find $out -name '*.sh' -exec sed -i '1s|#!/bin/bash|#!/usr/bin/env bash|' {} \;
    '';

  patchedSuperpowers = pkgs.applyPatches {
    name = "superpowers-patched";
    src = inputs.superpowers;
    patches = [../../patches/superpowers-no-auto-commit.patch];
  };

  readPluginVersion = src:
    (builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/plugin.json")).version or "unknown";

  plugins = [
    {
      name = "feature-dev";
      description = "Comprehensive feature development workflow";
      source = patchPlugin "feature-dev";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/feature-dev";
    }
    {
      name = "ralph-loop";
      description = "Iterative development loops";
      source = patchPlugin "ralph-loop";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/ralph-loop";
    }
    {
      name = "code-review";
      description = "Multi-agent PR code review";
      source = patchPlugin "code-review";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/code-review";
    }
    {
      name = "skill-creator";
      description = "Create, test, and optimize Claude Code skills";
      source = patchPlugin "skill-creator";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/skill-creator";
    }
    {
      name = "superpowers";
      description = "Core skills: TDD, debugging, collaboration patterns";
      source = patchedSuperpowers;
      version = readPluginVersion inputs.superpowers;
    }
    {
      name = "visual-explainer";
      description = "Generate HTML pages for diagrams, diff reviews, plan reviews, and data tables";
      source = inputs.visual-explainer;
      version = readPluginVersion inputs.visual-explainer;
    }
  ];

  nixPluginsMarketplace = builtins.toJSON {
    "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
    name = "nix-plugins";
    description = "Nix-managed Claude Code plugins";
    owner = {
      name = "nix";
      email = "nix@localhost";
    };
    plugins =
      map (p: {
        inherit (p) name description;
        source = "./${p.name}";
      })
      plugins;
  };

  installedPlugins = builtins.toJSON {
    version = 2;
    plugins = builtins.listToAttrs (map (p: {
        name = "${p.name}@nix-plugins";
        value = [
          {
            scope = "user";
            installPath = "${homeDir}/${nixPluginsPath}/${p.name}";
            inherit (p) version;
            installedAt = "2025-01-01T00:00:00.000Z";
            lastUpdated = "2025-01-01T00:00:00.000Z";
          }
        ];
      })
      plugins);
  };

  pluginFiles = builtins.listToAttrs (map (p: {
      name = "${nixPluginsPath}/${p.name}";
      value.source = p.source;
    })
    plugins);

  enabledPlugins = builtins.listToAttrs (map (p: {
      name = "${p.name}@nix-plugins";
      value = true;
    })
    plugins);

  knownMarketplaces = builtins.toJSON {
    "claude-plugins-official" = {
      source = {
        source = "github";
        repo = "anthropics/claude-plugins-official";
      };
      installLocation = "${homeDir}/${claudePluginsBase}/claude-plugins-official";
      lastUpdated = "2025-01-01T00:00:00.000Z";
    };
    "nix-plugins" = {
      source = {
        source = "directory";
        path = "${homeDir}/${nixPluginsPath}";
      };
      installLocation = "${homeDir}/${nixPluginsPath}";
      lastUpdated = "2025-01-01T00:00:00.000Z";
    };
  };

  sec = config.programs.claude-code.security.settingsFragment;
in {
  imports = [../../modules/claude-security];

  programs.claude-code.security = {
    enable = true;
    hooks.notification.ntfy = {
      enable = true;
      topicFile = "/run/secrets/ntfy-topic";
    };
  };

  home.file =
    {
      "${nixPluginsPath}/.claude-plugin/marketplace.json".text = nixPluginsMarketplace;
      ".claude/plugins/installed_plugins.json".text = installedPlugins;
      ".claude/plugins/known_marketplaces.json".text = knownMarketplaces;

      ".claude/rules/nix.md".source = ../../config/claude-rules/nix.md;
      ".claude/rules/lua.md".source = ../../config/claude-rules/lua.md;
      ".claude/rules/rust.md".source = ../../config/claude-rules/rust.md;
      ".claude/rules/go.md".source = ../../config/claude-rules/go.md;
      ".claude/rules/solidity.md".source = ../../config/claude-rules/solidity.md;

      ".claude/commands/remember.md".source = ../../config/claude-commands/remember.md;
      ".claude/commands/recall.md".source = ../../config/claude-commands/recall.md;
      ".claude/commands/cleanup.md".source = ../../config/claude-commands/cleanup.md;
      ".claude/commands/commit.md".source = ../../config/claude-commands/commit.md;
      ".claude/commands/pr.md".source = ../../config/claude-commands/pr.md;
      ".claude/commands/docs.md".source = ../../config/claude-commands/docs.md;
      ".claude/commands/vulnix-triage.md".source = ../../config/claude-commands/vulnix-triage.md;

      ".claude/CLAUDE.md".source = ../../config/claude/CLAUDE.md;
      ".claude/settings.json".text = builtins.toJSON {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        alwaysThinkingEnabled = true;
        inherit enabledPlugins;
        statusLine = {
          type = "command";
          command = "${homeDir}/.claude/hooks/statusline.sh";
        };
        env = {
          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };
        hooks = {
          PreToolUse =
            sec.hooks.PreToolUse
            ++ [
              {
                hooks = [
                  {
                    command = "parry-guard hook";
                    type = "command";
                  }
                ];
                matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__.*";
              }
            ];
          PostToolUse = [
            {
              hooks = [
                {
                  command = "claude-formatter";
                  type = "command";
                }
              ];
              matcher = "Edit|Write";
            }
            {
              hooks = [
                {
                  command = "parry-guard hook";
                  type = "command";
                }
              ];
              matcher = "Read|WebFetch|Bash|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";
            }
          ];
          inherit (sec.hooks) Notification;
          UserPromptSubmit = [
            {
              hooks = [
                {
                  command = "parry-guard hook";
                  type = "command";
                }
                {
                  command = "${homeDir}/.claude/hooks/auto-recall.sh";
                  type = "command";
                }
              ];
              matcher = "";
            }
          ];
        };
        permissions = {
          inherit (sec.permissions) allow deny;
        };
      };
      ".claude/settings.local.json".text = builtins.toJSON {
        permissions = {
          allow = [];
          deny = [];
        };
      };
      ".claude/hooks/auto-recall.sh" = {
        source = ../../config/claude/hooks/auto-recall.sh;
        executable = true;
      };
      ".claude/hooks/statusline.sh" = {
        source = ../../scripts/statusline.sh;
        executable = true;
      };
    }
    // pluginFiles;
}
