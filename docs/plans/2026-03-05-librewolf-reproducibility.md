# LibreWolf Reproducible Configuration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make LibreWolf extensions and preferences declarative via Nix, auto-deployed on `just switch`.

**Architecture:** New `home/common/librewolf.nix` module generates `policies.json` (extensions + search engines) and `librewolf.overrides.cfg` (preferences) as `home.file` entries. Install script copies policies.json into the app bundle post-install.

**Tech Stack:** Nix (home-manager `home.file`), `builtins.toJSON` for policies.json, bash for install script

---

### Task 1: Create `home/common/librewolf.nix`

**Files:**
- Create: `home/common/librewolf.nix`

**Step 1: Create the Nix module**

```nix
{
  lib,
  pkgs,
  ...
}: let
  # AMO install URL helper
  amoUrl = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";

  # Extensions to auto-install (ID -> AMO slug)
  # Excludes: MetaMask (webextension@metamask.io), polkadot{.js} ({7e3ce1f0-...})
  extensions = {
    "uBlock0@raymondhill.net" = "ublock-origin";
    "jid1-MnnxcxisBPnSXQ@jetpack" = "privacy-badger17";
    "CanvasBlocker@kkapsner.de" = "canvasblocker";
    "jid1-KKzOGWgsW3Ao4Q@jetpack" = "i-dont-care-about-cookies";
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = "bitwarden-password-manager";
    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = "vimium-ff";
    "{3c078156-979c-498b-8990-85f7987dd929}" = "sidebery";
    "sponsorBlocker@ajay.app" = "sponsorblock";
    "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = "return-youtube-dislikes";
    "myallychou@gmail.com" = "youtube-recommended-videos";
    "{e14163a1-321a-4c12-a85d-1f25d68fe047}" = "distraction-free-reddit";
    "{39ec6c53-67ca-42cc-9f23-339cca400ef2}" = "everforest1";
    "{44e65aeb-7d24-440c-8710-918d2111d4f1}" = "greyscale";
    "{a017b609-a39f-46a9-82c8-27bdf87b8a62}" = "everforest-light-soft";
  };

  # Build ExtensionSettings attrset for policies.json
  extensionSettings =
    (lib.mapAttrs (_id: slug: {
        install_url = amoUrl slug;
        installation_mode = "normal_installed";
      })
      extensions)
    // {
      # Block unwanted search engine extensions
      "google@search.mozilla.org".installation_mode = "blocked";
      "bing@search.mozilla.org".installation_mode = "blocked";
      "amazondotcom@search.mozilla.org".installation_mode = "blocked";
      "ebay@search.mozilla.org".installation_mode = "blocked";
      "twitter@search.mozilla.org".installation_mode = "blocked";
    };

  policies = {
    policies = {
      AppUpdateURL = "https://localhost";
      DisableAppUpdate = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DisableSystemAddonUpdate = true;
      DisableProfileImport = false;
      DisableFirefoxStudies = true;
      DisableTelemetry = true;
      DisableFeedbackCommands = true;
      DisablePocket = true;
      DisableSetDesktopBackground = false;
      DisableDeveloperTools = false;
      NoDefaultBookmarks = true;
      SkipTermsOfUse = true;
      ExtensionSettings = extensionSettings;
      SearchEngines = {
        PreventInstalls = false;
        Default = "DuckDuckGo";
        Remove = ["Google" "Bing" "Amazon.com" "eBay" "Twitter" "Perplexity"];
        Add = [
          {
            Name = "DuckDuckGo Lite";
            Description = "Minimal, ad-free version of DuckDuckGo";
            Alias = "";
            Method = "POST";
            URLTemplate = "https://start.duckduckgo.com/lite/?q={searchTerms}";
            PostData = "q={searchTerms}";
            SuggestURLTemplate = "https://ac.duckduckgo.com/ac/?q={searchTerms}&type=list";
          }
          {
            Name = "Searx Belgium";
            Description = "A privacy-respecting, open metasearch engine";
            Alias = "";
            Method = "POST";
            URLTemplate = "https://searx.be/?q={searchTerms}";
            PostData = "q={searchTerms}&category_general=on";
            SuggestURLTemplate = "https://searx.be/autocompleter?q={searchTerms}";
          }
          {
            Name = "MetaGer";
            Description = "Search safely while having your privacy respected";
            Alias = "";
            Method = "GET";
            URLTemplate = "https://metager.org/meta/meta.ger3?eingabe={searchTerms}";
            SuggestURLTemplate = "https://metager.org/suggest?query={searchTerms}";
          }
          {
            Name = "Startpage";
            Description = "Search and browse the internet without being tracked or targeted";
            Alias = "";
            Method = "GET";
            URLTemplate = "https://www.startpage.com/sp/search?query={searchTerms}&cat=web&pl=opensearch";
            SuggestURLTemplate = "https://www.startpage.com/osuggestions?q={searchTerms}";
          }
          {
            Name = "Mojeek";
            Description = "A web search engine that provides unbiased, fast, and relevant search results combined with a no tracking privacy policy";
            Alias = "";
            Method = "GET";
            URLTemplate = "https://www.mojeek.com/search?q={searchTerms}";
          }
        ];
      };
      SupportMenu = {
        Title = "LibreWolf Issue Tracker";
        URL = "https://codeberg.org/librewolf/issues";
      };
    };
  };

  overridesCfg = ''
    // === DNS over HTTPS — Quad9 ===
    defaultPref("network.trr.mode", 3);
    defaultPref("network.trr.uri", "https://dns.quad9.net/dns-query");

    // === UI ===
    defaultPref("sidebar.verticalTabs", true);
    defaultPref("sidebar.revamp", true);
    defaultPref("browser.toolbars.bookmarks.visibility", "never");
    defaultPref("browser.ctrlTab.sortByRecentlyUsed", true);
    defaultPref("browser.startup.page", 3);

    // === Font ===
    defaultPref("font.name.serif.x-western", "3270Medium Nerd Font Mono");

    // === Content blocking (strict) ===
    defaultPref("browser.contentblocking.category", "strict");
    defaultPref("privacy.trackingprotection.enabled", true);
    defaultPref("privacy.trackingprotection.socialtracking.enabled", true);
    defaultPref("privacy.trackingprotection.emailtracking.enabled", true);
    defaultPref("privacy.annotate_channels.strict_list.enabled", true);
    defaultPref("privacy.query_stripping.enabled", true);
    defaultPref("privacy.query_stripping.enabled.pbmode", true);
    defaultPref("privacy.fingerprintingProtection", true);
    defaultPref("privacy.bounceTrackingProtection.mode", 1);

    // === Clear on shutdown ===
    defaultPref("privacy.history.custom", true);
    defaultPref("privacy.sanitize.timeSpan", 4);

    // === Network ===
    defaultPref("network.prefetch-next", false);
    defaultPref("network.predictor.enabled", false);
    defaultPref("network.captive-portal-service.enabled", false);
    defaultPref("network.connectivity-service.enabled", false);
    defaultPref("network.early-hints.preconnect.max_connections", 0);

    // === Privacy ===
    defaultPref("privacy.resistFingerprinting.letterboxing", true);
    defaultPref("webgl.disabled", false);
    defaultPref("extensions.pocket.enabled", false);
    defaultPref("network.http.referer.XOriginPolicy", 2);
    defaultPref("network.http.referer.XOriginTrimmingPolicy", 2);
    defaultPref("browser.search.suggest.enabled", false);
    defaultPref("browser.urlbar.suggest.searches", false);
    defaultPref("network.http.speculative-parallel-limit", 0);
    defaultPref("browser.urlbar.speculativeConnect.enabled", false);

    // === Security ===
    defaultPref("dom.security.https_only_mode_ever_enabled", true);
    defaultPref("security.tls.enable_0rtt_data", false);
    defaultPref("permissions.delegation.enabled", false);

    // === Performance ===
    defaultPref("gfx.webrender.all", true);
    defaultPref("layers.acceleration.force-enabled", true);
    defaultPref("general.smoothScroll", true);

    // === Fullscreen ===
    defaultPref("full-screen-api.transition-duration.enter", "0 0");
    defaultPref("full-screen-api.transition-duration.leave", "0 0");

    // === DRM (streaming) ===
    defaultPref("media.eme.enabled", true);

    // === Safe browsing ===
    defaultPref("browser.safebrowsing.blockedURIs.enabled", true);
    defaultPref("browser.safebrowsing.malware.enabled", true);
    defaultPref("browser.safebrowsing.phishing.enabled", true);
    defaultPref("browser.safebrowsing.downloads.enabled", true);

    // === Translation ===
    defaultPref("browser.translations.neverTranslateLanguages", "ru");
  '';
in {
  home.file = {
    ".librewolf/policies.json".text = builtins.toJSON policies;
    ".librewolf/librewolf.overrides.cfg".text = overridesCfg;
  };
}
```

Write this file to `home/common/librewolf.nix`.

**Step 2: Verify Nix evaluation**

Run: `nix eval --impure --expr '(import ./home/common/librewolf.nix { lib = (import <nixpkgs> {}).lib; pkgs = import <nixpkgs> {}; }).home.file.".librewolf/policies.json".text' 2>&1 | head -5`

This should output JSON starting with `{"policies":`. If it errors, fix the syntax.

**Step 3: Commit**

```bash
git add home/common/librewolf.nix
git commit -m "feat: add librewolf.nix module for reproducible config"
```

---

### Task 2: Wire module into home-manager

**Files:**
- Modify: `home/common/default.nix`

**Step 1: Add import and remove old override**

In `home/common/default.nix`:

1. Add `./librewolf.nix` to the `imports` list (after `./neovim.nix`).

2. Remove this line from `home.file`:
```nix
      ".librewolf/librewolf.overrides.cfg".source = ../../config/librewolf/librewolf.overrides.cfg;
```

The result should look like:

```nix
  imports = [
    ../../modules/options.nix
    ./claude.nix
    ./git.nix
    ./ssh.nix
    ./mcp.nix
    ./qdrant.nix
    ./xdg.nix
    ./packages.nix
    ./shell.nix
    ./neovim.nix
    ./librewolf.nix
  ];
```

And `home.file` should only have:
```nix
    file = {
      ".envrc".text = ''
        use flake "github:vaporif/nix-devshells/${inputs.nix-devshells.rev}"
      '';
    };
```

**Step 2: Delete old static config**

```bash
rm config/librewolf/librewolf.overrides.cfg
rmdir config/librewolf  # remove empty dir
```

**Step 3: Verify Nix evaluation**

Run: `nix flake check 2>&1 | tail -20`

Expected: no errors. If there's a conflict on `.librewolf/librewolf.overrides.cfg` (defined in two places), the old `home.file` entry wasn't properly removed.

**Step 4: Commit**

```bash
git add home/common/default.nix
git rm config/librewolf/librewolf.overrides.cfg
git commit -m "wire librewolf.nix into home-manager, remove static config"
```

---

### Task 3: Update install script to deploy policies.json

**Files:**
- Modify: `scripts/install-librewolf.sh`

**Step 1: Add policies deployment after app copy**

In `scripts/install-librewolf.sh`, add these lines after line 145 (`cp -R "${VOLUME_PATH}/${APP_NAME}" "${INSTALL_PATH}/"`), before the "Unmount DMG" section:

```bash
    # Deploy Nix-generated policies.json into the app bundle
    POLICIES_SRC="${HOME}/.librewolf/policies.json"
    POLICIES_DST="${INSTALL_PATH}/${APP_NAME}/Contents/Resources/distribution/policies.json"
    if [[ -f "${POLICIES_SRC}" ]]; then
        echo "Deploying custom policies.json..."
        cp "${POLICIES_SRC}" "${POLICIES_DST}"
    fi
```

The section should read:

```bash
    # Copy app to Applications
    echo "Installing LibreWolf to ${INSTALL_PATH}..."
    cp -R "${VOLUME_PATH}/${APP_NAME}" "${INSTALL_PATH}/"

    # Deploy Nix-generated policies.json into the app bundle
    POLICIES_SRC="${HOME}/.librewolf/policies.json"
    POLICIES_DST="${INSTALL_PATH}/${APP_NAME}/Contents/Resources/distribution/policies.json"
    if [[ -f "${POLICIES_SRC}" ]]; then
        echo "Deploying custom policies.json..."
        cp "${POLICIES_SRC}" "${POLICIES_DST}"
    fi

    # Unmount DMG
    echo "Cleaning up..."
```

**Step 2: Verify shellcheck passes**

Run: `shellcheck scripts/install-librewolf.sh`

Expected: no new warnings (existing SC2310 suppression is fine).

**Step 3: Commit**

```bash
git add scripts/install-librewolf.sh
git commit -m "deploy policies.json into LibreWolf app bundle post-install"
```

---

### Task 4: Verify end-to-end with `just switch`

**Step 1: Run lint checks**

Run: `just check`

Expected: all checks pass (alejandra, statix, deadnix, shellcheck).

**Step 2: Apply configuration**

Run: `just switch`

Expected: home-manager activates successfully, creates `~/.librewolf/policies.json` and `~/.librewolf/librewolf.overrides.cfg`.

**Step 3: Verify generated files**

Run: `cat ~/.librewolf/policies.json | python3 -m json.tool | head -30`

Expected: valid JSON with `ExtensionSettings` containing all 14 extensions.

Run: `head -10 ~/.librewolf/librewolf.overrides.cfg`

Expected: starts with `// === DNS over HTTPS` section.

**Step 4: Verify policies.json in app bundle (if LibreWolf was installed)**

Run: `diff <(cat ~/.librewolf/policies.json | python3 -m json.tool) <(cat /Applications/LibreWolf.app/Contents/Resources/distribution/policies.json | python3 -m json.tool) 2>/dev/null && echo "MATCH" || echo "DIFFERS (expected if LibreWolf was already up-to-date and script skipped)"`

Note: If LibreWolf was already installed and up-to-date, the install script would have exited early without copying. The policies.json will be deployed on the next actual install/update. To force test, temporarily remove LibreWolf and re-run `just switch`.

**Step 5: Manual smoke test**

1. Quit LibreWolf if running
2. Manually copy policies: `cp ~/.librewolf/policies.json /Applications/LibreWolf.app/Contents/Resources/distribution/policies.json`
3. Launch LibreWolf
4. Check `about:policies` — should show all extension and search engine policies
5. Check `about:addons` — extensions should be installing/installed
6. Check `about:preferences#search` — DuckDuckGo default, Google/Bing/etc. removed
