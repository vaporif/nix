require('lze').load {
  {
    'nvim-treesitter',
    event = 'BufReadPre',
    after = function()
      require('nvim-treesitter.configs').setup {
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer' },
            goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer' },
            goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer' },
            goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer' },
          },
        },
      }
    end,
  },
}

require('lze').load {
  {
    'nvim-treesitter-context',
    event = 'BufReadPre',
    after = function()
      require('treesitter-context').setup {}
    end,
  },
}
