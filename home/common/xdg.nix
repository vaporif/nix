{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  yaziBookmarkKeymap =
    lib.concatMapStrings (b: ''

      [[mgr.prepend_keymap]]
      on = ["b", "${b.key}"]
      run = "cd ${b.path}"
      desc = "${b.desc}"
    '')
    cfg.yaziBookmarks;
  c = config.lib.stylix.colors.withHashtag;
in {
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = builtins.replaceStrings ["@configPath@" "@agentDeckPath@"] [cfg.configPath "${inputs.wezterm-agent-deck}/plugin/init.lua"] (builtins.readFile ../../config/wezterm/init.lua);
  };

  # GUI-launched WezTerm spawns the first shell with a minimal launchd env (no
  # TERMINFO_DIRS), so zsh's zle can't find the `wezterm` terminfo at startup —
  # hence "can't find terminal definition for wezterm" and a broken keymap until
  # a second shell inherits TERMINFO_DIRS. ~/.terminfo is the one dir ncurses
  # always searches without any env var, so mirror the entry there.
  home.file.".terminfo" = {
    source = "${pkgs.wezterm.terminfo}/share/terminfo";
    recursive = true;
  };

  xdg.configFile =
    {
      "yazi/yazi.toml".source = ../../config/yazi/yazi.toml;
      "yazi/init.lua".source = ../../config/yazi/init.lua;
      "yazi/keymap.toml".text = (builtins.readFile ../../config/yazi/keymap.toml) + yaziBookmarkKeymap;
      "yazi/plugins/yamb.yazi" = {
        source = inputs.yamb-yazi;
        recursive = true;
      };
      "yazi/plugins/yafg.yazi" = {
        source = inputs.yafg-yazi;
        recursive = true;
      };
      "yazi/plugins/augment-command.yazi" = {
        source = inputs.augment-command-yazi;
        recursive = true;
      };
      "wezterm/colors/earthtone-light.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_light.toml";
      "wezterm/colors/earthtone-dark.toml".source = "${inputs.earthtone-nvim}/extras/wezterm_dark.toml";
    }
    # The work server authenticates via SAML, so there is no local password to
    # hand matterhorn — a token is the only login path. Both the token and the
    # host live in sops; modules/sops.nix renders the file at activation.
    // lib.optionalAttrs cfg.mattermost.enable {
      "matterhorn/config.ini".source =
        config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/matterhorn-config.ini";

      # Matterhorn is not a stylix target, so mirror the palette by hand. Hex
      # values are clamped to the nearest 256-color entry by matterhorn.
      "matterhorn/theme.ini".text = ''
        [default]
        default.fg = ${c.base05}
        default.bg = default

        [other]
        time.fg = ${c.base03}
        dateTransition.fg = ${c.base03}
        newMessageTransition.fg = ${c.base09}
        newMessageTransition.style = bold
        gapMessage.fg = ${c.base03}
        loadMoreMessages.fg = ${c.base0C}
        verbatimTruncateMessage.fg = ${c.base03}

        channelHeader.fg = ${c.base04}
        channelListSectionHeader.fg = ${c.base04}
        currentChannelName.fg = ${c.base0C}
        currentChannelName.style = bold
        channelName.fg = ${c.base0C}
        unreadChannel.fg = ${c.base05}
        unreadChannel.style = bold
        unreadChannelGroupMarker.fg = ${c.base09}
        channelWithMentions.fg = ${c.base08}
        channelWithMentions.style = bold
        recentChannelMarker.fg = ${c.base09}
        currentTeam.fg = ${c.base0C}
        currentTeam.style = bold

        tabSelected.fg = ${c.base0C}
        tabSelected.style = bold
        tabUnselected.fg = ${c.base03}

        markdownHeader.fg = ${c.base0E}
        markdownHeader.style = bold
        markdownEmph.style = italic
        markdownStrong.style = bold
        markdownStrikethrough.fg = ${c.base03}
        markdownStrikethrough.style = strikethrough
        codeBlock.fg = ${c.base0B}
        email.fg = ${c.base0D}
        email.style = underline
        permalink.fg = ${c.base0D}
        permalink.style = underline
        reaction.fg = ${c.base0C}
        clientMessage.fg = ${c.base04}
        currentUser.fg = ${c.base0E}
        currentUser.style = bold
        replyParentPreview.fg = ${c.base03}
        pinnedMessageIndicator.fg = ${c.base09}
        editedMarking.fg = ${c.base03}
        editedRecentlyMarking.fg = ${c.base09}

        errorMessage.fg = ${c.base08}
        errorMessage.style = bold
        misspelling.fg = ${c.base08}
        misspelling.style = underline

        messageSelectCursor.bg = ${c.base02}
        messageSelectCursor.fg = ${c.base05}
        urlListCursor.bg = ${c.base02}
        urlListCursor.fg = ${c.base05}
        messageSelectStatus.fg = ${c.base0C}
        messageSelectStatus.style = bold
        urlSelectStatus.fg = ${c.base0C}
        urlSelectStatus.style = bold

        channelSelectPrompt.fg = ${c.base0C}
        channelSelectMatch.fg = ${c.base0C}
        channelSelectMatch.style = bold
        tabCompletionAlternative.fg = ${c.base04}
        tabCompletionCursor.fg = ${c.base0C}
        tabCompletionCursor.style = bold
        focusedEditorPrompt.fg = ${c.base0C}
        focusedEditorPrompt.style = bold

        dialog.fg = ${c.base05}
        dialog.bg = ${c.base01}
        dialogEmphasis.fg = ${c.base0C}
        dialogEmphasis.style = bold
        button.fg = ${c.base05}
        button.bg = ${c.base02}

        helpEmphasis.fg = ${c.base0C}
        helpEmphasis.style = bold
        helpKeyEvent.fg = ${c.base09}
      '';
    };
}
