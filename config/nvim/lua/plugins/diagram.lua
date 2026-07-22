require('lze').load {
  {
    'diagram.nvim',
    ft = { 'markdown', 'markdown.mdx' },
    after = function()
      require('image').setup {
        backend = 'kitty',
        processor = 'magick_cli',
        integrations = {},
      }

      local config_dir = _G.nixInfo and _G.nixInfo.settings and _G.nixInfo.settings.config_directory or vim.fn.stdpath 'config'

      require('diagram').setup {
        integrations = { require 'diagram.integrations.markdown' },
        renderer_options = {
          mermaid = {
            theme = 'neutral',
            background = 'transparent',
            scale = 4,
            width = 1200,
            cli_args = { '-C', config_dir .. '/mermaid.css' },
          },
        },
      }
    end,
  },
}
