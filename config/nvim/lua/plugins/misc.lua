require('lze').load {
  { 'nvim-lspconfig', event = 'BufReadPre' },
}

require('lze').load {
  {
    'guess-indent.nvim',
    event = 'BufReadPre',
    after = function()
      require('guess-indent').setup {}
    end,
  },
}

-- auto-session: loaded eagerly by Nix, just call setup
require('auto-session').setup {
  suppressed_dirs = { '~/', '~/Repos', '~/Downloads', '/' },
}

require('lze').load {
  {
    'noice.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('noice').setup {
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = false,
        },
      }
    end,
  },
}

require('lze').load {
  {
    'marks.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('marks').setup {}
    end,
  },
}

require('lze').load {
  {
    'todo-comments.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('todo-comments').setup { signs = false }
    end,
  },
}

require('lze').load {
  {
    'nvim-early-retirement',
    event = 'DeferredUIEnter',
    after = function()
      require('early-retirement').setup {}
    end,
  },
}

require('lze').load {
  {
    'diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
  },
}

require('lze').load {
  {
    'crates.nvim',
    ft = 'toml',
    after = function()
      require('crates').setup {}
    end,
  },
}

require('lze').load {
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
}

require('lze').load {
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
}

require('lze').load {
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
}
