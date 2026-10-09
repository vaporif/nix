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
  tmux = lib.getExe config.programs.tmux.package;

  ircdConfig = (pkgs.formats.toml {}).generate "matterircd.toml" {
    bind = "${address}:${toString port}";
    mattermost = {
      # Keep the mattermost membership when a buffer is closed in weechat.
      PartFake = true;
      Unicode = true;
      ShowMentions = true;
    };
  };

  # Esc is the leader: the input line can't take Space or bare letters, and
  # Esc+key is how terminals send Alt, so weechat reads these as meta combos
  # with no timeout. Groups mirror the nvim <leader> ones (b = buffer,
  # s = split); movement is arrows only. A default that is a prefix of a combo
  # (meta-b, meta-s, meta-m) has to go, or it fires before the combo completes.
  keys = {
    "meta-left" = "/buffer -1";
    "meta-right" = "/buffer +1";
    "meta-b,n" = "/buffer +1";
    "meta-b,p" = "/buffer -1";
    "meta-b,x" = "/buffer close";
    "meta-a" = "/buffer jump smart";
    "meta-up" = "/window page_up";
    "meta-down" = "/window page_down";
    "meta-g,up" = "/window scroll_top";
    "meta-g,down" = "/window scroll_bottom";
    "meta-m,up" = "/window scroll_previous_highlight";
    "meta-m,down" = "/window scroll_next_highlight";
    "meta-u" = "/window scroll_unread";
    "meta-s,v" = "/window splitv";
    "meta-s,h" = "/window splith";
    "meta-s,x" = "/window merge";
    "meta-tab" = "/window +1";
    "meta-/" = "/input search_text_here";
  };

  weechat = pkgs.weechat.override {
    configure = {availablePlugins, ...}: {
      plugins = builtins.attrValues (removeAttrs availablePlugins ["php"]);
      # Runs on every launch, and weechat evaluates these lines before running
      # them. The login line is wrapped in ''${raw:...} so it is stored with its
      # ''${env:...} refs intact and only expanded on connect, keeping the token
      # out of irc.conf. Keys are reset first so bindings dropped here don't
      # linger in weechat.conf.
      init = ''
        /mute /server add mattermost ${address}/${toString port} -notls
        /set irc.server.mattermost.autoconnect on
        /set irc.server.mattermost.nicks "''${env:MM_USER}"
        /set irc.server.mattermost.command "''${raw:/msg mattermost login ''${env:MM_HOST} ''${env:MM_TEAM} ''${env:MM_USER} token=''${env:MM_TOKEN}}"
        /mute /key resetall -yes
        /mute /key unbind meta-b
        /mute /key unbind meta-s
        /mute /key unbind meta-m
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: cmd: "/key bind ${key} ${cmd}") keys)}
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

    # Every channel message counts as tmux activity, which would bury the bell
    # weechat's default beep trigger rings on mentions and DMs. Mute activity
    # for this window only, and hand it back once weechat exits.
    if [[ -n ''${TMUX_PANE:-} ]]; then
      ${tmux} set-option -w -t "$TMUX_PANE" monitor-activity off
      trap '${tmux} set-option -wu -t "$TMUX_PANE" monitor-activity' EXIT
    fi
    ${lib.getExe' weechat "weechat"} "$@"
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
