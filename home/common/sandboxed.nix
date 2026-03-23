{
  lib,
  config,
  ...
}: let
  cfg = config.custom;
  # Shared secret names (read outside sandbox, injected as env vars)
  secretEnvVars = [
    {
      env = "TAVILY_API_KEY";
      file = cfg.secrets.tavily-key;
    }
    {
      env = "QDRANT_API_KEY";
      file = cfg.secrets.qdrant-api-key;
    }
    {
      env = "HF_TOKEN";
      file = cfg.secrets.hf-token-scan-injection;
    }
  ];

  # Generate pre-load script for secrets (runs before sandbox)
  secretPreload = lib.concatStringsSep "\n" (map (s: ''
      ${s.env}=""
      if [ -r ${s.file} ]; then
        ${s.env}="$(cat ${s.file})"
      fi
      export ${s.env}
    '')
    secretEnvVars);

  secretEnvNames = map (s: s.env) secretEnvVars;

  # Nix devshell env vars needed for compilation/linking inside sandbox
  nixDevshellEnvNames = [
    "NIX_LDFLAGS"
    "NIX_LDFLAGS_FOR_TARGET"
    "NIX_CFLAGS_COMPILE"
    "NIX_CFLAGS_COMPILE_FOR_TARGET"
    "NIX_CC"
    "NIX_CC_FOR_TARGET"
    "NIX_BINTOOLS"
    "NIX_BINTOOLS_FOR_TARGET"
    "NIX_HARDENING_ENABLE"
    "NIX_ENFORCE_NO_NATIVE"
    "NIX_DONT_SET_RPATH"
    "NIX_DONT_SET_RPATH_FOR_BUILD"
    "NIX_NO_SELF_RPATH"
    "NIX_IGNORE_LD_THROUGH_GCC"
    "NIX_STORE"
    "NIX_BUILD_CORES"
    "NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_CC_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_CC_WRAPPER_TARGET_HOST_arm64_apple_darwin"
    "NIX_BINTOOLS_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_BINTOOLS_WRAPPER_TARGET_HOST_arm64_apple_darwin"
    "NIX_APPLE_SDK_VERSION"
    "CC"
    "CXX"
    "AR"
    "LD"
    "NM"
    "AS"
    "RANLIB"
    "STRIP"
    "OBJDUMP"
    "OBJCOPY"
    "SIZE"
    "STRINGS"
    "SDKROOT"
    "DEVELOPER_DIR"
    "MACOSX_DEPLOYMENT_TARGET"
    "RUST_SRC_PATH"
    "PKG_CONFIG_PATH_FOR_TARGET"
    "CARGO_NET_GIT_FETCH_WITH_CLI"
    "IN_NIX_SHELL"
  ];

  # Shared env vars to pass through the sandbox
  sharedEnvNames =
    [
      "HOME"
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
      "CLAUDE_SANDBOX"
      "EDITOR"
      "VISUAL"
      "ENABLE_LSP_TOOL"
      "DFT_GRAPH_LIMIT"
      "DFT_BYTE_LIMIT"
      "GITHUB_PERSONAL_ACCESS_TOKEN"
      "GH_TOKEN"
    ]
    ++ nixDevshellEnvNames
    ++ secretEnvNames;

  # GitHub token: read from sops secret before sandbox (preserve existing value)
  ghTokenPreload = ''
    if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r ${cfg.secrets.github-token} ]; then
      GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${cfg.secrets.github-token})"
    fi
    export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
    export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
  '';
in {
  _module.args.sandboxShared = {
    inherit secretPreload ghTokenPreload sharedEnvNames;
  };
}
