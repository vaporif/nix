{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.custom;
  homeDir = config.home.homeDirectory;

  # Strip Serena's ~700-token system prompt template. We use Serena only as an
  # MCP — each tool description already explains itself, so the agent-role
  # preamble (and the interactive/editing mode prompts it renders) are dead weight.
  serenaSystemPrompt = pkgs.writeText "system_prompt.yml" ''
    prompts:
      system_prompt: ""
  '';

  # LSP-only claude-code context: replaces upstream claude-code.yml so only
  # symbolic / LSP-backed tools are advertised. Keeps Serena from polluting
  # context with file/memory/onboarding/think tools that Claude Code already
  # covers natively (or that we cover via ferrex).
  serenaClaudeCodeContext = pkgs.writeText "claude-code.yml" ''
    description: Claude Code (LSP-only — symbolic tools only)
    prompt: ""

    excluded_tools:
      # already excluded upstream — kept here so the list is self-contained
      - create_text_file
      - read_file
      - execute_shell_command
      - prepare_for_new_conversation
      - replace_content
      # file/dir ops Claude Code handles natively
      - find_file
      - list_dir
      - delete_lines
      - replace_lines
      - insert_at_line
      # memory subsystem — superseded by ferrex
      - write_memory
      - read_memory
      - list_memories
      - delete_memory
      - edit_memory
      # onboarding / meta-prompting / dashboard noise
      - check_onboarding_performed
      - onboarding
      - think_about_collected_information
      - think_about_task_adherence
      - think_about_whether_you_are_done
      - summarize_changes
      - initial_instructions
      - open_dashboard
      - remove_project

    tool_description_overrides: {}

    single_project: true
  '';

  serenaPatched = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.serena.overrideAttrs (oldAttrs: {
    version = "0.1.4-unstable-2025-12-28";
    src = pkgs.fetchFromGitHub {
      owner = "vaporif";
      repo = "serena";
      rev = "16c2124feb9a3cc242cc1583e70cb13f75cb8603";
      hash = "sha256-nozcdXVBHlHTtnXvJACC2M3Bat9oT1WEgVYP47SfrQ4=";
    };
    postPatch =
      (oldAttrs.postPatch or "")
      + ''
        cp ${serenaClaudeCodeContext} src/serena/resources/config/contexts/claude-code.yml
        cp ${serenaSystemPrompt} src/serena/resources/config/prompt_templates/system_prompt.yml
      '';
  });

  mcp-nixos-package = pkgs.mcp-nixos;

  ferrex-package = inputs.ferrex.packages.${pkgs.stdenv.hostPlatform.system}.default;

  youtube-mcp-package = inputs.mcp-youtube.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Shared programs used by both Desktop and Code
  commonPrograms = {
    context7.enable = true;
    serena = {
      enable = true;
      package = serenaPatched;
      context = "claude-code";
      enableWebDashboard = true;
      extraPackages =
        cfg.lspPackages
        ++ [
          pkgs.rust-analyzer
          pkgs.gopls
        ];
    };
  };

  # Shared custom servers used by both Desktop and Code
  commonServers = {
    github = {
      command = "${pkgs.writeShellScript "github-mcp-wrapper" ''
        export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-$(${lib.getExe pkgs.gh} auth token)}"
        exec ${lib.getExe pkgs.github-mcp-server} stdio
      ''}";
    };
    tavily = {
      command = "${pkgs.writeShellScript "tavily-mcp-wrapper" ''
        export TAVILY_API_KEY="''${TAVILY_API_KEY:-$(cat ${cfg.secrets.tavily-key})}"
        exec ${lib.getExe inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system}.tavily-mcp}
      ''}";
    };
    nixos = {
      command = lib.getExe mcp-nixos-package;
    };
    ferrex = {
      command = "${pkgs.writeShellScript "ferrex-mcp-wrapper" ''
        export FERREX_LOG=debug
        export FERREX_LOG_FILE="${homeDir}/.ferrex/ferrex.log"
        exec ${lib.getExe' ferrex-package "ferrex"} \
          --qdrant-url "${
          if pkgs.stdenv.isDarwin
          then "http://localhost:6334"
          else "http://${cfg.utmGatewayIp}:6334"
        }" \
          --db-path "${homeDir}/.ferrex/ferrex.db"
      ''}";
    };
    serena.args = lib.mkAfter ["--project-from-cwd"];
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
  desktopOnlyServers = {
    youtube = {
      command = "${pkgs.writeShellScript "youtube-mcp-wrapper" ''
        export YOUTUBE_API_KEY="$(cat ${cfg.secrets.youtube-key})"
        exec ${lib.getExe youtube-mcp-package}
      ''}";
    };
  };

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

  desktopMcpServersConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs desktopMcpConfig;
  codeMcpServersConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs codeMcpConfig;
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
  };

  config = {
    custom = {
      inherit desktopMcpServersConfig codeMcpServersConfig;
    };
    home.file."${config.xdg.configHome}/mcphub/servers.json".source = codeMcpServersConfig;
  };
}
