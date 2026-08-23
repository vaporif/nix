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

  # Rewrites the tab title on every state transition, so a background tab
  # shows whether that session is working, waiting on you, or done. `ps` is
  # for the pty lookup when the hook has no controlling terminal of its own;
  # on darwin the wrapper keeps the inherited PATH, which finds /bin/ps.
  tabStateScript = let
    script = pkgs.writeShellScriptBin "claude-tab-state" (builtins.readFile ../tab-state.sh);
  in
    pkgs.symlinkJoin {
      name = "claude-tab-state";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-tab-state \
          --prefix PATH : ${lib.makeBinPath ([pkgs.jq pkgs.coreutils] ++ lib.optional pkgs.stdenv.isLinux pkgs.procps)}
      '';
    };

  tabState = cfg.claude.tabState.enable;

  tabStateHook = matcher: {
    inherit matcher;
    hooks = [
      {
        command = "${tabStateScript}/bin/claude-tab-state";
        type = "command";
      }
    ];
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
        preferredNotifChannel = "ghostty";
        alwaysThinkingEnabled = true;
        skipDangerousModePermissionPrompt = true;
        teammateMode = "tmux";
        enabledMcpjsonServers = ["unity-mcp"];
        inherit (cfg.claude) enabledPlugins;
        statusLine = {
          type = "command";
          command = "${statuslineScript}/bin/claude-statusline";
        };
        env =
          {
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          }
          // lib.optionalAttrs tabState {
            # The tab-state hooks own OSC 2; without this Claude keeps
            # repainting the title with the conversation topic.
            CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1";
          };
        hooks = {
          PreToolUse =
            sec.hooks.PreToolUse
            ++ lib.optionals isDarwin [
              (parryHook // {matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__.*";})
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
            ++ lib.optional tabState (tabStateHook "")
            ++ lib.optionals isDarwin [
              (parryHook // {matcher = "Read|WebFetch|Bash|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";})
            ];

          Notification = sec.hooks.Notification ++ lib.optional tabState (tabStateHook "");
          SessionStart = sec.hooks.SessionStart ++ lib.optional tabState (tabStateHook "");
          Stop = lib.optional tabState (tabStateHook "");
          SessionEnd = lib.optional tabState (tabStateHook "");
          UserPromptSubmit =
            sec.hooks.UserPromptSubmit
            ++ lib.optional tabState (tabStateHook "")
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
