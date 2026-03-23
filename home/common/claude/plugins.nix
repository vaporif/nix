{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  claudePluginsBase = ".claude/plugins/marketplaces";
  nixPluginsPath = "${claudePluginsBase}/nix-plugins";

  patchPlugin = src: name:
    pkgs.runCommand "claude-plugin-${name}" {} ''
      cp -r ${src}/plugins/${name} $out
      chmod -R u+w $out
      find $out -name '*.sh' -exec sed -i '1s|#!/bin/bash|#!/usr/bin/env bash|' {} \;
    '';

  patchedSuperpowers = pkgs.applyPatches {
    name = "superpowers-patched";
    src = inputs.superpowers;
    patches = [../../../patches/superpowers-customizations.patch];
  };

  patchedWshobsonAgents = pkgs.applyPatches {
    name = "wshobson-agents-patched";
    src = inputs.wshobson-agents;
    patches = [../../../patches/systems-programming-go-only.patch];
  };

  readPluginVersion = src:
    (builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/plugin.json")).version or "unknown";

  officialPlugin = patchPlugin inputs.claude-code-plugins;
  wshobsonPlugin = patchPlugin inputs.wshobson-agents;
  patchedWshobsonPlugin = patchPlugin patchedWshobsonAgents;

  plugins = [
    {
      name = "feature-dev";
      description = "Comprehensive feature development workflow";
      source = officialPlugin "feature-dev";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/feature-dev";
    }
    {
      name = "ralph-loop";
      description = "Iterative development loops";
      source = officialPlugin "ralph-loop";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/ralph-loop";
    }
    {
      name = "code-review";
      description = "Multi-agent PR code review";
      source = officialPlugin "code-review";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/code-review";
    }
    {
      name = "skill-creator";
      description = "Create, test, and optimize Claude Code skills";
      source = officialPlugin "skill-creator";
      version = readPluginVersion "${inputs.claude-code-plugins}/plugins/skill-creator";
    }
    {
      name = "superpowers";
      description = "Core skills: TDD, debugging, collaboration patterns";
      source = patchedSuperpowers;
      version = readPluginVersion inputs.superpowers;
    }
    # {
    #   name = "visual-explainer";
    #   description = "Generate HTML pages for diagrams, diff reviews, plan reviews, and data tables";
    #   source = inputs.visual-explainer;
    #   version = readPluginVersion inputs.visual-explainer;
    # }
    {
      name = "systems-programming";
      description = "Go agent with concurrency patterns";
      source = patchedWshobsonPlugin "systems-programming";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/systems-programming";
    }
    {
      name = "security-scanning";
      description = "STRIDE threat modeling, SAST, dependency scanning, security hardening";
      source = wshobsonPlugin "security-scanning";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/security-scanning";
    }
    {
      name = "git-pr-workflows";
      description = "PR enhancement, git workflow automation, repo onboarding";
      source = wshobsonPlugin "git-pr-workflows";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/git-pr-workflows";
    }
    {
      name = "blockchain-web3";
      description = "Solidity security, DeFi protocols, NFT standards, Web3 testing";
      source = wshobsonPlugin "blockchain-web3";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/blockchain-web3";
    }
    {
      name = "agent-teams";
      # heaviest plugin: ~250 tokens in system prompt (17 skills/commands/agents)
      description = "Multi-agent team orchestration for parallel review, debugging, and development";
      source = wshobsonPlugin "agent-teams";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/agent-teams";
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
in {
  options.custom.claude.enabledPlugins = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Map of enabled plugin names for settings.json";
  };

  config = {
    custom.claude.enabledPlugins = enabledPlugins;

    home.file =
      {
        "${nixPluginsPath}/.claude-plugin/marketplace.json".text = nixPluginsMarketplace;
        ".claude/plugins/installed_plugins.json".text = installedPlugins;
        ".claude/plugins/known_marketplaces.json".text = knownMarketplaces;
      }
      // pluginFiles;
  };
}
