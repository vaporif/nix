{
  callPackage,
  runCommand,
  lib,
  stdenv,
}: let
  src = callPackage ./src.nix {};
in rec {
  inherit (src) packageVersion firefox source;

  extraPatches = ["${source}/patches/pref-pane/pref-pane-small.patch"];

  extraConfigureFlags =
    [
      "--with-unsigned-addon-scopes=app,system"
      "--disable-default-browser-agent"
      # Flags based on discussion in https://github.com/NixOS/nixpkgs/issues/482250
      "--disable-debug"
      "--disable-debug-symbols"
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      "--enable-lto=thin,cross"
    ];

  extraPreConfigure = ''
    export MOZ_TELEMETRY_REPORTING=
  '';

  extraPostPatch = ''
    # disable-data-reporting-at-compile-time.patch edits the vendored glean-core
    # crate, so cargo's directory-source checksums must be updated to match or
    # the gkrust build aborts. The old/new hash pairs are read from upstream's
    # scripts/librewolf-patches.py so they track each release without a manual bump.
    glean_pairs=$(grep -oE "s/[0-9a-f]{64}/[0-9a-f]{64}/g' third_party/rust/glean-core/\.cargo-checksum\.json" \
      ${source}/scripts/librewolf-patches.py | cut -d/ -f2,3)
    if [ -z "$glean_pairs" ]; then
      echo "no glean-core checksum rewrites found in librewolf-patches.py" >&2
      exit 1
    fi
    for pair in $glean_pairs; do
      substituteInPlace third_party/rust/glean-core/.cargo-checksum.json \
        --replace-fail "''${pair%/*}" "''${pair#*/}"
    done

    while read patch_name; do
      echo "applying LibreWolf patch: $patch_name"
      patch -p1 < ${source}/$patch_name
    done <${source}/assets/patches.txt

    rm toolkit/components/ml/content/backends/OpenAIPipeline.mjs
    rm -rf toolkit/components/ml/vendor/openai

    cp -r ${source}/themes/browser .

    # icons referenced by webgl-permission.patch's jar.mn entries
    cp ${source}/assets/icons/* browser/themes/shared/icons/

    cp ${source}/assets/search-config-v2.json services/settings/dumps/main/search-config-v2.json
    cp ${source}/assets/search-config-icons.json services/settings/dumps/main/search-config-icons.json
    # mojeek search engine icon
    cp ${source}/assets/2c4b8834-030c-4097-a887-c7506689095c services/settings/dumps/main/search-config-icons/
    cp ${source}/assets/2c4b8834-030c-4097-a887-c7506689095c.meta.json services/settings/dumps/main/search-config-icons/

    sed -i '/MOZ_SERVICES_HEALTHREPORT/ s/True/False/' browser/moz.configure

    cp ${source}/patches/pref-pane/category-librewolf.svg browser/themes/shared/preferences
    cp ${source}/patches/pref-pane/librewolf.css browser/themes/shared/preferences
    cp ${source}/patches/pref-pane/librewolf.inc.xhtml browser/components/preferences
    cp ${source}/patches/pref-pane/librewolf.js browser/components/preferences

    # override firefox version
    for fn in browser/config/version.txt browser/config/version_display.txt; do
      echo "${packageVersion}" > "$fn"
    done

    echo "patching appstrings.properties"
    find . -path '*/appstrings.properties' -exec sed -i s/Firefox/LibreWolf/ {} \;

    for fn in $(find "${source}/l10n/en-US/browser" -type f -name '*.inc.*'); do
      target_fn=$(echo "$fn" | sed "s,${source}/l10n/en-US/browser,browser/locales/en-US," | sed "s,\.inc,,")
      cat "$fn" >> "$target_fn"
    done
  '';

  localSettingsPrefs = runCommand "local-settings.js" {} ''
    # Import of `librewolf.cfg` file is already being done manually.
    substitute ${source}/settings/defaults/pref/local-settings.js $out \
      --replace-fail 'pref("general.config.filename", "librewolf.cfg");' ""
  '';

  extraPrefsFiles = [
    "${source}/settings/librewolf.cfg"
    localSettingsPrefs
  ];

  extraPoliciesFiles = ["${source}/settings/distribution/policies.json"];

  extraPassthru = {
    librewolf = {
      inherit src extraPatches;
    };
    inherit extraPrefsFiles extraPoliciesFiles;
  };
}
