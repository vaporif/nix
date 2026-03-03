require('lze').load {
  {
    'mini.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.cursorword').setup()
      require('mini.trailspace').setup()
      require('mini.indentscope').setup {
        symbol = '│',
        options = {
          try_as_border = true,
          indent_at_cursor = true,
        },
        draw = {
          delay = 0,
          animation = require('mini.indentscope').gen_animation.none(),
        },
      }
      vim.api.nvim_create_autocmd({ 'FileType', 'TermOpen', 'BufEnter' }, {
        pattern = '*',
        callback = function()
          if vim.bo.buftype == 'terminal' or vim.bo.filetype == 'fzf' or vim.fn.bufname():match 'fzf' then
            vim.b.miniindentscope_disable = true
          end
        end,
      })
    end,
  },
}
