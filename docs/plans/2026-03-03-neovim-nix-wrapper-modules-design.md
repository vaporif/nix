# Neovim nix-wrapper-modules Migration Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Neovim plugin management from lazy.nvim to nix-wrapper-modules for fully reproducible, Nix-pinned plugins while keeping all Lua configuration.

**Architecture:** Replace `programs.neovim` + lazy.nvim fetching with `wrappers.neovim` from nix-wrapper-modules. Plugins become Nix derivations installed via packadd. Lazy loading uses `lze` (lightweight loader by same author) instead of lazy.nvim. Existing Lua config in `config/nvim/` is preserved — only bootstrap and plugin spec format change.

**Tech Stack:** nix-wrapper-modules, lze, nixpkgs vimPlugins, home-manager

---

## Motivation

- **Reproducibility**: Plugins pinned in flake.lock, not lazy-lock.json
- **Build hermiticity**: Native components (blink.cmp Rust binary, treesitter parsers) compiled by Nix
- **No runtime fetching**: All plugins available at build time, no network needed at startup
- **Single source of truth**: flake.lock pins everything (system, tools, editor plugins)

## Flake Input

```nix
inputs.wrappers = {
  url = "github:BirdeeHub/nix-wrapper-modules";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Passed through `mkHostContext` to modules.

## Home-Manager Integration

Replace `programs.neovim` in `home/common/default.nix` with:

```nix
imports = [
  (inputs.wrappers.lib.mkInstallModule {
    loc = ["home" "packages"];
    name = "neovim";
    value = inputs.wrappers.lib.wrapperModules.neovim;
  })
];

wrappers.neovim = { pkgs, lib, ... }: {
  enable = true;
  settings.config_directory = ../../config/nvim;
  settings.info_plugin_name = "nix-info";
  config.info.configPath = userConfig.configPath;
  config.specs = { /* plugin specs */ };
};
```

Remove:
- `programs.neovim` block
- `xdg.configFile."nvim"` symlink (wrapper handles config directory)
- `xdg.configFile."nvim/lua/nix-paths.lua"` (replaced by nix-info plugin)

## Plugin Spec Mapping

All plugins grouped into logical specs. Each uses `pkgs.vimPlugins.*` derivations.

### Eager (startup)

| Spec Name | Plugins | Notes |
|-----------|---------|-------|
| `colorscheme` | earthtone-nvim | `before = ["INIT_MAIN"]`, `lazy = false` |
| `lze` | lze | `before = ["INIT_MAIN"]`, `lazy = false` |
| `snacks` | snacks-nvim | `lazy = false` |

### Lazy Groups

| Spec Name | Plugins | Trigger Pattern |
|-----------|---------|----------------|
| `completion` | blink-cmp, blink-pairs, lazydev-nvim | event/ft |
| `treesitter` | nvim-treesitter.withAllGrammars, textobjects, context | event |
| `lsp` | nvim-lspconfig, conform-nvim | event |
| `navigation` | fzf-lua, neo-tree-nvim, flash-nvim, harpoon2 | keys/cmd |
| `git` | gitsigns-nvim, diffview-nvim | event/cmd |
| `ui` | lualine-nvim, which-key-nvim, noice-nvim, dashboard-nvim | event |
| `debug` | nvim-dap, nvim-dap-ui, nvim-dap-go, mason-nvim-dap | keys |
| `testing` | neotest + adapters (go, python, jest, foundry, rust) | keys/cmd |
| `rust` | rustaceanvim | ft |
| `utilities` | marks, todo-comments, early-retirement, crates, baleia, yanky, outline, grug-far, nvim-ufo, trouble, guess-indent, auto-session, markdown | mixed |
| `tidal` | vim-tidal-lua | ft=tidal |

### Plugins Not in nixpkgs

These need flake inputs with `flake = false`:

```nix
inputs.plugin-earthtone = { url = "github:vaporif/earthtone.nvim"; flake = false; };
inputs.plugin-vim-tidal-lua = { url = "github:vaporif/vim-tidal-lua"; flake = false; };
```

Built via `config.nvim-lib.mkPlugin`.

### Runtime Dependencies (extraPackages)

Bundled into the wrapper's PATH:

```nix
extraPackages = with pkgs; [
  # LSP servers
  lua-language-server typescript-language-server basedpyright nixd
  just-lsp haskell-language-server
  # Formatters/linters
  stylua golangci-lint
  # Tools
  lua51Packages.luarocks lua51Packages.lua
];
```

## nix-paths.lua → nix-info

**Current:** HM generates `nix-paths.lua` returning configPath string.

**New:** Built-in nix-info plugin:

```nix
# Nix side
config.info.configPath = userConfig.configPath;
```

```lua
-- Lua side
local nixInfo = require("nix-info")
local configPath = nixInfo("", "info", "configPath")
```

Non-Nix fallback pattern for portability:

```lua
do
  local ok
  ok, _G.nixInfo = pcall(require, vim.g.nix_info_plugin_name)
  if not ok then
    package.loaded[vim.g.nix_info_plugin_name or "nix-info"] = setmetatable({}, {
      __call = function(_, default) return default end
    })
    _G.nixInfo = require(vim.g.nix_info_plugin_name or "nix-info")
  end
end
```

## Treesitter Parsers

Fully Nix-managed via `collateGrammars = true` (default):

```nix
config.specs.treesitter = {
  lazy = true;
  collateGrammars = true;
  data = with pkgs.vimPlugins; [
    nvim-treesitter.withAllGrammars
    nvim-treesitter-textobjects
    nvim-treesitter-context
  ];
};
```

Remove any `ensure_installed` or `:TSInstall` from Lua config.

## init.lua Changes

Remove lazy.nvim bootstrap (~20 lines). Replace with:

```lua
-- nix-info setup with non-Nix fallback
do
  local ok
  ok, _G.nixInfo = pcall(require, vim.g.nix_info_plugin_name)
  if not ok then
    package.loaded[vim.g.nix_info_plugin_name or "nix-info"] = setmetatable({}, {
      __call = function(_, default) return default end
    })
    _G.nixInfo = require(vim.g.nix_info_plugin_name or "nix-info")
  end
end

require("core")
-- Plugin configs loaded from lua/plugins/*.lua
-- Each file calls require("lze").load { ... }
```

## Plugin Lua Config Changes

Each `lua/plugins/*.lua` file changes from lazy.nvim spec to lze spec:

```lua
-- Before (lazy.nvim):
return {
  "lewis6991/gitsigns.nvim",
  event = "BufReadPre",
  opts = { current_line_blame = true },
}

-- After (lze):
require("lze").load {
  { "gitsigns.nvim", event = "BufReadPre",
    after = function()
      require("gitsigns").setup({ current_line_blame = true })
    end,
  },
}
```

Key differences:
- No `opts` sugar — use explicit `after = function() ... setup({}) end`
- Plugin name is pname (derivation name), not `user/repo`
- `config` key becomes `after` callback
- `init` key becomes `before` callback
- `dependencies` handled by Nix specs, not Lua

## Mason Removal

Remove mason.nvim entirely. All tools managed by Nix `extraPackages`. Remove:
- `mason.nvim` plugin
- `mason-nvim-dap.nvim` (configure DAP adapters directly)
- Any `ensure_installed` in mason config

## What Changes vs. What Stays

| Component | Changes? | Details |
|-----------|----------|---------|
| `flake.nix` | Yes | Add wrappers input, plugin inputs, pass to modules |
| `home/common/default.nix` | Yes | Replace programs.neovim with wrappers.neovim |
| `config/nvim/init.lua` | Yes | Remove lazy bootstrap, add nix-info setup |
| `config/nvim/lua/plugins/*.lua` | Yes | lazy.nvim spec → lze spec format |
| `config/nvim/lazy-lock.json` | Delete | No longer needed |
| `config/nvim/lua/core/options.lua` | No | Unchanged |
| `config/nvim/lua/core/keymaps.lua` | No | Unchanged |
| `config/nvim/lua/core/autocmds.lua` | No | Unchanged |
| `config/nvim/lua/core/lsp.lua` | Minor | Remove ensure_installed references |

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Plugin not in nixpkgs | Add as flake input, build with mkPlugin |
| lze missing lazy.nvim feature | lze covers event/ft/cmd/keys/colorscheme/on_require — sufficient |
| nixpkgs plugin version lag | Override with newer flake input |
| Config breaks during migration | Keep lazy.nvim branch, migrate incrementally per plugin group |
| Mason-managed tools missing | All tools explicitly listed in extraPackages |
