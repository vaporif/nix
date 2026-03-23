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
    ++ secretEnvNames;

  # GitHub token: read from sops secret before sandbox
  ghTokenPreload = ''
    GITHUB_PERSONAL_ACCESS_TOKEN=""
    if [ -r ${cfg.secrets.github-token} ]; then
      GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${cfg.secrets.github-token})"
    fi
    export GITHUB_PERSONAL_ACCESS_TOKEN
    export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
  '';
in {
  _module.args.sandboxShared = {
    inherit secretPreload ghTokenPreload sharedEnvNames;
  };
}
