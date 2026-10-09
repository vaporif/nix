local opt = vim.opt
local g = vim.g

-- Global options
g.mapleader = ' '
g.maplocalleader = ' '
g.have_nerd_font = true
g.no_cecutil_maps = 1

-- Editor UI options
opt.number = true
opt.relativenumber = true
opt.mouse = 'a'
opt.showmode = false
opt.signcolumn = 'yes'
opt.cursorline = true
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- UX options
opt.breakindent = true
opt.scrolloff = 15
opt.updatetime = 250
opt.timeoutlen = 300
opt.inccommand = 'split'

-- Split behavior
opt.splitright = true
opt.splitbelow = true

-- File handling options
opt.swapfile = false
opt.undofile = true
-- localoptions excluded: causes buffer-local keymaps to persist in sessions
opt.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal'

-- Search options
opt.ignorecase = true
opt.smartcase = true

vim.lsp.inlay_hint.enable(true)

-- Over ssh, copy via OSC 52 but never query the terminal on paste: tmux
-- ignores the query (get-clipboard off), and a late reply would land in the
-- shell after nvim exits. Paste falls back to the unnamed register.
if vim.env.SSH_TTY ~= nil then
  local osc52 = require 'vim.ui.clipboard.osc52'
  local function paste()
    return { vim.fn.getreg('"', 1, true), vim.fn.getregtype '"' }
  end
  g.clipboard = {
    name = 'OSC 52 (copy only)',
    copy = { ['+'] = osc52.copy '+', ['*'] = osc52.copy '*' },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end

-- Setup clipboard (deferred to avoid startup issues)
vim.schedule(function()
  opt.clipboard = 'unnamedplus'
end)
