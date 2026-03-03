require('lze').load {
  {
    'yanky.nvim',
    event = 'DeferredUIEnter',
    keys = {
      { 'P', '<Plug>(YankyPutBefore)', mode = { 'n', 'x' }, desc = 'Put before' },
      { 'gp', '<Plug>(YankyGPutAfter)', mode = { 'n', 'x' }, desc = 'GPut after' },
      { 'gP', '<Plug>(YankyGPutBefore)', mode = { 'n', 'x' }, desc = 'GPut before' },
      { '<c-p>', '<Plug>(YankyPreviousEntry)', desc = 'Yanky previous' },
      { '<c-n>', '<Plug>(YankyNextEntry)', desc = 'Yanky next' },
    },
    after = function()
      require('yanky').setup {
        preserve_cursor_position = { enabled = true },
      }
    end,
  },
}

require('lze').load {
  {
    'substitute.nvim',
    keys = {
      {
        's',
        function()
          require('substitute').operator()
        end,
        desc = 'Substitute',
      },
      {
        'ss',
        function()
          require('substitute').line()
        end,
        desc = 'Substitute line',
      },
      {
        'S',
        function()
          require('substitute').eol()
        end,
        desc = 'Substitute to EOL',
      },
      {
        's',
        function()
          require('substitute').visual()
        end,
        mode = 'x',
        desc = 'Substitute',
      },
    },
    after = function()
      require('substitute').setup {
        on_substitute = function(event)
          require('yanky.integration').substitute()(event)
        end,
        highlight_substituted_text = { enabled = true, timer = 300 },
      }
    end,
  },
}
