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
  # check-bash-command uses writeShellApplication for fail-closed posture
  # (set -euo pipefail). The script body deliberately omits its own shebang
  # and `set` lines because writeShellApplication injects them.
  check-bash-command = pkgs.writeShellApplication {
    name = "claude-check-bash-command";
    runtimeInputs = with pkgs; [jq shfmt coreutils gnugrep];
    text = checkBashCommandSrc;
  };

  # writeShellScriptBin (not writeShellApplication) for the rest because:
  # - notify.sh osascript fails on Linux (expected, not an error)
  # - shfmt pipeline uses 2>/dev/null and relies on non-zero exits for fallback
  # symlinkJoin + makeWrapper prepends runtimeInputs to PATH
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
