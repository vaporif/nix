require('yafg'):setup {
  editor = 'nvim',
}

require('augment-command'):setup {
  smart_enter = true,
  smart_paste = false,
  smart_tab_create = false,
  smart_tab_switch = false,
  skip_single_subdirectory_on_enter = true,
  skip_single_subdirectory_on_leave = true,
  wraparound_file_navigation = true,
}

local bookmarks = {}

local path_sep = package.config:sub(1, 1)
local home_path = os.getenv 'HOME'

require('yamb'):setup {
  -- Optional, the path ending with path separator represents folder.
  bookmarks = bookmarks,
  -- Optional, receive notification every time you jump.
  jump_notify = true,
  -- Optional, the cli of fzf.
  cli = 'fzf',
  -- Optional, a string used for randomly generating keys, where the preceding characters have higher priority.
  keys = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
  path = home_path .. '/.config/home-manager/yazi/bookmark',
}
