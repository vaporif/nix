require('lze').load {
  {
    'difftastic.nvim',
    cmd = { 'Difft', 'DifftPick' },
    after = function()
      require('difftastic-nvim').setup {
        download = false,
        vcs = 'git',
        snacks_picker = { enabled = true },
      }
    end,
  },
}
