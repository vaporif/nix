{lib, ...}: {
  imports = [./container-base.nix];

  # VS Code devcontainers run as the unprivileged "vscode" user; common.nix
  # sets user plainly to "vaporif", so force it here.
  custom = {
    user = lib.mkForce "vscode";
    homeDir = "/home/vscode";
    configPath = "/home/vscode/.config/nix";
  };
}
