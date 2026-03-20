{
  config,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  # On macOS: bind to 0.0.0.0 so NixOS VM can connect over UTM network
  # macOS firewall restricts access to UTM subnet only (see system/darwin)
  # On NixOS: localhost only (uses macOS qdrant over network)
  bindHost =
    if pkgs.stdenv.isDarwin
    then "0.0.0.0"
    else "127.0.0.1";
in {
  home.file.".qdrant/config.yaml".text = ''
    service:
      host: ${bindHost}
      http_port: 6333
      grpc_port: 6334
    storage:
      storage_path: ${homeDir}/.qdrant/storage
      snapshots_path: ${homeDir}/.qdrant/snapshots
    telemetry_disabled: true
  '';
}
