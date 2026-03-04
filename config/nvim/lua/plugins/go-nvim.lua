require('lze').load {
  {
    'go.nvim',
    ft = { 'go', 'gomod', 'gowork', 'gotmpl' },
    after = function()
      require('go').setup {}
    end,
  },
}
