{
  pkgs,
  config,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  systemd.user.services.qdrant = {
    Unit = {
      Description = "Qdrant vector database";
      After = ["network.target"];
    };
    Service = {
      ExecStart = "${pkgs.qdrant}/bin/qdrant --config-path ${homeDir}/.qdrant/config.yaml";
      Restart = "always";
      StandardOutput = "append:${homeDir}/.qdrant/qdrant.log";
      StandardError = "append:${homeDir}/.qdrant/qdrant.err";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
