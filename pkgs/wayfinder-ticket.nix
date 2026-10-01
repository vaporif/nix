{
  lib,
  writeShellApplication,
  git,
  flock,
  yq-go,
  coreutils,
  procps,
  util-linux,
  gh,
}:
writeShellApplication {
  name = "wayfinder-ticket";
  runtimeInputs = [git flock yq-go coreutils procps util-linux gh];
  text = lib.concatMapStrings builtins.readFile [
    ./wayfinder-ticket/lib.sh
    ./wayfinder-ticket/model.sh
    ./wayfinder-ticket/git.sh
    ./wayfinder-ticket/claim.sh
    ./wayfinder-ticket/commands.sh
    ./wayfinder-ticket/trailer.sh
    ./wayfinder-ticket/main.sh
  ];
}
