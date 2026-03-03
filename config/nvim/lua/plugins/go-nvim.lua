require('lze').load {
  {
    'go.nvim',
    ft = { 'go', 'gomod' },
    after = function()
      require('go').setup {}
    end,
  },
}
