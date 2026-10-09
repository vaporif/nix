{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  inherit (cfg) secrets;
  address = "127.0.0.1";
  port = 6667;

  ircdConfig = (pkgs.formats.toml {}).generate "matterircd.toml" {
    bind = "${address}:${toString port}";
    mattermost = {
      # Keep the mattermost membership when a buffer is closed in weechat.
      PartFake = true;
      Unicode = true;
      ShowMentions = true;
    };
  };

  # The work server is SAML-only, so login takes a personal access token (or
  # the MMAUTHTOKEN cookie). The login line is stored with ${env:...} refs and
  # weechat evaluates them on connect, so the token never lands in irc.conf.
  weechat = pkgs.weechat.override {
    configure = {availablePlugins, ...}: {
      plugins = builtins.attrValues (removeAttrs availablePlugins ["php"]);
      init = ''
        /server add mattermost ${address}/${toString port} -notls
        /set irc.server.mattermost.autoconnect on
        /set irc.server.mattermost.nicks "''${env:MM_USER}"
        /set irc.server.mattermost.command "/msg mattermost login ''${env:MM_HOST} ''${env:MM_TEAM} ''${env:MM_USER} token=''${env:MM_TOKEN}"
      '';
    };
  };

  # Secrets are read at launch, not build, so the work host stays out of the store.
  # matterircd's login wants a username and team, which the token alone can
  # answer, so ask the API rather than keep two more secrets in sync.
  weechatWithSecrets = pkgs.writeShellScriptBin "weechat" ''
    set -o pipefail
    MM_HOST="$(<${secrets.mattermost-host})"
    MM_TOKEN="$(<${secrets.mattermost-token})"
    api() {
      ${lib.getExe pkgs.curl} -fsS -H "Authorization: Bearer $MM_TOKEN" "https://$MM_HOST/api/v4/$1"
    }
    if ! MM_USER="$(api users/me | ${lib.getExe pkgs.jq} -er .username)"; then
      echo "mattermost: token rejected, put a fresh one in mattermost-token (sops) and switch" >&2
      exit 1
    fi
    MM_TEAM="$(api users/me/teams | ${lib.getExe pkgs.jq} -er '.[0].name')" || exit 1
    export MM_HOST MM_TEAM MM_USER MM_TOKEN
    exec ${lib.getExe' weechat "weechat"} "$@"
  '';
in {
  config = lib.mkIf cfg.mattermost.enable {
    assertions = [
      {
        assertion = secrets.mattermost-host != null && secrets.mattermost-token != null;
        message = "custom.mattermost.enable needs the mattermost-host and mattermost-token sops secrets";
      }
    ];

    home.packages = [weechatWithSecrets];

    systemd.user.services.matterircd = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "matterircd Mattermost-to-IRC bridge";
      Service = {
        ExecStart = "${lib.getExe pkgs.matterircd} --conf ${ircdConfig}";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
