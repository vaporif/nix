-- rustaceanvim is loaded eagerly by Nix
vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ['rust-analyzer'] = {
        files = {
          excludeDirs = { '.direnv' },
        },
      },
    },
  },
}
