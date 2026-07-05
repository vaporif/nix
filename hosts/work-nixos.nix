{
  config,
  lib,
  ...
}: {
  imports = [./common.nix];
  nix.settings.trusted-users = ["root" config.custom.user];
  custom = {
    hostname = "work-nixos";
    system = "aarch64-linux";
    configPath = "${config.custom.homeDir}/.config/nix";
    sshAgent = "";
    git = {
      name = "Dmytro Onypko";
      email = "dmytro.onypko@justmarkets.com";
      signingKey = "";
    };
    stateVersion = "26.05";
    cachix = {
      name = lib.mkForce "";
      publicKey = lib.mkForce "";
    };
    gitlab.enable = true;
    qdrant.enable = false;
    tmux.autoAttach = true;
    # Work laptop (the VMware host) SSH key, so it can log into this VM.
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9gvaCjdNLEKlUzkpBGtnnO7AjYxHkkueSfj689dkyX dmytro.onypko@Mac-G4F36NXDV4.local"
    ];
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
        key = "m";
        path = "~/repos/matching-engine";
        desc = "Go to [m]atching-engine";
      }
    ];
  };
}
