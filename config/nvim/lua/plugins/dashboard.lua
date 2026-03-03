require('lze').load {
  {
    'alpha-nvim',
    event = 'VimEnter',
    after = function()
      local logo = [[
░░░░░░░░▀▀▀██████▄▄▄░░░░░░░░░░░░
░░░░░░▄▄▄▄▄░░█████████▄░░░░░░░░░
░░░░░▀▀▀▀█████▌░▀▐▄░▀▐█░░░░░░░░░
░░░▀▀█████▄▄░▀██████▄██░░░░░░░░░
░░░▀▄▄▄▄▄░░▀▀█▄▀█════█▀░░░░░░░░░
░░░░░░░░▀▀▀▄░░▀▀███░▀░░░░░░▄▄░░░
░░░░░▄███▀▀██▄████████▄░▄▀▀▀██▌░
░░░██▀▄▄▄██▀▄███▀░▀▀████░░░░░▀█▄
▄▀▀▀▄██▄▀▀▌████▒▒▒▒▒▒███░░░░▌▄▄▀
▌░░░░▐▀████▐███▒▒▒▒▒▐██▌░░░░░░░░
▀▄░░▄▀░░░▀▀████▒▒▒▒▄██▀░░░░░░░░░
░░▀▀░░░░░░▀▀█████████▀░░░░░░░░░░
]]
      local startify = require 'alpha.themes.startify'
      startify.section.header.val = vim.split(logo, '\n')
      startify.section.header.opts = { position = 'center', hl = 'Comment' }
      startify.section.mru.opts = { position = 'center', spacing = 1 }
      startify.section.mru_cwd.opts = { position = 'center', spacing = 1 }
      startify.config.layout = {
        { type = 'padding', val = 2 },
        startify.section.header,
        { type = 'padding', val = 2 },
        startify.section.mru_cwd,
        { type = 'padding', val = 1 },
        startify.section.mru,
        { type = 'padding', val = 1 },
      }
      startify.config.opts = { margin = 44 }
      startify.file_icons.provider = 'devicons'
      require('alpha').setup(startify.config)
    end,
  },
}
