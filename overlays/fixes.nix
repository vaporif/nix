_: prev: let
  inherit (prev) lib;
in
  {
    pythonPackagesExtensions =
      prev.pythonPackagesExtensions
      # Skip aioboto3 tests (moto mock server sends duplicate Server header, rejected by newer aiohttp)
      ++ [
        (_: python-prev: {
          aioboto3 = python-prev.aioboto3.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
        })
      ]
      # Skip jeepney checks (dbus + trio/outcome unavailable on macOS)
      ++ lib.optionals prev.stdenv.isDarwin [
        (_: python-prev: {
          jeepney = python-prev.jeepney.overrideAttrs (_: {
            doInstallCheck = false;
            pythonImportsCheck = [];
          });
        })
      ]
      # lupa 2.7 bundles x86_64 libluajit.a — linker fails on aarch64-linux
      ++ lib.optionals (prev.stdenv.isLinux && prev.stdenv.isAarch64) [
        (_: python-prev: {
          lupa = python-prev.lupa.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or []) ++ ["luajit"];
            env = (old.env or {}) // {LUPA_NO_LUAJIT = "true";};
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
  }
  # deno: drop stale patch (fd331552) that's already applied upstream — breaks aarch64-linux build
  // lib.optionalAttrs (prev.stdenv.isLinux && prev.stdenv.isAarch64) {
    deno = prev.deno.overrideAttrs (old: {
      patches = lib.filter (p: !(lib.hasSuffix "fd331552de39501d47c43dc4b0c637b969402ab1.patch" (toString p))) (old.patches or []);
    });
  }
  // lib.optionalAttrs prev.stdenv.isDarwin {
    # Skip ast-grep check (test_scan_invalid_rule_id fails with illegal byte sequence in sandbox)
    ast-grep = prev.ast-grep.overrideAttrs (_: {
      doCheck = false;
    });

    # Skip curl-impersonate check (AppleIDN not compiled on macOS 15)
    curl-impersonate = prev.curl-impersonate.overrideAttrs (_: {
      doCheck = false;
    });

    # Fix direnv build: -linkmode=external requires cgo but it's disabled upstream; tests hang in sandbox
    direnv = prev.direnv.overrideAttrs (old: {
      doCheck = false;
      env = (old.env or {}) // {CGO_ENABLED = "1";};
    });

    # Skip duckdb tests (Trace/BPT trap crash on CI macOS runners)
    duckdb = prev.duckdb.overrideAttrs (_: {
      doInstallCheck = false;
    });
  }
