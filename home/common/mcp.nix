{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;

  serenaPatched = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.serena.overrideAttrs (_: {
    version = "0.1.4-unstable-2025-12-28";
    src = pkgs.fetchFromGitHub {
      owner = "vaporif";
      repo = "serena";
      rev = "16c2124feb9a3cc242cc1583e70cb13f75cb8603";
      hash = "sha256-nozcdXVBHlHTtnXvJACC2M3Bat9oT1WEgVYP47SfrQ4=";
    };
  });

  mcp-nixos-package = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;

  youtube-mcp-server = pkgs.callPackage ../../mcp/youtube-mcp-server.nix {};

  mcpConfig = {
    programs = {
      filesystem = {
        enable = true;
        args = [
          "${homeDir}/Documents"
          cfg.configPath
          "${homeDir}/.cargo"
          "${homeDir}/go"
          "/nix/store"
          "${homeDir}/.config"
          "${homeDir}/.local/share"
        ];
      };
      git.enable = true;
      sequential-thinking.enable = true;
      time = {
        enable = true;
        args = ["--local-timezone" cfg.timezone];
      };
      context7.enable = true;
      memory.enable = true;
      serena = {
        enable = true;
        package = serenaPatched;
        context = "claude-code";
        enableWebDashboard = true;
        extraPackages =
          cfg.lspPackages
          ++ (with pkgs; [
            rust-analyzer
            gopls
          ]);
      };
      deepl = {
        enable = true;
        passwordCommand = {
          DEEPL_API_KEY = ["cat" "/run/secrets/deepl-key"];
        };
      };
      qdrant = {
        enable = true;
        env = {
          QDRANT_URL = "http://localhost:6333";
          COLLECTION_NAME = "claude-memory";
          FASTEMBED_CACHE_PATH = "${homeDir}/.cache/fastembed";
        };
      };
    };
    settings.servers = {
      github = {
        command = "${pkgs.writeShellScript "github-mcp-wrapper" ''
          export GITHUB_PERSONAL_ACCESS_TOKEN="$(${lib.getExe pkgs.gh} auth token)"
          exec ${lib.getExe pkgs.github-mcp-server} stdio
        ''}";
      };
      tavily = {
        command = "${pkgs.writeShellScript "tavily-mcp-wrapper" ''
          export TAVILY_API_KEY="$(cat /run/secrets/tavily-key)"
          exec ${inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.tavily-mcp}/bin/tavily-mcp
        ''}";
      };
      nixos = {
        command = "${mcp-nixos-package}/bin/mcp-nixos";
      };
      youtube = {
        command = "${pkgs.writeShellScript "youtube-mcp-wrapper" ''
          export YOUTUBE_API_KEY="$(cat /run/secrets/youtube-key)"
          exec ${lib.getExe youtube-mcp-server}
        ''}";
      };
      serena.args = lib.mkAfter ["--project-from-cwd"];
    };
  };

  mcpServersConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs mcpConfig;
in {
  options.custom.mcpServersConfig = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    description = "Generated MCP servers config file";
  };

  config = {
    custom.mcpServersConfig = mcpServersConfig;
    home.file."${config.xdg.configHome}/mcphub/servers.json".source = mcpServersConfig;
  };
}
