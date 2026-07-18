{lib, ...}: {
  imports = [./container-base.nix];

  # common.nix sets user plainly to "vaporif"; force root for the rootless container.
  custom = {
    user = lib.mkForce "root";
    homeDir = "/root";
    configPath = "/root/.config/nix";
  };
}
