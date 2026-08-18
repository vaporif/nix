lib: let
  required = [
    "openrouter-key"
    "tavily-key"
    "youtube-key"
    "hf-token-scan-injection"
    "ntfy-topic"
    "nix-access-tokens"
    "github-token"
    "gitlab-token"
    "gitlab-api-url"
    "mattermost-token"
    "mattermost-host"
  ];

  optional = [
    "context7-key"
  ];

  sopsLines = lib.splitString "\n" (builtins.readFile ../secrets/secrets.yaml);
  inSopsFile = name: lib.any (line: lib.hasPrefix "${name}:" line) sopsLines;
in {
  all = required ++ optional;
  available = required ++ lib.filter inSopsFile optional;
}
