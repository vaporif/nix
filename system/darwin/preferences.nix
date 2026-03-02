# macOS system.defaults (dock, finder, NSGlobalDomain, etc.)
{user, ...}: {
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
    screensaver.askForPasswordDelay = 0;
    loginwindow = {
      GuestEnabled = false;
      LoginwindowText = "derp durp";
      autoLoginUser = user;
    };
    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfMonth = true;
    };
    CustomUserPreferences = {
      "com.apple.remoteappleevents".enabled = false;
      "com.apple.assistant.support"."Siri Data Sharing Opt-In Status" = 0;
      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      "com.apple.CrashReporter".DialogType = "none";
      NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
      # Secure keyboard entry - prevents keyloggers from capturing terminal input
      "com.apple.Terminal".SecureKeyboardEntry = true;
    };
  };
}
