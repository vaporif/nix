{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.runCommand "wayfinder-ticket-test" {
    nativeBuildInputs = [pkgs.bash pkgs.git pkgs.coreutils pkgs.procps pkgs.flock pkgs.util-linux];
  } ''
    export WT=${lib.getExe pkgs.wayfinder-ticket}
    export BCLONE=${../scripts/git-bare-clone.sh}
    export WT_COMMANDS="${lib.concatStringsSep " " (import ./wayfinder-commands.nix)}"
    bash ${./wayfinder-ticket}/run.sh
    touch $out
  ''
