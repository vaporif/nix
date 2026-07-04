{
  config,
  lib,
  ...
}: {
  custom = {
    claude.enable = true;
    codex = {
      enable = false;
      trustedRepoNames = [
        "Zikkaron"
        "advanced"
        "agave"
        "go"
        "ibc-attestor"
        "justmarkets"
        "kingdom"
        "learning"
        "leetcode"
        "monorepo"
        "nearcore"
        "chernroot"
        "remix-mcp"
        "tidal"
        "tikv"
        "tokyo"
        "vim-tidal-lua"
        "zair"
        "zmk-config"
        "dereza"
      ];
    };
    user = "vaporif";
    git = {
      name = lib.mkDefault "Dmytro Onypko";
      email = lib.mkDefault "vaporif@proton.me";
      signingKey = lib.mkDefault "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBP7sf4L6CNhRgdRKmXH2H7xxWTEWMTCS/oOkOwZIIIrpoVeXj01gVp6G4Al0+MdekYO9QbVGX4WMX8+hMpUXs/M= github@secretive.burned-apple.local";
    };
    cachix = {
      name = "vaporif";
      publicKey = "vaporif.cachix.org-1:y/fKd8ILM10UJCdXFFYn/n8+AqXnRLzwHjX+BikcUf8=";
    };
    # mkDefault so a host without an age key can opt out (secrets.enable = false).
    secrets.enable = lib.mkDefault true;
    timezone = "Europe/Lisbon";

    # Full bookmark set; hosts override (e.g. work-nixos trims to a subset).
    yaziBookmarks = lib.mkDefault [
      {
        key = "r";
        path = "~/Repos/";
        desc = "Go to [r]epos";
      }
      {
        key = "a";
        path = "~/Repos/nephila";
        desc = "Go to nephil[a]";
      }
      {
        key = "p";
        path = "~/Repos/parry-guard";
        desc = "Go to [p]arry-guard";
      }
      {
        key = "m";
        path = "~/Repos/mercury";
        desc = "Go to [m]ercury";
      }
      {
        key = "k";
        path = "~/Repos/kingdom";
        desc = "Go to [k]ingdom";
      }
      {
        key = "c";
        path = "~/Repos/monorepo";
        desc = "Go to [c]ommonware";
      }
      {
        key = "n";
        path = config.custom.configPath;
        desc = "Go to [n]ix";
      }
      {
        key = "l";
        path = "~/Repos/logos";
        desc = "Go to [l]ogos";
      }
    ];
  };
}
