{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
in {
  home.packages =
    [
      pkgs.nixd
      pkgs.alejandra
      pkgs.selene
      pkgs.statix
      pkgs.deadnix
      pkgs.nix-tree
      pkgs.nix-diff
      pkgs.nix-search
      pkgs.nix-output-monitor
      pkgs.nvd

      pkgs.dua
      pkgs.stylua
      pkgs.typos
      pkgs.taplo
      pkgs.shellcheck
      pkgs.actionlint
      pkgs.cachix

      pkgs.bacon
      pkgs.cargo-info
      pkgs.cargo-depgraph
      pkgs.rusty-man
      pkgs.graphviz

      pkgs.presenterm
      pkgs.asciinema
      pkgs.asciinema-agg
      pkgs.tokei
      pkgs.just
      pkgs.lazydocker
      pkgs.procs
      pkgs.sops
      pkgs.jqp
      pkgs.viddy
      pkgs.sshx
      pkgs.trippy
      pkgs.promptfoo

      pkgs.tdf

      pkgs.wget
      pkgs.rsync
      pkgs.delta
      pkgs.difftastic
      pkgs.ouch
      pkgs.hyperfine

      pkgs.shfmt
      pkgs.lefthook

      pkgs.mcp-nixos

      pkgs.lean-ctx
      pkgs.unclog
      pkgs.matterhorn

      (pkgs.writeShellScriptBin "git-bare-clone" (builtins.readFile ../../scripts/git-bare-clone.sh))
      (pkgs.writeShellScriptBin "git-meta" (builtins.readFile ../../scripts/git-meta.sh))
      (pkgs.writeShellScriptBin "git-worktree-new" (builtins.readFile ../../scripts/git-worktree-new.sh))
      (pkgs.writeShellScriptBin "git-worktree-remove" (builtins.readFile ../../scripts/git-worktree-remove.sh))
    ]
    # Heavy / host-only tooling, darwin only (kept off Linux + container builds).
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.python314
      pkgs.uv
      pkgs.python3Packages.huggingface-hub

      (pkgs.haskellPackages.ghcWithPackages (hpkgs: [
        hpkgs.tidal
        hpkgs.cabal-install
      ]))

      pkgs.ffmpeg

      pkgs.qdrant
      pkgs.qdrant-web-ui

      pkgs.tidal_script
      pkgs.nomicfoundation_solidity_language_server

      pkgs.gnused
    ]
    ++ lib.optionals cfg.claude.enable [
      pkgs.claude-code
      pkgs.claude_formatter
    ]
    ++ lib.optionals cfg.codex.enable [
      pkgs.codex
    ]
    ++ lib.optionals cfg.gitlab.enable [
      pkgs.glab
    ];
}
