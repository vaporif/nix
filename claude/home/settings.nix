{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  inherit (pkgs.stdenv) isDarwin;

  sec = config.programs.claude-code.security.settingsFragment;

  statuslineScript = let
    script = pkgs.writeShellScriptBin "claude-statusline" (builtins.readFile ../statusline.sh);
  in
    pkgs.symlinkJoin {
      name = "claude-statusline";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-statusline \
          --prefix PATH : ${lib.makeBinPath [pkgs.jq pkgs.git pkgs.curl pkgs.coreutils pkgs.gawk pkgs.gnugrep]}
      '';
    };

  parryHook = {
    hooks = [
      {
        command = "parry-guard hook";
        type = "command";
      }
    ];
  };
in {
  config = lib.mkIf cfg.claude.enable {
    home.file = {
      ".claude/settings.json".text = builtins.toJSON {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        theme = "light";
        alwaysThinkingEnabled = true;
        skipDangerousModePermissionPrompt = true;
        teammateMode = "tmux";
        enabledMcpjsonServers = ["unity-mcp"];
        inherit (cfg.claude) enabledPlugins;
        statusLine = {
          type = "command";
          command = "${statuslineScript}/bin/claude-statusline";
        };
        env = {
          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };
        hooks = {
          PreToolUse =
            sec.hooks.PreToolUse
            ++ lib.optionals isDarwin [
              (parryHook // {matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__.*";})
            ]
            # rtk only returns "allow"; most-restrictive-wins keeps the guards above authoritative.
            # Bare "rtk" (not an absolute store path) so rtk's own self-detector recognises its
            # hook as installed — an abs path fails its first-token check and nags on every Bash
            # call. pkgs.rtk is on PATH under the same rtk.enable gate (cf. "parry-guard hook").
            ++ lib.optionals cfg.claude.rtk.enable [
              {
                matcher = "Bash";
                hooks = [
                  {
                    command = "rtk hook claude";
                    type = "command";
                  }
                ];
              }
            ];
          PostToolUse =
            sec.hooks.PostToolUse
            ++ [
              {
                hooks = [
                  {
                    command = "claude-formatter";
                    type = "command";
                  }
                ];
                matcher = "Edit|Write";
              }
            ]
            ++ lib.optionals isDarwin [
              (parryHook // {matcher = "Read|WebFetch|Bash|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";})
            ];

          inherit (sec.hooks) Notification SessionStart;
          UserPromptSubmit =
            sec.hooks.UserPromptSubmit
            ++ lib.optionals isDarwin [
              (parryHook // {matcher = "";})
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
    };
  };
}
