# macOS system.defaults (dock, finder, NSGlobalDomain, etc.)
_: {
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.2;
      autohide-time-modifier = 0.4;
      mru-spaces = false;
      wvous-br-corner = 1;
      show-recents = false;
      tilesize = 48;
      minimize-to-application = true;
      launchanim = false;
      expose-animation-duration = 0.1;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
      AppleShowAllFiles = true;
      NewWindowTarget = "Home";
      ShowPathbar = true;
      ShowStatusBar = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXRemoveOldTrashItems = true;
      _FXShowPosixPathInTitle = true;
      CreateDesktop = false;
    };
    NSGlobalDomain = {
      "com.apple.sound.beep.volume" = 0.0;
      AppleShowAllFiles = true;
      AppleShowScrollBars = "WhenScrolling";
      NSAutomaticWindowAnimationsEnabled = false;
    };
    screencapture.location = "~/screenshots";
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };
    loginwindow = {
      GuestEnabled = false;
      LoginwindowText = "derp durp";
      SHOWFULLNAME = true;
      DisableConsoleAccess = true;
    };
    LaunchServices.LSQuarantine = true;
    smb = {
      NetBIOSName = "localhost";
      ServerDescription = "";
    };
    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfMonth = true;
    };
    CustomUserPreferences = {
      # --- General safety ---
      "com.apple.remoteappleevents".enabled = false;
      "com.apple.CrashReporter".DialogType = "none";
      NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
      "com.apple.Terminal".SecureKeyboardEntry = true;

      # --- Siri ---
      "com.apple.assistant.support" = {
        "Siri Data Sharing Opt-In Status" = 0;
        "Assistant Enabled" = false;
      };
      "com.apple.Siri".StatusMenuVisible = false;

      # --- Advertising & tracking ---
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        forceLimitAdTracking = true;
        allowIdentifierForAdvertising = false;
      };

      # --- Diagnostics & analytics ---
      "com.apple.SubmitDiagInfo".AutoSubmit = false;
      "com.apple.UsageTracking" = {
        CoreDonationsEnabled = false;
        UDCAutomationEnabled = false;
      };

      # --- Metadata leakage ---
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      # --- Animations ---
      "com.apple.dock" = {
        expose-animation-duration = 0.1;
        springboard-show-duration = 0.1;
        springboard-hide-duration = 0.1;
      };

      # --- Miscellaneous privacy ---
      "com.apple.lookup.shared".LookupSuggestionsDisabled = true;
      "com.apple.ImageCapture".disableHotPlug = true;
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    };
  };
}
