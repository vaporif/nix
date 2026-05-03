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
  checkBashCommandSrc =
    builtins.replaceStrings
    [
      "@blockedCommandsJson@"
      "@blockedSubcommandsJson@"
      "@deniedSubcommandsJson@"
      "@blockedPatternsJson@"
    ]
    [
      (builtins.toJSON blockedCommands)
      (builtins.toJSON blockedSubcommands)
      (builtins.toJSON deniedSubcommands)
      (builtins.toJSON blockedPatterns)
    ]
    (builtins.readFile ./check-bash-command.sh);
in {
  # writeShellApplication injects shebang + `set -euo pipefail` so the body
  # is fail-closed (any unset var or piped failure aborts the hook).
  check-bash-command = pkgs.writeShellApplication {
    name = "claude-check-bash-command";
    runtimeInputs = with pkgs; [jq shfmt coreutils gnugrep];
    text = checkBashCommandSrc;
  };

  # Same writeShellApplication treatment. /usr/bin/osascript is absolute
  # because cleanPATH won't find it and there's no nixpkgs equivalent.
  notify = pkgs.writeShellApplication {
    name = "claude-notify";
    runtimeInputs = [pkgs.jq pkgs.curl pkgs.coreutils];
    text =
      builtins.replaceStrings
      ["@sound@" "@ntfyEnabled@" "@ntfyTopicFile@" "@ntfyServerUrl@"]
      [
        notificationSound
        (lib.boolToString ntfyEnabled)
        (lib.optionalString (ntfyTopicFile != null) (toString ntfyTopicFile))
        ntfyServerUrl
      ]
      (builtins.readFile ./notify.sh);
  };

  # The remaining hooks need to swallow non-zero exits from their
  # internals (notably shfmt fallback paths), which `set -e` from
  # writeShellApplication wouldn't tolerate. symlinkJoin+makeWrapper
  # gives them a runtime PATH without the strict-mode wrapper.
  read-gate = let
    script = pkgs.writeShellScriptBin "claude-read-gate" (builtins.readFile ./read-gate.sh);
  in
    pkgs.symlinkJoin {
      name = "claude-read-gate";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-read-gate \
          --prefix PATH : ${lib.makeBinPath [pkgs.jq pkgs.coreutils]}
      '';
    };

  edit-track = let
    script = pkgs.writeShellScriptBin "claude-edit-track" (builtins.readFile ./edit-track.sh);
  in
    pkgs.symlinkJoin {
      name = "claude-edit-track";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-edit-track \
          --prefix PATH : ${lib.makeBinPath [pkgs.jq pkgs.coreutils]}
      '';
    };

  read-once-cleanup = let
    script = pkgs.writeShellScriptBin "claude-read-once-cleanup" (builtins.readFile ./read-once-cleanup.sh);
  in
    pkgs.symlinkJoin {
      name = "claude-read-once-cleanup";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-read-once-cleanup \
          --prefix PATH : ${lib.makeBinPath [pkgs.findutils pkgs.coreutils]}
      '';
    };
}
