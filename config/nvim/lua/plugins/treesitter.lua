require('lze').load {
  {
    'nvim-treesitter',
    event = 'BufReadPre',
    after = function()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
      pcall(vim.treesitter.start)

      local select = require 'nvim-treesitter-textobjects.select'
      local move = require 'nvim-treesitter-textobjects.move'

      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      local map = vim.keymap.set

      -- textobject selections
      map({ 'x', 'o' }, 'af', function()
        select.select_textobject('@function.outer', 'textobjects')
      end, { desc = 'outer function' })
      map({ 'x', 'o' }, 'if', function()
        select.select_textobject('@function.inner', 'textobjects')
      end, { desc = 'inner function' })
      map({ 'x', 'o' }, 'ac', function()
        select.select_textobject('@class.outer', 'textobjects')
      end, { desc = 'outer class' })
      map({ 'x', 'o' }, 'ic', function()
        select.select_textobject('@class.inner', 'textobjects')
      end, { desc = 'inner class' })
      map({ 'x', 'o' }, 'aa', function()
        select.select_textobject('@parameter.outer', 'textobjects')
      end, { desc = 'outer parameter' })
      map({ 'x', 'o' }, 'ia', function()
        select.select_textobject('@parameter.inner', 'textobjects')
      end, { desc = 'inner parameter' })

      -- move to next/prev
      map({ 'n', 'x', 'o' }, ']f', function()
        move.goto_next_start('@function.outer', 'textobjects')
      end, { desc = 'next function start' })
      map({ 'n', 'x', 'o' }, ']c', function()
        move.goto_next_start('@class.outer', 'textobjects')
      end, { desc = 'next class start' })
      map({ 'n', 'x', 'o' }, ']F', function()
        move.goto_next_end('@function.outer', 'textobjects')
      end, { desc = 'next function end' })
      map({ 'n', 'x', 'o' }, ']C', function()
        move.goto_next_end('@class.outer', 'textobjects')
      end, { desc = 'next class end' })
      map({ 'n', 'x', 'o' }, '[f', function()
        move.goto_previous_start('@function.outer', 'textobjects')
      end, { desc = 'prev function start' })
      map({ 'n', 'x', 'o' }, '[c', function()
        move.goto_previous_start('@class.outer', 'textobjects')
      end, { desc = 'prev class start' })
      map({ 'n', 'x', 'o' }, '[F', function()
        move.goto_previous_end('@function.outer', 'textobjects')
      end, { desc = 'prev function end' })
      map({ 'n', 'x', 'o' }, '[C', function()
        move.goto_previous_end('@class.outer', 'textobjects')
      end, { desc = 'prev class end' })
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
