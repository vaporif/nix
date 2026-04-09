{lib, ...}: let
  bitwardenId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
  vimiumId = "{d7742d87-e61d-4b78-b8a1-b469842139fa}";
  vimiumNewTabId = "@vimium-new-tab";
  sideberyId = "{3c078156-979c-498b-8990-85f7987dd929}";
  returnYtDislikesId = "{762f9885-5a13-4abd-9c77-433dcd38b8fd}";
  distractionFreeRedditId = "{e14163a1-321a-4c12-a85d-1f25d68fe047}";
  everforestId = "{39ec6c53-67ca-42cc-9f23-339cca400ef2}";
  greyscaleId = "{44e65aeb-7d24-440c-8710-918d2111d4f1}";
  everforestLightId = "{a017b609-a39f-46a9-82c8-27bdf87b8a62}";

  extensions = {
    "uBlock0@raymondhill.net" = {
      slug = "ublock-origin";
      private_browsing = true;
    };
    "jid1-MnnxcxisBPnSXQ@jetpack" = {slug = "privacy-badger17";};
    "jid1-KKzOGWgsW3Ao4Q@jetpack" = {slug = "i-dont-care-about-cookies";};
    ${bitwardenId} = {slug = "bitwarden-password-manager";};
    ${vimiumId} = {slug = "vimium-ff";};
    ${sideberyId} = {slug = "sidebery";};
    ${vimiumNewTabId} = {slug = "vimium-new-tab-page";};
    "sponsorBlocker@ajay.app" = {slug = "sponsorblock";};
    ${returnYtDislikesId} = {slug = "return-youtube-dislikes";};
    "myallychou@gmail.com" = {slug = "youtube-recommended-videos";};
    ${distractionFreeRedditId} = {slug = "distraction-free-reddit";};
    ${everforestId} = {slug = "everforest1";};
    ${greyscaleId} = {slug = "greyscale";};
    ${everforestLightId} = {slug = "everforest-light-soft";};
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
in {
  programs.librewolf = {
    enable = true;

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

    profiles.default = {
      isDefault = true;
      settings = {
        # Privacy & Fingerprinting
        "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.fingerprintingProtection" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.annotate_channels.strict_list.enabled" = true;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;
        "privacy.bounceTrackingProtection.mode" = 1;
        "privacy.globalprivacycontrol.was_ever_enabled" = true;
        "privacy.history.custom" = true;
        "privacy.sanitize.timeSpan" = 4;

        # DNS over HTTPS (Quad9)
        "network.trr.mode" = 3;
        "network.trr.uri" = "https://dns.quad9.net/dns-query";

        # Network
        "network.http.referer.XOriginPolicy" = 2;
        "network.http.referer.XOriginTrimmingPolicy" = 2;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;
        "network.predictor.enabled" = false;
        "network.captive-portal-service.enabled" = false;
        "network.connectivity-service.enabled" = false;
        "network.early-hints.preconnect.max_connections" = 0;

        # Content blocking
        "browser.contentblocking.category" = "strict";

        # UI
        "sidebar.verticalTabs" = true;
        "sidebar.revamp" = true;
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        "browser.startup.page" = 3;
        "browser.urlbar.speculativeConnect.enabled" = false;

        # Security
        "dom.security.https_only_mode_ever_enabled" = true;
        "security.tls.enable_0rtt_data" = false;
        "permissions.delegation.enabled" = false;

        # Performance
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;
        "general.smoothScroll" = true;

        # Fullscreen
        "full-screen-api.transition-duration.enter" = "0 0";
        "full-screen-api.transition-duration.leave" = "0 0";

        # DRM (streaming)
        "media.eme.enabled" = true;

        # Safe browsing
        "browser.safebrowsing.blockedURIs.enabled" = true;
        "browser.safebrowsing.malware.enabled" = true;
        "browser.safebrowsing.phishing.enabled" = true;
        "browser.safebrowsing.downloads.enabled" = true;

        # Search
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;

        # Misc
        "extensions.pocket.enabled" = false;
        "webgl.disabled" = false;
        "browser.translations.neverTranslateLanguages" = "ru";
      };
    };
  };
}
