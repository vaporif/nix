{lib, ...}: let
  extensions = {
    "uBlock0@raymondhill.net" = {
      slug = "ublock-origin";
      private_browsing = true;
    };
    "jid1-MnnxcxisBPnSXQ@jetpack" = {slug = "privacy-badger17";};
    "jid1-KKzOGWgsW3Ao4Q@jetpack" = {slug = "i-dont-care-about-cookies";};
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {slug = "bitwarden-password-manager";};
    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {slug = "vimium-ff";};
    "{3c078156-979c-498b-8990-85f7987dd929}" = {slug = "sidebery";};
    "sponsorBlocker@ajay.app" = {slug = "sponsorblock";};
    "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {slug = "return-youtube-dislikes";};
    "myallychou@gmail.com" = {slug = "youtube-recommended-videos";};
    "{e14163a1-321a-4c12-a85d-1f25d68fe047}" = {slug = "distraction-free-reddit";};
    "{39ec6c53-67ca-42cc-9f23-339cca400ef2}" = {slug = "everforest1";};
    "{44e65aeb-7d24-440c-8710-918d2111d4f1}" = {slug = "greyscale";};
    "{a017b609-a39f-46a9-82c8-27bdf87b8a62}" = {slug = "everforest-light-soft";};
  };

  blockedSearchEngines = [
    "google@search.mozilla.org"
    "bing@search.mozilla.org"
    "amazondotcom@search.mozilla.org"
    "ebay@search.mozilla.org"
    "twitter@search.mozilla.org"
  ];

  extensionSettings =
    builtins.mapAttrs (_: ext:
      {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";
        installation_mode = "normal_installed";
      }
      // lib.optionalAttrs (ext ? private_browsing) {
        inherit (ext) private_browsing;
      })
    extensions
    // builtins.listToAttrs (builtins.map (id: {
        name = id;
        value = {installation_mode = "blocked";};
      })
      blockedSearchEngines);

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
      WebsiteFilter = {
        Block = ["https://localhost/*"];
        Exceptions = ["https://localhost/*"];
      };
      SupportMenu = {
        Title = "LibreWolf Issue Tracker";
        URL = "https://codeberg.org/librewolf/issues";
      };

      ExtensionSettings = extensionSettings;

      SearchEngines = {
        Default = "DuckDuckGo";
        Remove = ["Google" "Bing" "Amazon.com" "eBay" "Twitter" "Perplexity"];
        PreventInstalls = false;
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
    };
  };

  overridesCfg = ''
    // === Privacy & Fingerprinting ===
    defaultPref("privacy.resistFingerprinting.letterboxing", true);
    defaultPref("privacy.fingerprintingProtection", true);
    defaultPref("privacy.trackingprotection.enabled", true);
    defaultPref("privacy.trackingprotection.socialtracking.enabled", true);
    defaultPref("privacy.trackingprotection.emailtracking.enabled", true);
    defaultPref("privacy.annotate_channels.strict_list.enabled", true);
    defaultPref("privacy.query_stripping.enabled", true);
    defaultPref("privacy.query_stripping.enabled.pbmode", true);
    defaultPref("privacy.bounceTrackingProtection.mode", 1);
    defaultPref("privacy.globalprivacycontrol.was_ever_enabled", true);
    defaultPref("privacy.history.custom", true);
    defaultPref("privacy.sanitize.timeSpan", 4);

    // === DNS over HTTPS (Quad9) ===
    defaultPref("network.trr.mode", 3);
    defaultPref("network.trr.uri", "https://dns.quad9.net/dns-query");

    // === Network ===
    defaultPref("network.http.referer.XOriginPolicy", 2);
    defaultPref("network.http.referer.XOriginTrimmingPolicy", 2);
    defaultPref("network.http.speculative-parallel-limit", 0);
    defaultPref("network.prefetch-next", false);
    defaultPref("network.predictor.enabled", false);
    defaultPref("network.captive-portal-service.enabled", false);
    defaultPref("network.connectivity-service.enabled", false);
    defaultPref("network.early-hints.preconnect.max_connections", 0);

    // === Content blocking ===
    defaultPref("browser.contentblocking.category", "strict");

    // === UI ===
    defaultPref("sidebar.verticalTabs", true);
    defaultPref("sidebar.revamp", true);
    defaultPref("browser.toolbars.bookmarks.visibility", "never");
    defaultPref("browser.ctrlTab.sortByRecentlyUsed", true);
    defaultPref("browser.startup.page", 3);
    defaultPref("browser.urlbar.speculativeConnect.enabled", false);

    // === Font ===
    defaultPref("font.name.serif.x-western", "3270Medium Nerd Font Mono");

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

    // === Search ===
    defaultPref("browser.search.suggest.enabled", false);
    defaultPref("browser.urlbar.suggest.searches", false);

    // === Misc ===
    defaultPref("extensions.pocket.enabled", false);
    defaultPref("webgl.disabled", false);
    defaultPref("browser.translations.neverTranslateLanguages", "ru");
  '';
in {
  home.file = {
    ".librewolf/policies.json".text = builtins.toJSON policies;
    ".librewolf/librewolf.overrides.cfg".text = overridesCfg;
  };
}
