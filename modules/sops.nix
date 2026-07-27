{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.custom;
  secretsPath = ../secrets/secrets.yaml;
  ownership = {
    owner = cfg.user;
    group =
      if pkgs.stdenv.isDarwin
      then "staff"
      else "users";
    mode = "0400";
  };
in {
  sops = lib.mkIf cfg.secrets.enable {
    defaultSopsFile = secretsPath;
    age = {
      keyFile = "${cfg.homeDir}/.config/sops/age/key.txt";
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
    secrets = lib.genAttrs (import ./secrets.nix) (_: ownership);

    # matterhorn takes the host as a literal in config.ini — unlike the token,
    # there is no `hostcmd` to defer the read to runtime. Render the file at
    # activation so the work server name stays in sops, not in the nix source.
    templates = lib.mkIf cfg.mattermost.enable {
      "matterhorn-config.ini" =
        ownership
        // {
          content = ''
            [mattermost]
            host: ${config.sops.placeholder.mattermost-host}
            port: 443
            tokencmd: cat ${cfg.secrets.mattermost-token}
            theme: builtin:${
              if config.stylix.polarity == "dark"
              then "dark256"
              else "light256"
            }
            themeCustomizationFile: ${cfg.homeDir}/.config/matterhorn/theme.ini

            [KEYBINDINGS]
            show-help: M-?
            toggle-channel-list-visibility: M-e
            toggle-expanded-channel-topics: M-t
            cycle-channel-list-sorting: M-r
            toggle-multiline: M-m
            select-up: Up
            select-down: Down
          '';
        };
    };
  };
}
