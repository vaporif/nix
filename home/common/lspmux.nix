# Language server multiplexer. Without it every client starts its own server:
# a swarm of Claude Code sessions editing Rust in one worktree spawned six
# rust-analyzers, each holding a ~2.4 GiB index of the same crates, and several
# neovim windows on the same project do exactly the same. lspmux keeps one
# server per (server binary, workspace root, passed environment) and hands it to
# every client that matches.
#
# Two consequences worth knowing before changing anything here:
#
#   - The first client to spawn an instance fixes its settings for every later
#     client, because the others attach to a server that has already
#     initialized. That is why rustAnalyzerSettings below is the single source
#     of truth shared by neovim and Claude Code rather than each carrying its
#     own — mismatched settings would otherwise resolve by whoever started
#     first, which is a race.
#
#   - `pass_environment = ["PATH"]` sends the client's PATH to the spawned
#     server, so rust-analyzer finds the toolchain from the project's direnv
#     shell instead of the daemon's bare environment. The cost is that clients
#     with different PATHs get separate instances; clients sharing a direnv
#     shell — the case that matters — share one.
#
# lspmux demultiplexes by rewriting request/response IDs, and drops messages it
# cannot attribute, notably every server→client request. Dynamic registration of
# file watching goes with them, so diagnostics can lag edits made outside the
# attached clients. Set `custom.lspmux.enable = false` to route every client
# straight at its server again; the `servers` attribute below keeps the same
# shape either way, so no consumer needs to branch on it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.lspmux;
  homeDir = config.home.homeDirectory;

  # Shared rust-analyzer configuration. `allTargets = false` drops tests,
  # benches and examples from analysis; `cachePriming` off trades a smaller
  # startup footprint for filling the cache lazily as files are visited.
  rustAnalyzerSettings = {
    files.excludeDirs = [".direnv"];
    cargo.allTargets = false;
    cachePriming.enable = false;
    lru.capacity = 64;
  };

  configFile = ''
    instance_timeout = ${toString cfg.instanceTimeout}
    gc_interval = 10
    listen = ["127.0.0.1", ${toString cfg.port}]
    connect = ["127.0.0.1", ${toString cfg.port}]
    log_filters = "info"
    pass_environment = ["PATH"]
  '';

  # Route a server through the proxy, or hand back the bare binary when the
  # multiplexer is off. `lspmux client` speaks stdio to its caller, so it drops
  # into any place that expects an LSP command plus args.
  mkServer = server:
    if cfg.enable
    then {
      command = lib.getExe cfg.package;
      args = ["client" "--server-path" server];
    }
    else {
      command = server;
      args = [];
    };
in {
  options.custom.lspmux = {
    enable = lib.mkEnableOption "the lspmux language server multiplexer";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lspmux;
      description = "The lspmux package to use";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 27631;
      description = "Localhost port the lspmux daemon listens on";
    };

    instanceTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds a server with no attached clients is kept alive";
    };

    rustAnalyzerSettings = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "rust-analyzer settings shared by every client, sent as initializationOptions";
    };

    servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.str;
            description = "Executable to run for this language server";
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Arguments passed to the executable";
          };
        };
      });
      readOnly = true;
      description = "Per-language-server command and args, proxied through lspmux when enabled";
    };
  };

  config = {
    custom.lspmux = {
      inherit rustAnalyzerSettings;
      servers = {
        rust-analyzer = mkServer (lib.getExe pkgs.rust-analyzer);
        gopls = mkServer (lib.getExe pkgs.gopls);
      };
    };

    home.packages = lib.mkIf cfg.enable [cfg.package];

    xdg.configFile."lspmux/config.toml" = lib.mkIf cfg.enable {
      text = configFile;
    };

    systemd.user.services.lspmux = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
      Unit = {
        Description = "lspmux language server multiplexer";
        After = ["default.target"];
      };
      Service = {
        ExecStart = "${lib.getExe cfg.package} server";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };

    launchd.agents.lspmux = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      inherit (cfg) enable;
      config = {
        Label = "org.codeberg.p2502.lspmux";
        ProgramArguments = ["${lib.getExe cfg.package}" "server"];
        RunAtLoad = true;
        KeepAlive = {SuccessfulExit = false;};
        StandardOutPath = "${homeDir}/Library/Logs/lspmux.log";
        StandardErrorPath = "${homeDir}/Library/Logs/lspmux.err";
      };
    };
  };
}
