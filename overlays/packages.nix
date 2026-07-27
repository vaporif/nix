{
  vim-tidal,
  difftastic-src,
}: final: _: let
  mkTest = name: cmd:
    final.runCommand "${name}-test" {} ''
      ${cmd}
      touch $out
    '';
in {
  librewolf-unwrapped = final.callPackage ../pkgs/librewolf-unwrapped/package.nix {};

  claude-code = final.callPackage ../claude/package.nix {};

  codex = final.callPackage ../pkgs/codex.nix {};

  gitlab-mcp = final.callPackage ../pkgs/gitlab-mcp.nix {};

  difftastic = final.callPackage ../pkgs/difftastic.nix {inherit difftastic-src;};

  # matterhorn: the nixpkgs build is broken. mattermost-api's TLS code predates
  # crypton-connection 0.4's added `Supported` field on TLSSettingsSimple, and
  # matterhorn's own dependency bounds are stale. Patch the API for the new
  # constructor arity (adding tls + data-default deps) and jailbreak the bounds.
  matterhorn = let
    hl = final.haskell.lib;
    hp = final.haskellPackages.override {
      overrides = _: hprev: {
        mattermost-api = hl.doJailbreak (hl.markUnbroken (hl.addBuildDepends
          (hl.appendPatch hprev.mattermost-api ../patches/mattermost-api-tls.patch)
          [hprev.tls hprev.data-default]));
        mattermost-api-qc = hl.doJailbreak (hl.markUnbroken hprev.mattermost-api-qc);
        matterhorn = hl.doJailbreak (hl.markUnbroken hprev.matterhorn);
      };
    };
  in
    hp.matterhorn;

  lean-ctx = (final.callPackage ../pkgs/lean-ctx.nix {}).overrideAttrs (_: {
    passthru.tests.lean-ctx = mkTest "lean-ctx" ''
      ${final.lean-ctx}/bin/lean-ctx --version > /dev/null
    '';
  });

  unclog = (final.callPackage ../pkgs/unclog.nix {}).overrideAttrs (_: {
    passthru.tests.unclog = mkTest "unclog" ''
      ${final.unclog}/bin/unclog --help > /dev/null
    '';
  });

  nomicfoundation_solidity_language_server = (final.callPackage ../pkgs/nomicfoundation-solidity-language-server.nix {}).overrideAttrs (_: {
    passthru.tests.solidity-lsp = mkTest "solidity-lsp" ''
      test -x ${final.nomicfoundation_solidity_language_server}/bin/nomicfoundation-solidity-language-server
    '';
  });

  claude_formatter =
    (final.writeShellScriptBin "claude-formatter" ''
      file_path=$(${final.jq}/bin/jq -r '.tool_input.file_path // empty')
      [ -z "$file_path" ] || [ ! -f "$file_path" ] && exit 0

      case "$file_path" in
        *.nix) alejandra -q "$file_path" 2>/dev/null || true ;;
        *.go)  gofmt -w "$file_path" 2>/dev/null || true ;;
        *.rs)  rustfmt "$file_path" 2>/dev/null || true ;;
        *.lua) stylua "$file_path" 2>/dev/null || true ;;
      esac
    '').overrideAttrs (_: {
      passthru.tests.claude-formatter = mkTest "claude-formatter" ''
        echo '{}' | ${final.claude_formatter}/bin/claude-formatter
      '';
    });

  tidal_script =
    (final.stdenv.mkDerivation {
      name = "tidal";
      src = "${vim-tidal}/bin/tidal";
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/tidal
        chmod +x $out/bin/tidal
      '';
    }).overrideAttrs (_: {
      passthru.tests.tidal = mkTest "tidal" ''
        test -x ${final.tidal_script}/bin/tidal
      '';
    });
}
