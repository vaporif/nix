{
  pkgs,
  lib,
  blockedCommands,
  blockedSubcommands,
  deniedSubcommands,
  blockedPatterns,
  notificationSound,
  ntfyServerUrl,
  ntfyTopicFile,
  ntfyEnabled,
}: let
  blockedCommandsStr = builtins.concatStringsSep " " blockedCommands;

  # Convert pipe patterns to grep-compatible regexes
  # "curl|sh" becomes "curl.*\|.*sh"
  patternToRegex = pattern: let
    parts = builtins.split "\\|" pattern;
    source = builtins.elemAt parts 0;
    sink = builtins.elemAt parts 2;
  in "${source}.*\\|.*${sink}";

  # blockedSubcommands as newline-separated "command subcommand [flags]" entries
  blockedSubcommandsStr = builtins.concatStringsSep "\n" blockedSubcommands;
  deniedSubcommandsStr = builtins.concatStringsSep "\n" deniedSubcommands;

  blockedPatternsStr = builtins.concatStringsSep "\n" (map patternToRegex blockedPatterns);

  checkBashCommandSrc =
    builtins.replaceStrings
    ["@blockedCommands@" "@blockedSubcommands@" "@deniedSubcommands@" "@blockedPatterns@"]
    [blockedCommandsStr blockedSubcommandsStr deniedSubcommandsStr blockedPatternsStr]
    (builtins.readFile ./check-bash-command.sh);

  notifySrc =
    builtins.replaceStrings
    ["@sound@" "@ntfyServerUrl@" "@ntfyTopicFile@" "@ntfyEnabled@"]
    [
      notificationSound
      ntfyServerUrl
      (
        if ntfyTopicFile != null
        then toString ntfyTopicFile
        else ""
      )
      (lib.boolToString ntfyEnabled)
    ]
    (builtins.readFile ./notify.sh);
in {
  # writeShellScriptBin (not writeShellApplication) because:
  # - writeShellApplication adds set -euo pipefail which breaks these scripts
  # - shfmt pipeline uses 2>/dev/null and relies on non-zero exits for fallback
  # - notify.sh osascript fails on Linux (expected, not an error)
  # symlinkJoin + makeWrapper prepends runtimeInputs to PATH
  check-bash-command = let
    script = pkgs.writeShellScriptBin "claude-check-bash-command" checkBashCommandSrc;
  in
    pkgs.symlinkJoin {
      name = "claude-check-bash-command";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-check-bash-command \
          --prefix PATH : ${lib.makeBinPath [pkgs.shfmt pkgs.jq pkgs.coreutils pkgs.gawk]}
      '';
    };

  notify = let
    script = pkgs.writeShellScriptBin "claude-notify" notifySrc;
  in
    pkgs.symlinkJoin {
      name = "claude-notify";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-notify \
          --prefix PATH : ${lib.makeBinPath [pkgs.jq pkgs.curl]}
      '';
    };
}
