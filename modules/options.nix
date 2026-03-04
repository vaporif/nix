{lib, ...}: {
  options.custom = {
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
      type = lib.types.str;
      default = "";
      description = "SSH agent type: 'secretive' for macOS Secretive.app, empty otherwise";
    };
    utmHostIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IP of UTM VM for SSH config (macOS only)";
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
  };
}
