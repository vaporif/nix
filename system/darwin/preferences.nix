# macOS system.defaults (dock, finder, NSGlobalDomain, etc.)
_: {
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.2;
      mru-spaces = false;
      wvous-br-corner = 1;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
      AppleShowAllFiles = true;
      NewWindowTarget = "Home";
      ShowPathbar = true;
    };
    NSGlobalDomain = {
      "com.apple.sound.beep.volume" = 0.0;
      AppleShowAllFiles = true;
      AppleShowScrollBars = "WhenScrolling";
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

      # --- Miscellaneous privacy ---
      "com.apple.lookup.shared".LookupSuggestionsDisabled = true;
      "com.apple.ImageCapture".disableHotPlug = true;
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    };
  };
}
