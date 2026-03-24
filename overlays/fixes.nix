_: prev: let
  inherit (prev) lib;
in
  {
    # Skip rocksdict tests (crash on macOS after nixpkgs update)
    pythonPackagesExtensions =
      prev.pythonPackagesExtensions
      ++ lib.optionals prev.stdenv.isDarwin [
        (_: python-prev: {
          rocksdict = python-prev.rocksdict.overrideAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
            pytestCheckPhase = "";
          });
          # Skip jeepney checks (dbus + trio/outcome unavailable on macOS)
          jeepney = python-prev.jeepney.overrideAttrs (_: {
            doInstallCheck = false;
            pythonImportsCheck = [];
          });
        })
      ];

    # Disable ffmpeg due to CVEs (video previews disabled in yazi.toml anyway)
    yazi = prev.yazi.override {
      optionalDeps = with prev; [
        jq
        poppler-utils
        _7zz
        fd
        ripgrep
        fzf
        zoxide
        chafa
        resvg
      ];
    };

    # Skip ast-grep check (test_scan_invalid_rule_id fails with illegal byte sequence in sandbox)
    ast-grep = prev.ast-grep.overrideAttrs (_: {
      doCheck = false;
    });
  }
  // lib.optionalAttrs prev.stdenv.isDarwin {
    # Skip curl-impersonate check (AppleIDN not compiled on macOS 15)
    curl-impersonate = prev.curl-impersonate.overrideAttrs (_: {
      doCheck = false;
    });

    # Fix direnv build: -linkmode=external requires cgo but it's disabled upstream
    direnv = prev.direnv.overrideAttrs (old: {
      env = (old.env or {}) // {CGO_ENABLED = "1";};
    });
  }
