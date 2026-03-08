require('lze').load {
  {
    'nvim-treesitter',
    event = 'DeferredUIEnter',
    after = function()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then
          pcall(vim.treesitter.start, buf)
        end
      end

      local select = require 'nvim-treesitter-textobjects.select'
      local move = require 'nvim-treesitter-textobjects.move'

      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      -- textobject selections
      for _, m in ipairs {
        { 'af', '@function.outer', 'outer function' },
        { 'if', '@function.inner', 'inner function' },
        { 'ac', '@class.outer', 'outer class' },
        { 'ic', '@class.inner', 'inner class' },
        { 'aa', '@parameter.outer', 'outer parameter' },
        { 'ia', '@parameter.inner', 'inner parameter' },
      } do
        vim.keymap.set({ 'x', 'o' }, m[1], function()
          select.select_textobject(m[2], 'textobjects')
        end, { desc = m[3] })
      end

      -- move to next/prev
      for _, m in ipairs {
        { ']f', 'goto_next_start', '@function.outer', 'next function start' },
        { ']t', 'goto_next_start', '@class.outer', 'next class/type start' },
        { ']F', 'goto_next_end', '@function.outer', 'next function end' },
        { ']T', 'goto_next_end', '@class.outer', 'next class/type end' },
        { '[f', 'goto_previous_start', '@function.outer', 'prev function start' },
        { '[t', 'goto_previous_start', '@class.outer', 'prev class/type start' },
        { '[F', 'goto_previous_end', '@function.outer', 'prev function end' },
        { '[T', 'goto_previous_end', '@class.outer', 'prev class/type end' },
      } do
        vim.keymap.set({ 'n', 'x', 'o' }, m[1], function()
          move[m[2]](m[3], 'textobjects')
        end, { desc = m[4] })
      end
    end,
  },
  {
    'nvim-treesitter-context',
    event = 'DeferredUIEnter',
    after = function()
      require('treesitter-context').setup {}
    end,
  },
}
