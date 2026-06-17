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
  };
}
