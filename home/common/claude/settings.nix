{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;

  sec = config.programs.claude-code.security.settingsFragment;

  statuslineScript = let
    script = pkgs.writeShellScriptBin "claude-statusline" (builtins.readFile ../../../scripts/statusline.sh);
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
  home.file = {
    ".claude/settings.json".text = builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      alwaysThinkingEnabled = true;
      teammateMode = "tmux";
      inherit (config.custom.claude) enabledPlugins;
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
          ];
        PostToolUse =
          [
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
        inherit (sec.hooks) Notification;
        UserPromptSubmit = lib.optionals isDarwin [
          (parryHook // {matcher = "";})
        ];
      };
      permissions = {
        inherit (sec.permissions) allow deny;
      };
      sandbox = {
        filesystem = {
          allowWrite = ["~/.cache/vulnix"];
        };
      };
    };
    ".claude/settings.local.json".text = builtins.toJSON {
      permissions = {
        allow = [];
        deny = [];
      };
    };
  };
}
