-- rustaceanvim is loaded eagerly by Nix
local settings = _G.nixInfo and _G.nixInfo.settings or {}
local cmd = settings.rustAnalyzerCmd or {}

vim.g.rustaceanvim = {
  server = {
    -- Points at the lspmux client when Nix wired one up, so several neovim
    -- windows on the same project attach to one rust-analyzer instead of each
    -- starting its own. Empty falls back to rustaceanvim's own discovery.
    cmd = #cmd > 0 and cmd or nil,
    default_settings = {
      ['rust-analyzer'] = settings.rustAnalyzerSettings or {
        files = {
          excludeDirs = { '.direnv' },
        },
      },
    },
  },
}
