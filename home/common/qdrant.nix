{config, ...}: let
  homeDir = config.home.homeDirectory;
in {
  home.file.".qdrant/config.yaml".text = ''
    service:
      host: 127.0.0.1
      http_port: 6333
      grpc_port: 6334
    storage:
      storage_path: ${homeDir}/.qdrant/storage
      snapshots_path: ${homeDir}/.qdrant/snapshots
    telemetry_disabled: true
  '';
}
