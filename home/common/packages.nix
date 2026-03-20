{
  lib,
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs;
    [
      nixd
      alejandra
      statix
      deadnix
      nix-tree
      nix-diff
      nix-search
      nix-output-monitor
      nvd

      dua
      stylua
      selene
      typos
      taplo
      shellcheck
      actionlint
      cachix
      vulnix

      bacon
      cargo-info
      rusty-man

      yt-dlp

      python3

      presenterm
      tokei
      just
      lazydocker
      btop
      procs
      sops

      (haskellPackages.ghcWithPackages (pkgs:
        with pkgs; [
          tidal
          cabal-install
        ]))

      tdf

      wget
      rsync
      delta
      difftastic
      ouch
      hyperfine

      shfmt

      claude-code
      inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default
      qdrant
      qdrant-web-ui

      tidal_script
      unclog
      nomicfoundation_solidity_language_server
      claude_formatter

      (writeShellScriptBin "git-bare-clone" (builtins.readFile ../../scripts/git-bare-clone.sh))
      (writeShellScriptBin "git-meta" (builtins.readFile ../../scripts/git-meta.sh))
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      gnused
    ];
}
