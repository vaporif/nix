{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;

  mcp-nixos-package = pkgs.mcp-nixos;

  ferrex-package = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;

  youtube-mcp-package = inputs.mcp-youtube.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Shared programs used by both Desktop and Code
  commonPrograms = {
    context7.enable = true;
  };

  # Shared custom servers used by both Desktop and Code
  commonServers =
    {
      github = {
        command = "${pkgs.writeShellScript "github-mcp-wrapper" ''
          export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-$(${lib.getExe pkgs.gh} auth token)}"
          exec ${lib.getExe pkgs.github-mcp-server} stdio
        ''}";
      };
      nixos = {
        command = lib.getExe mcp-nixos-package;
      };
    }
    // lib.optionalAttrs cfg.qdrant.enable {
      ferrex = {
        command = "${pkgs.writeShellScript "ferrex-mcp-wrapper" ''
          export FERREX_LOG=debug
          export FERREX_LOG_FILE="${homeDir}/.ferrex/ferrex.log"
          exec ${lib.getExe' ferrex-package "ferrex"} \
            --qdrant-url "${
            if pkgs.stdenv.isDarwin
            then "http://localhost:6334"
            else "http://${cfg.hostGatewayIp}:6334"
          }" \
            --db-path "${homeDir}/.ferrex/ferrex.db"
        ''}";
      };
    }
    // lib.optionalAttrs (cfg.secrets.tavily-key != null) {
      tavily = {
        command = "${pkgs.writeShellScript "tavily-mcp-wrapper" ''
          export TAVILY_API_KEY="''${TAVILY_API_KEY:-$(cat ${cfg.secrets.tavily-key})}"
          exec ${lib.getExe inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.tavily-mcp}
        ''}";
      };
    }
    // lib.optionalAttrs (cfg.gitlab.enable && cfg.secrets.gitlab-token != null && cfg.secrets.gitlab-api-url != null) {
      gitlab = {
        command = "${pkgs.writeShellScript "gitlab-mcp-wrapper" ''
          export GITLAB_PERSONAL_ACCESS_TOKEN="''${GITLAB_PERSONAL_ACCESS_TOKEN:-$(cat ${cfg.secrets.gitlab-token})}"
          export GITLAB_API_URL="''${GITLAB_API_URL:-$(cat ${cfg.secrets.gitlab-api-url})}"
          export GITLAB_READ_ONLY_MODE=true
          exec ${lib.getExe pkgs.gitlab-mcp}
        ''}";
      };
    };

  # Desktop-only programs
  desktopOnlyPrograms = {
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
    sequential-thinking.enable = true;
    time = {
      enable = true;
      args = ["--local-timezone" cfg.timezone];
    };
  };

  # Desktop-only custom servers
  desktopOnlyServers = lib.optionalAttrs (cfg.secrets.youtube-key != null) {
    youtube = {
      command = "${pkgs.writeShellScript "youtube-mcp-wrapper" ''
        export YOUTUBE_API_KEY="$(cat ${cfg.secrets.youtube-key})"
        exec ${lib.getExe youtube-mcp-package}
      ''}";
    };
  };

  # unity-mcp is intentionally NOT a stdio server here. Claude Code spawns stdio
  # MCP servers inside the macOS seatbelt sandbox, which denies reads of
  # ~/.unity-mcp (where Unity writes its instance status files), so stdio
  # discovery always found 0 instances. Instead it runs as a standalone HTTP
  # server (launchd agent in home/darwin/default.nix) that discovers instances
  # via the plugin's WebSocket hub — no filesystem scan, so the sandbox is
  # irrelevant. The enterprise managed-mcp.json has exclusive control over MCP
  # servers, so the HTTP entry is injected into the generated config below.

  # Claude Desktop: all servers
  desktopMcpConfig = {
    programs = commonPrograms // desktopOnlyPrograms;
    settings.servers = commonServers // desktopOnlyServers;
  };

  # Claude Code: dev-focused servers only
  codeMcpConfig = {
    programs = commonPrograms;
    settings.servers = commonServers;
  };

  desktopMcpModule = inputs.mcp-servers-nix.lib.evalModule pkgs desktopMcpConfig;
  codeMcpModule = inputs.mcp-servers-nix.lib.evalModule pkgs codeMcpConfig;
  desktopMcpServersConfig = desktopMcpModule.config.configFile;

  # On darwin, inject the unity-mcp HTTP entry pointing at the launchd-managed
  # standalone server (see the note above). The server default port is 8080 and
  # FastMCP serves the MCP protocol at /mcp.
  codeMcpServersConfig =
    if pkgs.stdenv.isDarwin
    then
      pkgs.runCommand "managed-mcp.json" {} ''
        ${lib.getExe pkgs.jq} \
          '.mcpServers["unity-mcp"] = {type: "http", url: "http://127.0.0.1:8080/mcp"}' \
          ${codeMcpModule.config.configFile} > $out
      ''
    else codeMcpModule.config.configFile;
  codexMcpServers = lib.mapAttrs (name: server:
    lib.filterAttrs (_: value: value != null && value != {}) {
      command = server.command or null;
      args = server.args or [];
      env = server.env or {};
      env_vars = lib.optionals (name == "tavily") ["TAVILY_API_KEY"];
    })
  codeMcpModule.config.settings.servers;
in {
  options.custom = {
    desktopMcpServersConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Generated MCP servers config for Claude Desktop (all servers)";
    };
    codeMcpServersConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Generated MCP servers config for Claude Code (dev-focused servers)";
    };
    codexMcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Generated MCP server definitions for Codex config.toml (dev-focused servers)";
    };
  };

  config = {
    custom = {
      inherit desktopMcpServersConfig codeMcpServersConfig codexMcpServers;
    };
  };
}
