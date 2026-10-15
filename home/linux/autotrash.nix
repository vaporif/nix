{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.autotrash;
in {
  systemd.user.services.autotrash = {
    Unit.Description = "Purge old trash, and the oldest trash when disk is low";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.autotrash} --min-free ${toString (cfg.minFreeGB * 1024)} --days ${toString cfg.maxAgeDays}";
    };
  };

  systemd.user.timers.autotrash = {
    Unit.Description = "Run autotrash hourly";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
