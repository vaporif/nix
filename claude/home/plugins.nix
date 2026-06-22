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
    patches = [../../patches/superpowers-customizations.patch];
  };

  # Removes Rust/C/C++ agents + memory-safety skill from systems-programming
  # (Rust handled by standalone rust-engineer agent; C/C++ unused).
  # Uses runCommand instead of applyPatches so it survives upstream churn —
  # only file presence and the description string are touched.
  patchedWshobsonAgents = pkgs.runCommand "wshobson-agents-patched" {nativeBuildInputs = [pkgs.jq];} ''
    cp -r ${inputs.wshobson-agents} $out
    chmod -R u+w $out
    rm -f $out/plugins/systems-programming/agents/c-pro.md
    rm -f $out/plugins/systems-programming/agents/cpp-pro.md
    rm -f $out/plugins/systems-programming/agents/rust-pro.md
    rm -rf $out/plugins/systems-programming/skills/memory-safety-patterns
    plugin_json=$out/plugins/systems-programming/.claude-plugin/plugin.json
    jq '.description = "Go systems programming with concurrency patterns"' \
      "$plugin_json" > "$plugin_json.new"
    mv "$plugin_json.new" "$plugin_json"
  '';

  readPluginVersion = src: let
    json = builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/plugin.json");
  in
    json.version or "0.0.0";

  officialPlugin = patchPlugin inputs.claude-code-plugins;
  wshobsonPlugin = patchPlugin inputs.wshobson-agents;

  pythonProOnlyPlugin = pkgs.runCommand "claude-plugin-python-development" {} ''
    cp -r ${inputs.wshobson-agents}/plugins/python-development $out
    chmod -R u+w $out
    rm -f $out/agents/django-pro.md $out/agents/fastapi-pro.md
    rm -rf $out/skills $out/commands
    cp ${../overrides/agent-overrides/python-pro.md} $out/agents/python-pro.md
  '';

  systemsProgrammingPlugin = pkgs.runCommand "claude-plugin-systems-programming" {} ''
    cp -r ${patchedWshobsonAgents}/plugins/systems-programming $out
    chmod -R u+w $out
    cp ${../overrides/agent-overrides/golang-pro.md} $out/agents/golang-pro.md
  '';

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
    {
      name = "systems-programming";
      description = "Go agent with concurrency patterns";
      source = systemsProgrammingPlugin;
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/systems-programming";
    }
    {
      name = "python-development";
      description = "python-pro agent (Python 3.12+ with Pydantic v2 modern syntax)";
      source = pythonProOnlyPlugin;
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/python-development";
    }
    {
      name = "security-scanning";
      description = "STRIDE threat modeling, SAST, dependency scanning, security hardening";
      source = wshobsonPlugin "security-scanning";
      version = readPluginVersion "${inputs.wshobson-agents}/plugins/security-scanning";
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

  # Code-intelligence plugins for the native LSP tool. Each carries no skills/
  # agents — only an `lspServers` block in the marketplace entry. `command` is
  # pinned to an absolute store path (via getExe) so the server need not be on
  # PATH and its version is locked to this flake; the binary is pulled into the
  # closure by the string reference. Covers rust, go, lua, ts, python; sources
  # are the upstream LICENSE/README dirs (metadata lives in the marketplace).
  lspPlugins = map (p:
    p
    // {
      source = officialPlugin p.name;
      version = "1.0.0";
    }) [
    {
      name = "rust-analyzer-lsp";
      description = "Rust language server (rust-analyzer) for code intelligence";
      lspServers."rust-analyzer" = {
        command = lib.getExe pkgs.rust-analyzer;
        extensionToLanguage.".rs" = "rust";
      };
    }
    {
      name = "gopls-lsp";
      description = "Go language server (gopls) for code intelligence";
      lspServers.gopls = {
        command = lib.getExe pkgs.gopls;
        extensionToLanguage.".go" = "go";
      };
    }
    {
      name = "lua-lsp";
      description = "Lua language server for code intelligence";
      lspServers.lua = {
        command = lib.getExe pkgs.lua-language-server;
        extensionToLanguage.".lua" = "lua";
      };
    }
    {
      name = "typescript-lsp";
      description = "TypeScript/JavaScript language server for code intelligence";
      lspServers.typescript = {
        command = lib.getExe pkgs.typescript-language-server;
        args = ["--stdio"];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
          ".mts" = "typescript";
          ".cts" = "typescript";
          ".mjs" = "javascript";
          ".cjs" = "javascript";
        };
      };
    }
    {
      name = "pyright-lsp";
      description = "Python language server (basedpyright) for code intelligence";
      lspServers.pyright = {
        command = lib.getExe' pkgs.basedpyright "basedpyright-langserver";
        args = ["--stdio"];
        extensionToLanguage = {
          ".py" = "python";
          ".pyi" = "python";
        };
      };
    }
  ];

  allPlugins = plugins ++ lspPlugins;

  nixPluginsMarketplace = builtins.toJSON {
    "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
    name = "nix-plugins";
    description = "Nix-managed Claude Code plugins";
    owner = {
      name = "nix";
      email = "nix@localhost";
    };
    plugins = map (p:
      {
        inherit (p) name description;
        source = "./${p.name}";
      }
      // lib.optionalAttrs (p ? lspServers) {inherit (p) lspServers;})
    allPlugins;
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
      allPlugins);
  };

  pluginFiles = builtins.listToAttrs (map (p: {
      name = "${nixPluginsPath}/${p.name}";
      value.source = p.source;
    })
    allPlugins);

  # Plugins to keep installed but disabled (skills/commands/agents not loaded).
  # Toggle by adding/removing names here — no rebuild of plugin sources needed.
  disabledPlugins = [
    "blockchain-web3"
    "ralph-loop"
    "security-scanning"
  ];

  enabledPlugins = builtins.listToAttrs (map (p: {
      name = "${p.name}@nix-plugins";
      value = !(builtins.elem p.name disabledPlugins);
    })
    allPlugins);

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

  config = lib.mkIf config.custom.claude.enable {
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
