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

  nixPluginsMarketplace = builtins.toJSON {
    "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
    name = "nix-plugins";
    description = "Nix-managed Claude Code plugins";
    owner = {
      name = "nix";
      email = "nix@localhost";
    };
    plugins = [
      {
        name = "feature-dev";
        description = "Comprehensive feature development workflow";
        source = "./feature-dev";
      }
      {
        name = "ralph-loop";
        description = "Iterative development loops";
        source = "./ralph-loop";
      }
      {
        name = "code-review";
        description = "Multi-agent PR code review";
        source = "./code-review";
      }
      {
        name = "superpowers";
        description = "Core skills: TDD, debugging, collaboration patterns";
        source = "./superpowers";
      }
    ];
  };

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
in {
  home.file = {
    "${nixPluginsPath}/.claude-plugin/marketplace.json".text = nixPluginsMarketplace;
    "${nixPluginsPath}/feature-dev".source = patchPlugin "feature-dev";
    "${nixPluginsPath}/ralph-loop".source = patchPlugin "ralph-loop";
    "${nixPluginsPath}/code-review".source = patchPlugin "code-review";
    "${nixPluginsPath}/superpowers".source = "${inputs.superpowers}";

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

    ".claude/CLAUDE.md".source = ../../config/claude/CLAUDE.md;
    ".claude/settings.json".text = builtins.replaceStrings ["@homeDir@"] [homeDir] (builtins.readFile ../../config/claude/settings.json);
    ".claude/settings.local.json".text = builtins.toJSON {
      permissions = {
        allow = [];
        deny = [];
      };
    };
    ".claude/hooks/check-bash-command.sh" = {
      source = ../../config/claude/hooks/check-bash-command.sh;
      executable = true;
    };
    ".claude/hooks/auto-recall.sh" = {
      source = ../../config/claude/hooks/auto-recall.sh;
      executable = true;
    };
    ".claude/hooks/notify.sh" = {
      source = ../../config/claude/hooks/notify.sh;
      executable = true;
    };
    ".claude/plugins/known_marketplaces.json".text = knownMarketplaces;
  };
}
