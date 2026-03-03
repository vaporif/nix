require('lze').load {
  {
    'blink.pairs',
    event = 'DeferredUIEnter',
    after = function()
      require('blink.pairs').setup {
        mappings = {
          enabled = true,
          pairs = {},
          disabled_filetypes = {},
        },
        highlights = {
          enabled = true,
          groups = {
            'BlinkPairsWarm1',
            'BlinkPairsWarm2',
          },
        },
        debug = false,
      }
    end,
  },
}
