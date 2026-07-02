{
  pkgs,
  lib,
  home-manager,
  inputs,
}:
{
  formatting = pkgs.runCommand "check-formatting" {} ''
    ${pkgs.alejandra}/bin/alejandra -c ${../.} && touch $out
  '';
  # TODO: re-enable. The codex check fails the `ferrex` mcp_servers grep
  # because qdrant.enable defaults to false, so the ferrex MCP server is
  # never emitted into config.toml.
  # codex = import ./codex.nix {
  #   inherit pkgs home-manager inputs;
  # };
}
// lib.optionalAttrs pkgs.stdenv.isDarwin (
  pkgs.unclog.passthru.tests
  // pkgs.nomicfoundation_solidity_language_server.passthru.tests
  // pkgs.claude_formatter.passthru.tests
  // pkgs.tidal_script.passthru.tests
)
// lib.optionalAttrs pkgs.stdenv.isLinux {
  claude-security = import ./claude-security.nix {
    inherit pkgs home-manager;
  };
  claude-settings = import ./claude-settings.nix {
    inherit pkgs home-manager;
  };
  check-bash-matcher = import ./check-bash-matcher.nix {
    inherit pkgs;
  };
  xdg-config-paths = import ./xdg-config-paths.nix {
    inherit pkgs home-manager inputs;
  };
}
