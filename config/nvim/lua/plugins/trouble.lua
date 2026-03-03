require('lze').load {
  {
    'trouble.nvim',
    on_require = 'trouble',
    cmd = 'Trouble',
    keys = {
      { '<leader>bt', '<cmd>Trouble todo toggle<cr>', desc = '[t]odo' },
      { '<leader>bd', '<cmd>Trouble diagnostics toggle<cr>', desc = '[d]iagnostics' },
      { '<leader>bb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = '[b]uffer' },
      { '<leader>bs', '<cmd>Trouble symbols toggle focus=false<cr>', desc = '[s]ymbols' },
      { '<leader>bl', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', desc = '[L]SP Definitions / references / ...' },
      { '<leader>bo', '<cmd>Trouble loclist toggle<cr>', desc = 'l[o]ocation' },
      { '<leader>bq', '<cmd>Trouble qflist toggle<cr>', desc = '[q]uickfix' },
      {
        ']x',
        function()
          require('trouble').next { skip_groups = true, jump = true }
        end,
        desc = 'Next trouble item',
      },
      {
        '[x',
        function()
          require('trouble').prev { skip_groups = true, jump = true }
        end,
        desc = 'Previous trouble item',
      },
    },
    after = function()
      require('trouble').setup {}
    end,
  },
}
