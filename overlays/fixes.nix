_: prev: let
  inherit (prev) lib;

  # TODO: Remove once nixpkgs ships vimPlugins.blink-pairs >= 0.5.0.
  # v0.4.1 uses std::simd::{LaneCount, SupportedLaneCount}, which were
  # removed from the std::simd API. Upstream v0.5.0 switched to Select.
  # See https://github.com/Saghen/blink.pairs/releases/tag/v0.5.0
  blinkPairsVersion = "0.5.0";
  blinkPairsSrc = prev.fetchFromGitHub {
    owner = "Saghen";
    repo = "blink.pairs";
    tag = "v${blinkPairsVersion}";
    hash = "sha256-PTbj6jlXNRUOmwFSplvRDDiyyGqkBzUKtuBrvZm9kzM=";
  };
  # v0.5.0's vendored cargo deps hash matches v0.4.1's, so the parent
  # derivation's cargoHash carries over unchanged via overrideAttrs (which
  # can't reach buildRustPackage's internal FOD anyway).
  blinkPairsLib = prev.vimPlugins.blink-pairs.passthru.blink-pairs-lib.overrideAttrs (_: {
    version = blinkPairsVersion;
    src = blinkPairsSrc;
  });
  blinkPairsExt = prev.stdenv.hostPlatform.extensions.sharedLibrary;
in
  {
    vimPlugins =
      prev.vimPlugins
      // {
        blink-pairs = prev.vimPlugins.blink-pairs.overrideAttrs (old: {
          version = blinkPairsVersion;
          src = blinkPairsSrc;
          # v0.5.0 ships a repro.lua at the project root that loads plugin
          # internals; the neovim require-check can't resolve it standalone.
          nvimSkipModules = (old.nvimSkipModules or []) ++ ["repro"];
          preInstall = ''
            mkdir -p target/release
            ln -s ${blinkPairsLib}/lib/libblink_pairs${blinkPairsExt} target/release/
          '';
          passthru = (old.passthru or {}) // {blink-pairs-lib = blinkPairsLib;};
        });
      };

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

    # Skip flaky mcp-nixos test (test_read_text_file matches "Error" in store file content)
    mcp-nixos = prev.mcp-nixos.overrideAttrs (_: {
      doInstallCheck = false;
    });

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
