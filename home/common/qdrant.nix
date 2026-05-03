{config, ...}: let
  homeDir = config.home.homeDirectory;
  # Bind 0.0.0.0 so the NixOS VM can reach qdrant over UTM's shared net.
  # macOS firewall restricts inbound to the UTM subnet (see system/darwin).
  # Darwin-only; imported from home/darwin/default.nix.
  bindHost = "0.0.0.0";
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
