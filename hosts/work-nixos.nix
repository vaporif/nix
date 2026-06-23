{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "work-nixos";
    system = "aarch64-linux";
    configPath = "${config.custom.homeDir}/.config/nix";
    sshAgent = "";
    # The signing key is the personal Mac's Secretive key, whose private half
    # isn't on this box — drop it so git signing is off and it isn't an
    # authorized SSH key here.
    git.signingKey = "";
    stateVersion = "26.05";
    # No qdrant on the work Mac, so disable the ferrex memory stack here.
    qdrant.enable = false;
    # Persistent SSH sessions: drop into a tmux session on login so work
    # survives closing the terminal or losing the connection.
    tmux.autoAttach = true;
    claude.bashGuard.enable = false;
    # No age key on the work box — skip sops so activation doesn't need it.
    secrets.enable = false;
    # Work laptop (the VMware host) SSH key, so it can log into this VM.
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9gvaCjdNLEKlUzkpBGtnnO7AjYxHkkueSfj689dkyX dmytro.onypko@Mac-G4F36NXDV4.local"
    ];
    # This box only needs the repos, nix and justex jumps.
    yaziBookmarks = [
      {
        key = "r";
        path = "~/repos/";
        desc = "Go to [r]epos";
      }
      {
        key = "n";
        path = config.custom.configPath;
        desc = "Go to [n]ix";
      }
      {
        key = "j";
        path = "~/repos/justex";
        desc = "Go to [j]ustex";
      }
    ];
  };
}
