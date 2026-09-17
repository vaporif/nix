{
  lib,
  config,
  ...
}: let
  cfg = config.custom;
  # Secrets read outside the sandbox and forwarded in as env vars.
  # Filter out null entries so a fork without sops doesn't try to
  # interpolate a null path.
  secretEnvVars = lib.filter (s: s.file != null) (
    [
      {
        env = "TAVILY_API_KEY";
        file = cfg.secrets.tavily-key;
      }
      {
        env = "CONTEXT7_API_KEY";
        file = cfg.secrets.context7-key;
      }
      {
        env = "HF_TOKEN";
        file = cfg.secrets.hf-token-scan-injection;
      }
    ]
    ++ lib.optionals cfg.gitlab.enable [
      {
        env = "GITLAB_PERSONAL_ACCESS_TOKEN";
        file = cfg.secrets.gitlab-token;
      }
      {
        env = "GITLAB_API_URL";
        file = cfg.secrets.gitlab-api-url;
      }
      # glab reads the same two secrets under its own variable names, and
      # wants the bare host rather than the /api/v4 endpoint the MCP server
      # takes. Mirrors the non-sandbox exports in home/common/shell.nix.
      {
        env = "GITLAB_TOKEN";
        file = cfg.secrets.gitlab-token;
      }
      {
        env = "GITLAB_HOST";
        file = cfg.secrets.gitlab-api-url;
        transform = ''GITLAB_HOST="''${GITLAB_HOST%/api/v4}"'';
      }
    ]
  );

  # Generate pre-load script for secrets (runs before sandbox). An entry may
  # carry a `transform` snippet to reshape the value once it has been read.
  secretPreload = lib.concatStringsSep "\n" (map (s: ''
      ${s.env}=""
      if [ -r ${s.file} ]; then
        ${s.env}="$(cat ${s.file})"
        ${lib.optionalString (s ? transform) s.transform}
      fi
      export ${s.env}
    '')
    secretEnvVars);

  secretEnvNames = map (s: s.env) secretEnvVars;

  # Nix devshell env vars needed for compilation/linking inside sandbox.
  # These are the stable names from stdenv's setup.sh, cc-wrapper, and
  # bintools-wrapper. Arch-specific wrapper sentinel vars
  # (NIX_CC_WRAPPER_TARGET_*) are included via the NIX_* prefix list.
  nixDevshellEnvNames = [
    # Compilers / toolchain
    "CC"
    "CXX"
    "AR"
    "AS"
    "LD"
    "NM"
    "RANLIB"
    "STRIP"
    "OBJDUMP"
    "OBJCOPY"
    "SIZE"
    "STRINGS"
    # macOS SDK
    "SDKROOT"
    "DEVELOPER_DIR"
    "MACOSX_DEPLOYMENT_TARGET"
    # Rust
    "RUST_SRC_PATH"
    "CARGO_NET_GIT_FETCH_WITH_CLI"
    "LIBCLANG_PATH"
    "BINDGEN_EXTRA_CLANG_ARGS"
    # Nix stdenv / cc-wrapper / bintools-wrapper
    "NIX_CC"
    "NIX_CC_FOR_TARGET"
    "NIX_BINTOOLS"
    "NIX_BINTOOLS_FOR_TARGET"
    "NIX_CFLAGS_COMPILE"
    "NIX_CFLAGS_COMPILE_FOR_TARGET"
    "NIX_LDFLAGS"
    "NIX_LDFLAGS_FOR_TARGET"
    "NIX_HARDENING_ENABLE"
    "NIX_ENFORCE_NO_NATIVE"
    "NIX_DONT_SET_RPATH"
    "NIX_DONT_SET_RPATH_FOR_BUILD"
    "NIX_NO_SELF_RPATH"
    "NIX_IGNORE_LD_THROUGH_GCC"
    "NIX_STORE"
    "NIX_BUILD_CORES"
    "NIX_APPLE_SDK_VERSION"
    "PKG_CONFIG_PATH_FOR_TARGET"
    "IN_NIX_SHELL"
    "SOURCE_DATE_EPOCH"
    "HOST_PATH"
    "PATH_LOCALE"
    "CONFIG_SHELL"
    "ZERO_AR_DATE"
    "LD_DYLD_PATH"
    # Arch-specific wrapper sentinels (darwin + linux)
    "NIX_CC_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_CC_WRAPPER_TARGET_HOST_arm64_apple_darwin"
    "NIX_BINTOOLS_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_BINTOOLS_WRAPPER_TARGET_HOST_arm64_apple_darwin"
    "NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_arm64_apple_darwin"
    "NIX_CC_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_CC_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
    "NIX_BINTOOLS_WRAPPER_TARGET_HOST_aarch64_unknown_linux_gnu"
    "NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_aarch64_unknown_linux_gnu"
  ];

  # Shared env vars to pass through the sandbox
  sharedEnvNames =
    [
      "HOME"
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
      "CLAUDE_SANDBOX"
      "CODEX_SANDBOX"
      "EDITOR"
      "VISUAL"
      "ENABLE_LSP_TOOL"
      "DFT_GRAPH_LIMIT"
      "DFT_BYTE_LIMIT"
      "GITHUB_PERSONAL_ACCESS_TOKEN"
      "GH_TOKEN"
      "OPENAI_API_KEY"
      "OPENAI_ORG_ID"
      "OPENAI_PROJECT_ID"
    ]
    ++ nixDevshellEnvNames
    ++ secretEnvNames;

  # GitHub token: load from sops secret before sandbox (existing env wins).
  ghTokenPreload = ''
    ${lib.optionalString (cfg.secrets.github-token != null) ''
      if [ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ -r ${cfg.secrets.github-token} ]; then
        GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${cfg.secrets.github-token})"
      fi
    ''}
    export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
    export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
  '';
in {
  _module.args.sandboxShared = {
    inherit secretPreload ghTokenPreload sharedEnvNames;
  };
}
