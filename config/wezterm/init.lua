local wezterm = require 'wezterm'
local act = wezterm.action

local function toggle_split(split_dir, size, focus_dir, hide_dir)
  return wezterm.action_callback(function(window, pane)
    local panes = window:active_tab():panes_with_info()
    if #panes == 1 then
      pane:split { direction = split_dir, size = size }
    elseif #panes == 2 then
      for _, p in ipairs(panes) do
        if p.is_zoomed then
          window:perform_action(act.TogglePaneZoomState, pane)
          window:perform_action(act.ActivatePaneDirection(focus_dir), pane)
          return
        end
      end
      window:perform_action(act.ActivatePaneDirection(hide_dir), pane)
      window:perform_action(act.TogglePaneZoomState, pane)
    end
  end)
end

-- Event handlers (side effects, not config values)
local mux = wezterm.mux
wezterm.on('gui-startup', function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

local agent_deck = dofile '@agentDeckPath@'

local config = {
  term = 'wezterm',
  color_scheme = 'earthtone-light',
  line_height = 1.0,
  front_end = wezterm.target_triple:find 'linux' and 'OpenGL' or 'WebGpu',
  freetype_load_flags = 'NO_HINTING',
  freetype_load_target = 'Light',
  max_fps = 120,
  animation_fps = 120,

  -- Window configuration
  window_padding = {
    left = 15,
    right = 15,
    top = 10,
    bottom = 5,
  },
  window_decorations = 'RESIZE',
  native_macos_fullscreen_mode = true,

  -- Tab bar configuration
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  hide_tab_bar_if_only_one_tab = true,
  tab_max_width = 32,
  cursor_blink_rate = 0,

  -- Scrollback
  scrollback_lines = 50000,

  -- Disable dead keys
  use_dead_keys = false,

  leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 },

  keys = {
    -- Pane management
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = false } },

    -- Split panes
    { key = 'v', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'h', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },

    -- Navigate panes
    { key = 'n', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    { key = 'i', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
    { key = 'u', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    { key = 'e', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },

    -- Toggle fullscreen for pane
    { key = 'f', mods = 'LEADER', action = act.TogglePaneZoomState },

    -- Rename tab
    {
      key = ',',
      mods = 'LEADER',
      action = act.PromptInputLine {
        description = 'Enter new name for tab',
        action = wezterm.action_callback(function(window, _, line)
          if line then
            window:active_tab():set_title(line)
          end
        end),
      },
    },

    -- Search mode
    { key = '/', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },

    -- Scroll mode
    { key = 'c', mods = 'LEADER', action = act.ActivateCopyMode },

    -- Resize panes
    {
      key = 'r',
      mods = 'LEADER',
      action = act.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
      },
    },

    -- Move panes
    {
      key = 'm',
      mods = 'LEADER',
      action = act.ActivateKeyTable {
        name = 'move_tab',
        one_shot = false,
      },
    },

    -- Session management
    { key = 'o', mods = 'LEADER', action = act.ShowLauncher },

    -- Quick session switcher
    { key = 'z', mods = 'LEADER', action = act.ShowLauncherArgs {
      flags = 'FUZZY|WORKSPACES',
    } },

    -- Pane cycling with Tab
    { key = 'Tab', mods = 'LEADER', action = act.ActivatePaneDirection 'Next' },

    -- Additional useful bindings
    { key = 'Enter', mods = 'ALT', action = act.ToggleFullScreen },
    { key = '+', mods = 'CMD', action = act.IncreaseFontSize },
    { key = '-', mods = 'CMD', action = act.DecreaseFontSize },
    { key = '0', mods = 'CMD', action = act.ResetFontSize },

    -- Copy/Paste
    { key = 'y', mods = 'CMD', action = act.CopyTo 'Clipboard' },
    { key = 'p', mods = 'CMD', action = act.PasteFrom 'Clipboard' },
    { key = 't', mods = 'CTRL', action = toggle_split('Bottom', 0.7, 'Down', 'Up') },
    { key = '/', mods = 'CTRL', action = toggle_split('Right', 0.5, 'Right', 'Left') },
  },

  -- Key tables for resize and move modes
  key_tables = {
    resize_pane = {
      { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 1 } },
      { key = 'n', action = act.AdjustPaneSize { 'Left', 1 } },

      { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 1 } },
      { key = 'i', action = act.AdjustPaneSize { 'Right', 1 } },

      { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 1 } },
      { key = 'u', action = act.AdjustPaneSize { 'Up', 1 } },

      { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 1 } },
      { key = 'e', action = act.AdjustPaneSize { 'Down', 1 } },

      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'Enter', action = 'PopKeyTable' },
    },

    move_tab = {
      { key = 'n', action = act.MoveTabRelative(-1) },
      { key = 'i', action = act.MoveTabRelative(1) },

      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'Enter', action = 'PopKeyTable' },
    },
  },

  -- Mouse bindings
  mouse_bindings = {
    -- Right click to paste
    {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = act.PasteFrom 'Clipboard',
    },

    -- Select text to copy to clipboard
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection 'ClipboardAndPrimarySelection',
    },
  },

  unix_domains = {
    {
      name = 'unix',
    },
  },

  launch_menu = {
    {
      label = 'Repos',
      cwd = wezterm.home_dir .. '/Repos',
    },
    {
      label = 'Nix Config',
      cwd = '@configPath@', -- substituted at build time by builtins.replaceStrings
    },
    {
      label = 'Home',
      cwd = wezterm.home_dir,
    },
  },
}

agent_deck.apply_to_config(config, {
  icons = {
    style = 'nerd',
    nerd = {
      working = wezterm.nerdfonts.cod_terminal,
      waiting = wezterm.nerdfonts.cod_bell,
      idle = wezterm.nerdfonts.cod_dash,
      inactive = wezterm.nerdfonts.cod_circle_outline,
    },
  },
  colors = {
    working = '#607530',
    waiting = '#a2362f',
    idle = '#2c7670',
    inactive = '#72817a',
  },
  right_status = { enabled = false },
  notifications = {
    enabled = true,
    on_waiting = true,
  },
})

wezterm.on('update-status', function(window, pane)
  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, p in ipairs(tab:panes()) do
      agent_deck.update_pane(p)
    end
  end

  local counts = agent_deck.count_agents_by_status()
  local cfg = agent_deck.get_config()
  local items = {}

  if counts.waiting > 0 then
    table.insert(items, { Foreground = { Color = cfg.colors.waiting } })
    table.insert(items, { Text = ' ' .. counts.waiting .. ' waiting ' })
  end
  if counts.working > 0 then
    table.insert(items, { Foreground = { Color = cfg.colors.working } })
    table.insert(items, { Text = ' ' .. counts.working .. ' working ' })
  end

  window:set_right_status(wezterm.format(items))
end)

-- Use Secretive's SSH agent if available
local secretive_sock = wezterm.home_dir .. '/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh'
if #wezterm.glob(secretive_sock) == 1 then
  config.default_ssh_auth_sock = secretive_sock
end

return config
