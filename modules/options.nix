{
  lib,
  config,
  ...
}: let
  llmContentEntry = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        description = "Path (literal or store-path string) to the content.";
      };
      kind = lib.mkOption {
        type = lib.types.enum ["file" "directory"];
        default = "file";
        description = "'file' = single markdown file. 'directory' = multi-file content tree (e.g. SKILL.md plus helpers).";
      };
    };
  };
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
    hostGatewayIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.64.1";
      description = "IP of the host Mac as seen from a NixOS guest VM. Default is UTM's shared-network gateway address; override per host for other hypervisors (e.g. VMware Fusion).";
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
      {
        enable = lib.mkEnableOption "sops-managed secrets";
      }
      // lib.genAttrs
      (import ./secrets.nix)
      (name:
        lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to ${name} secret file. null when sops is not configured.";
        });

    claude.enable = lib.mkEnableOption "Claude Code (CLI, plugins, settings, security, sandbox, aliases, MCP integration)";
    qdrant.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Qdrant-backed ferrex memory stack: the qdrant launchd agent on macOS plus the ferrex MCP server on every host. Disable on machines with no qdrant reachable (e.g. the work VM).";
    };
    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "25.11";
      description = "NixOS system.stateVersion — the release this host was first installed with. Set per host and NEVER change it after install. (NixOS hosts only.)";
    };
    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra SSH public keys authorized to log in as the user, in addition to the git signing key. Set per host (e.g. the work laptop's key on work-nixos).";
    };
    codex = {
      enable = lib.mkEnableOption "Codex CLI (CLI, settings, skills, agents, aliases, MCP integration)";
      trustedRepoNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Directory names under custom.homeDir/Repos to trust in Codex config.toml.";
      };
    };

    llm = {
      skills = lib.mkOption {
        type = lib.types.attrsOf llmContentEntry;
        default = {};
        description = "Tool-neutral skill content. Per-client consumers (claude, codex, gemini) read this and deliver to their own paths.";
      };
      agents = lib.mkOption {
        type = lib.types.attrsOf llmContentEntry;
        default = {};
        description = "Tool-neutral agent content.";
      };
      commands = lib.mkOption {
        type = lib.types.attrsOf llmContentEntry;
        default = {};
        description = "Tool-neutral slash-command content.";
      };
      rules = lib.mkOption {
        type = lib.types.attrsOf llmContentEntry;
        default = {};
        description = "Tool-neutral language/usage rules.";
      };
      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Tool-neutral MCP server definitions. Per-client configs (claude desktop/code, codex, gemini) read this and transform.";
      };
    };
  };

  config.custom = {
    homeDir =
      if lib.hasSuffix "darwin" config.custom.system
      then "/Users/${config.custom.user}"
      else "/home/${config.custom.user}";

    # Populate /run/secrets paths when sops is enabled; otherwise leave
    # everything null. Consumers gate on the value (see modules/nix.nix etc).
    # Lives here, not in modules/sops.nix, because both system and HM modules
    # consume custom.secrets.* and only options.nix is in both scopes.
    secrets = lib.mkIf config.custom.secrets.enable (
      lib.genAttrs (import ./secrets.nix) (name: "/run/secrets/${name}")
    );
  };
}
