_: {
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
      ];
    };
    user = "vaporif";
    git = {
      name = "Dmytro Onypko";
      email = "vaporif@proton.me";
      signingKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBP7sf4L6CNhRgdRKmXH2H7xxWTEWMTCS/oOkOwZIIIrpoVeXj01gVp6G4Al0+MdekYO9QbVGX4WMX8+hMpUXs/M= github@secretive.burned-apple.local";
    };
    cachix = {
      name = "vaporif";
      publicKey = "vaporif.cachix.org-1:y/fKd8ILM10UJCdXFFYn/n8+AqXnRLzwHjX+BikcUf8=";
    };
    secrets.enable = true;
    timezone = "Europe/Lisbon";
  };
}
