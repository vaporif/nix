{
  config,
  lib,
  pkgs,
  sandboxShared,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  toml = pkgs.formats.toml {};

  # base16 has no tinted backgrounds, so diff add/del rows blend the accent
  # into base00 the way GitHub-style diffs do.
  mix = ratio: fg: bg: let
    channel = hex: i: lib.fromHexString (builtins.substring (1 + i * 2) 2 hex);
    blend = i: let
      v = builtins.floor (ratio * channel fg i + (1 - ratio) * channel bg i + 0.5);
      h = lib.toLower (lib.toHexString v);
    in
      lib.optionalString (v < 16) "0" + h;
  in "#${blend 0}${blend 1}${blend 2}";
  tint = color: mix 0.18 color c.base00;

  theme = {
    panel_bg = c.base00;
    bg_highlight = c.base02;
    fg_primary = c.base05;
    fg_secondary = c.base04;
    fg_dim = c.base03;

    diff_add = c.base0B;
    diff_add_bg = tint c.base0B;
    diff_del = c.base08;
    diff_del_bg = tint c.base08;
    diff_context = c.base05;
    diff_hunk_header = c.base0D;
    expanded_context_fg = c.base03;
    syntax_add_bg = tint c.base0B;
    syntax_del_bg = tint c.base08;

    file_added = c.base0B;
    file_modified = c.base0A;
    file_deleted = c.base08;
    file_renamed = c.base0E;

    reviewed = c.base0B;
    pending = c.base0A;

    comment_note = c.base0D;
    comment_suggestion = c.base0C;
    comment_issue = c.base08;
    comment_praise = c.base0B;

    border_focused = c.base0D;
    border_unfocused = c.base02;
    status_bar_bg = c.base01;
    cursor_color = c.base0A;
    cursor_line_bg = c.base01;
    branch_name = c.base0E;
    help_indicator = c.base04;

    message_info_fg = c.base00;
    message_info_bg = c.base0D;
    message_warning_fg = c.base00;
    message_warning_bg = c.base0A;
    message_error_fg = c.base00;
    message_error_bg = c.base08;
    update_badge_fg = c.base00;
    update_badge_bg = c.base0A;

    mode_fg = c.base00;
    mode_bg = c.base0D;
  };
in {
  # Keys are patched to match codediff.nvim/review.nvim, see overlays/packages.nix.
  home.packages = [pkgs.tuicr sandboxShared.tuicrPane];

  xdg.configFile = {
    "tuicr/config.toml".source = toml.generate "tuicr-config.toml" {
      theme = "stylix";
      leader = " ";
      editor = "nvim";
      comment_vim = true;
      q_quits = true;
      diff_view = "side-by-side";
    };
    "tuicr/themes/stylix.toml".source = toml.generate "tuicr-stylix.toml" theme;
  };

  # Taken from the package source so the skill always matches the installed
  # CLI. Inside claude-sandboxed there is no $TMUX, so the tmux row points at
  # tuicr-pane (scripts/tuicr-pane.sh) instead of the upstream wrapper.
  custom.llm.skills.tuicr = {
    source = pkgs.runCommand "tuicr-skill" {} ''
      cp -r ${pkgs.tuicr.src}/skills/tuicr $out
      chmod -R u+w $out
      substituteInPlace $out/SKILL.md --replace-fail \
        '| `$TMUX` is set | Run `tuicr-wrapper.sh /path/to/repo -- <scope>` |' \
        '| `$TMUX` or `$TUICR_BROKER` is set | Run `tuicr-pane <scope>` from the repo directory. It works inside the sandbox, blocks until the user quits tuicr, then prints `closed` |'
    '';
    kind = "directory";
  };
}
