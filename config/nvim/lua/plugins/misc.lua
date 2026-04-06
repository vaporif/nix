require('lze').load {
  { 'nvim-lspconfig', event = 'BufReadPre' },
  {
    'guess-indent.nvim',
    event = 'BufReadPre',
    after = function()
      require('guess-indent').setup {}
    end,
  },
  {
    'noice.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('noice').setup {
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = true,
          lsp_doc_border = false,
        },
      }
    end,
  },
  {
    'marks.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('marks').setup {}
    end,
  },
  {
    'todo-comments.nvim',
    event = 'DeferredUIEnter',
    keys = {
      { '<leader>fT', '<cmd>TodoFzfLua<cr>', desc = '[T]odos' },
    },
    after = function()
      require('todo-comments').setup { signs = false }
    end,
  },
  {
    'nvim-early-retirement',
    event = 'DeferredUIEnter',
    after = function()
      require('early-retirement').setup {}
    end,
  },
  {
    'diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
  },
  {
    'crates.nvim',
    ft = 'toml',
    after = function()
      require('crates').setup {}
    end,
  },
  {
    'go-mod.nvim',
    ft = 'gomod',
    after = function()
      require('go-mod').setup {}
      vim.schedule(function()
        vim.cmd 'GoModCheck'
      end)
    end,
  },
  {
    'lazydev.nvim',
    ft = 'lua',
    after = function()
      require('lazydev').setup {
        library = {
          { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        },
      }
    end,
  },
  {
    'baleia.nvim',
    keys = {
      { '<leader>cA', desc = '[A]nsi colorize' },
    },
    after = function()
      local baleia = require('baleia').setup {}
      vim.api.nvim_create_user_command('BaleiaColorize', function()
        baleia.once(vim.api.nvim_get_current_buf())
      end, {})
      vim.keymap.set('n', '<leader>cA', '<cmd>BaleiaColorize<cr>', { desc = '[A]nsi colorize' })
    end,
  },
  {
    'vim-tidal-lua',
    ft = 'tidal',
    after = function()
      require('vim-tidal-lua').setup {
        ghci = 'ghci',
        boot = vim.fn.expand '~/.config/tidal/Tidal.ghci',
        sc_enable = false,
      }
    end,
  },
  {
    'inc-rename.nvim',
    cmd = 'IncRename',
    after = function()
      require('inc_rename').setup()
    end,
  },
  {
    'auto-session',
    -- loaded eagerly by Nix, just call setup
    after = function()
      local home = vim.env.HOME
      require('auto-session').setup {
        suppressed_dirs = { home, home .. '/Repos', home .. '/Downloads', '/' },
      }
    end,
  },
}
