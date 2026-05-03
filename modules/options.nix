{
  lib,
  config,
  ...
}: let
  secretsPath = ../secrets/secrets.yaml;
  secretsExist = builtins.pathExists secretsPath;
in {
  options.custom = {
    homeDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory path, derived from user and system";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Primary username";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Machine hostname, used as flake output key";
    };
    system = lib.mkOption {
      type = lib.types.enum ["aarch64-darwin" "aarch64-linux"];
      description = "System architecture";
    };
    configPath = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to this repo on the host";
    };
    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "System timezone";
    };
    sshAgent = lib.mkOption {
      type = lib.types.enum ["" "secretive"];
      default = "";
      description = "SSH agent type: 'secretive' for macOS Secretive.app, empty otherwise";
    };
    utmHostIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IP of UTM VM for SSH config (macOS only)";
    };
    utmGatewayIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.64.1";
      description = "IP of macOS host as seen from UTM VM (NixOS only). Default is UTM's shared-network gateway address.";
    };
    git = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Git author name";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Git author email";
      };
      signingKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SSH public key for git commit signing";
      };
    };
    cachix = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Cachix cache name";
      };
      publicKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Cachix cache public key";
      };
    };
    lspPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Shared LSP packages for neovim and MCP servers";
    };
    sandboxedPackages = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = {};
      description = "Sandboxed package wrappers (populated on darwin only)";
    };
    secrets =
      lib.genAttrs
      (import ./secrets.nix)
      (name:
        lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to ${name} secret file. null when sops is not configured.";
        });
  };

  config.custom = {
    homeDir =
      if lib.hasSuffix "darwin" config.custom.system
      then "/Users/${config.custom.user}"
      else "/home/${config.custom.user}";

    # Populate secret paths only when sops is configured. Consumers must gate
    # their wiring on the value being non-null (see modules/nix.nix etc.).
    secrets = lib.mkIf secretsExist (
      lib.genAttrs (import ./secrets.nix) (name: "/run/secrets/${name}")
    );
  };
}
