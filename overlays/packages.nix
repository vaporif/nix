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
  claude-code = final.callPackage ../claude/package.nix {};

  codex = final.callPackage ../pkgs/codex/package.nix {};

  difftastic = final.callPackage ../pkgs/difftastic.nix {inherit difftastic-src;};

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
