{
  lib,
  pkgs,
  ...
}: {
  home.packages =
    [
      pkgs.nixd
      pkgs.alejandra
      pkgs.statix
      pkgs.deadnix
      pkgs.nix-tree
      pkgs.nix-diff
      pkgs.nix-search
      pkgs.nix-output-monitor
      pkgs.nvd

      pkgs.dua
      pkgs.stylua
      pkgs.selene
      pkgs.typos
      pkgs.taplo
      pkgs.shellcheck
      pkgs.actionlint
      pkgs.cachix
      pkgs.vulnix

      pkgs.bacon
      pkgs.cargo-info
      pkgs.cargo-depgraph
      pkgs.rusty-man
      pkgs.graphviz

      pkgs.python3
      pkgs.python3Packages.huggingface-hub

      pkgs.presenterm
      pkgs.tokei
      pkgs.just
      pkgs.lazydocker
      pkgs.btop
      pkgs.procs
      pkgs.sops
      pkgs.jqp
      pkgs.viddy
      pkgs.sshx
      pkgs.trippy
      pkgs.promptfoo

      (pkgs.haskellPackages.ghcWithPackages (hpkgs: [
        hpkgs.tidal
        hpkgs.cabal-install
      ]))

      pkgs.tdf

      pkgs.wget
      pkgs.rsync
      pkgs.delta
      pkgs.difftastic
      pkgs.ouch
      pkgs.hyperfine

      pkgs.shfmt

      pkgs.claude-code
      pkgs.mcp-nixos
      pkgs.qdrant
      pkgs.qdrant-web-ui

      pkgs.tidal_script
      pkgs.unclog
      pkgs.nomicfoundation_solidity_language_server
      pkgs.claude_formatter

      (pkgs.writeShellScriptBin "git-bare-clone" (builtins.readFile ../../scripts/git-bare-clone.sh))
      (pkgs.writeShellScriptBin "git-meta" (builtins.readFile ../../scripts/git-meta.sh))
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.gnused
    ];
}
