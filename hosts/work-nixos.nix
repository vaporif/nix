{config, ...}: {
  imports = [./common.nix];
  custom = {
    hostname = "work-nixos";
    system = "aarch64-linux";
    configPath = "${config.custom.homeDir}/.config/nix";
    sshAgent = "";
    stateVersion = "26.05";
    # No qdrant on the work Mac, so disable the ferrex memory stack here.
    qdrant.enable = false;
    # No age key on the work box — skip sops so activation doesn't need it.
    secrets.enable = false;
    # Work laptop (the VMware host) SSH key, so it can log into this VM.
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9gvaCjdNLEKlUzkpBGtnnO7AjYxHkkueSfj689dkyX dmytro.onypko@Mac-G4F36NXDV4.local"
    ];
  };
}
