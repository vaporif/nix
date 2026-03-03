# Neovim nix-wrapper-modules Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Neovim from lazy.nvim plugin fetching to nix-wrapper-modules, making all plugins Nix-managed while preserving existing Lua configuration.

**Architecture:** Replace `programs.neovim` + lazy.nvim with `wrappers.neovim` from nix-wrapper-modules. Plugins become Nix derivations from nixpkgs `vimPlugins`. Lazy loading uses `lze` (Neovim-native packadd) instead of lazy.nvim. All Lua config files are rewritten from lazy.nvim spec format to lze format. The `nix-paths.lua` mechanism is replaced by nix-wrapper-modules' built-in `nix-info` plugin.

**Tech Stack:** nix-wrapper-modules, lze, nixpkgs vimPlugins, home-manager

---

## Reference: Plugin Inventory

All plugins exist in nixpkgs `vimPlugins.*` except:
- `earthtone-nvim` — already a flake input (`vaporif/earthtone.nvim`)
- `vim-tidal-lua` — user's custom plugin (`vaporif/vim-tidal-lua`), needs new flake input

Dependencies handled by Nix (no longer needed in Lua specs): `plenary.nvim`, `nvim-web-devicons`, `nui.nvim`, `nvim-nio`, `promise-async`, `guihua.lua`, `blink-download`.

Mason is removed entirely — all tools come from Nix `extraPackages`.

---

### Task 1: Add flake inputs

**Files:**
- Modify: `flake.nix:1-53` (inputs block)

**Step 1: Add wrappers input to flake.nix**

Add after the `parry` input (line 52):

```nix
wrappers = {
  url = "github:BirdeeHub/nix-wrapper-modules";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

**Step 2: Add vim-tidal-lua flake input**

Replace the existing `vim-tidal` input (line 32-35) with both:

```nix
vim-tidal = {
  url = "github:tidalcycles/vim-tidal/e440fe5bdfe07f805e21e6872099685d38e8b761";
  flake = false;
};
vim-tidal-lua = {
  url = "github:vaporif/vim-tidal-lua";
  flake = false;
};
```

**Step 3: Add new inputs to outputs function args**

In the `outputs` function (line 55-71), add `wrappers,` and `vim-tidal-lua,` to the destructured args.

**Step 4: Run nix flake lock to verify**

Run: `nix flake lock`
Expected: Lock file updated with new inputs, no errors.

**Step 5: Commit**

```bash
git add flake.nix flake.lock
git commit -m "add nix-wrapper-modules and vim-tidal-lua flake inputs"
```

---

### Task 2: Create the Nix wrapper module

**Files:**
- Create: `home/common/neovim.nix`

This file defines ALL plugin specs for nix-wrapper-modules. It replaces `programs.neovim` from `home/common/default.nix`.

**Step 1: Create `home/common/neovim.nix`**

```nix
{
  pkgs,
  lib,
  sharedLspPackages,
  earthtone-nvim,
  vim-tidal-lua,
  userConfig,
  wrappers,
  ...
}: let
  mkPlugin = name: src:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = "unstable";
      src = src;
    };
in {
  imports = [
    (wrappers.lib.mkInstallModule {
      loc = ["home" "packages"];
      name = "neovim";
      value = wrappers.lib.wrapperModules.neovim;
    })
  ];

  wrappers.neovim = {pkgs, ...}: {
    enable = true;

    settings = {
      config_directory = ../../config/nvim;
      info_plugin_name = "nix-info";
    };

    config = {
      info.configPath = userConfig.configPath;

      specs = {
        # ── Eager: loaded before init.lua ──────────────────────
        colorscheme = {
          data = mkPlugin "earthtone.nvim" earthtone-nvim;
          lazy = false;
          before = ["INIT_MAIN"];
        };

        lze = {
          data = pkgs.vimPlugins.lze;
          lazy = false;
          before = ["INIT_MAIN"];
        };

        # ── Eager: loaded at startup ──────────────────────────
        snacks = {
          data = pkgs.vimPlugins.snacks-nvim;
          lazy = false;
        };

        rustaceanvim = {
          data = pkgs.vimPlugins.rustaceanvim;
          lazy = false;
        };

        auto-session = {
          data = pkgs.vimPlugins.auto-session;
          lazy = false;
        };

        # ── Lazy: completion ──────────────────────────────────
        completion = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            blink-cmp
            blink-pairs
            lazydev-nvim
          ];
        };

        # ── Lazy: treesitter ──────────────────────────────────
        treesitter = {
          lazy = true;
          collateGrammars = true;
          data = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            nvim-treesitter-context
          ];
        };

        # ── Lazy: LSP & formatting ────────────────────────────
        lsp = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-lspconfig
            conform-nvim
          ];
        };

        # ── Lazy: navigation ──────────────────────────────────
        navigation = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            fzf-lua
            neo-tree-nvim
            flash-nvim
            harpoon2
            # Dependencies bundled by Nix
            nvim-web-devicons
            plenary-nvim
            nui-nvim
          ];
        };

        # ── Lazy: git ─────────────────────────────────────────
        git = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            gitsigns-nvim
            diffview-nvim
          ];
        };

        # ── Lazy: UI ──────────────────────────────────────────
        ui = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            lualine-nvim
            which-key-nvim
            noice-nvim
            alpha-nvim
            trouble-nvim
          ];
        };

        # ── Lazy: debug ──────────────────────────────────────
        debug = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            nvim-dap
            nvim-dap-ui
            nvim-dap-go
            nvim-nio
          ];
        };

        # ── Lazy: testing ─────────────────────────────────────
        testing = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            neotest
            neotest-golang
            neotest-python
            neotest-vitest
            neotest-foundry
          ];
        };

        # ── Lazy: language-specific ───────────────────────────
        go = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            go-nvim
            guihua-lua
          ];
        };

        tidal = {
          lazy = true;
          data = mkPlugin "vim-tidal-lua" vim-tidal-lua;
        };

        # ── Lazy: utilities ───────────────────────────────────
        utilities = {
          lazy = true;
          data = with pkgs.vimPlugins; [
            mini-nvim
            marks-nvim
            todo-comments-nvim
            nvim-early-retirement
            crates-nvim
            baleia-nvim
            yanky-nvim
            substitute-nvim
            outline-nvim
            grug-far-nvim
            nvim-ufo
            promise-async
            guess-indent-nvim
            render-markdown-nvim
          ];
        };

        # ── Tools (no plugin, just PATH) ─────────────────────
        tools = {
          data = null;
          extraPackages =
            sharedLspPackages
            ++ (with pkgs; [
              lua51Packages.luarocks
              lua51Packages.lua
              stylua
              haskell-language-server
              just-lsp
              golangci-lint
            ]);
        };
      };
    };
  };
}
```

**Step 2: Verify the file parses**

Run: `nix eval --parse ./home/common/neovim.nix`
Expected: No parse errors.

**Step 3: Commit**

```bash
git add home/common/neovim.nix
git commit -m "add nix-wrapper-modules neovim config"
```

---

### Task 3: Wire the module into flake.nix and home-manager

**Files:**
- Modify: `flake.nix:55-248` (outputs block)
- Modify: `home/common/default.nix:1-15,81-84,194-207,308-315`

**Step 1: Pass new inputs through mkHostContext and extraSpecialArgs**

In `flake.nix`, update the darwin `extraSpecialArgs` (around line 186) to add:
```nix
inherit wrappers vim-tidal-lua;
```

Do the same for the nixos `extraSpecialArgs` (around line 232):
```nix
inherit wrappers vim-tidal-lua;
```

**Step 2: Add neovim.nix to home-manager imports**

In `home/common/default.nix`, add to the imports list (line 81-84):

```nix
imports = [
  ./packages.nix
  ./shell.nix
  ./neovim.nix
];
```

Also add the new parameters to the function args (line 1-15):
```nix
{
  pkgs,
  config,
  user,
  homeDir,
  sharedLspPackages,
  yamb-yazi,
  mcpServersConfig,
  claude-code-plugins,
  superpowers,
  nix-devshells,
  earthtone-nvim,
  parry,
  userConfig,
  wrappers,
  vim-tidal-lua,
  ...
}:
```

**Step 3: Remove programs.neovim block**

In `home/common/default.nix`, remove lines 194-207:

```nix
    neovim = {
      viAlias = true;
      enable = true;
      extraPackages =
        sharedLspPackages
        ++ (with pkgs; [
          lua51Packages.luarocks
          lua51Packages.lua
          stylua
          haskell-language-server
          just-lsp
          golangci-lint
        ]);
    };
```

**Step 4: Remove xdg nvim entries**

In `home/common/default.nix`, remove lines 308-315 (the nvim xdg.configFile entries):

```nix
    # recursive = true so we can inject nix-paths.lua alongside the symlinked config files
    "nvim" = {
      source = ../../config/nvim;
      recursive = true;
    };
    # Generated Lua module returning configPath; required by init.lua for the lazy.nvim lockfile path
    "nvim/lua/nix-paths.lua".text = ''return "${userConfig.configPath}"'';
```

**Step 5: Update EDITOR session variable to use wrapper**

In `home/common/default.nix`, the `EDITOR = "nvim"` (line 102) stays as-is — the wrapper binary is still named `nvim`.

**Step 6: Verify nix flake check passes**

Run: `nix flake check`
Expected: No errors. This validates the module structure and type-checking.

**Step 7: Commit**

```bash
git add flake.nix home/common/default.nix home/common/neovim.nix
git commit -m "wire nix-wrapper-modules into home-manager, remove programs.neovim"
```

---

### Task 4: Rewrite init.lua for lze

**Files:**
- Modify: `config/nvim/init.lua` (complete rewrite)

**Step 1: Replace init.lua contents**

Replace the entire file with:

```lua
-- nix-info setup (values injected by nix-wrapper-modules)
-- Falls back gracefully when running outside Nix
do
  local ok, info = pcall(require, vim.g.nix_info_plugin_name)
  if ok then
    _G.nixInfo = info
  else
    local plugin_name = vim.g.nix_info_plugin_name or 'nix-info'
    package.loaded[plugin_name] = setmetatable({}, {
      __call = function(_, default)
        return default
      end,
    })
    _G.nixInfo = require(plugin_name)
  end
end

require 'core'

-- Load all plugin configs (each file calls require("lze").load)
-- Files are loaded alphabetically from lua/plugins/
local plugin_dir = vim.fn.stdpath 'config' .. '/lua/plugins'
local files = vim.fn.glob(plugin_dir .. '/*.lua', false, true)
table.sort(files)
for _, file in ipairs(files) do
  local module = file:match '.*/lua/(.*)%.lua$'
  if module then
    require(module:gsub('/', '.'))
  end
end
```

**Step 2: Delete lazy-lock.json**

Run: `rm -f config/nvim/lazy-lock.json`

**Step 3: Verify file is syntactically valid**

Run: `luac -p config/nvim/init.lua`
Expected: No errors.

**Step 4: Commit**

```bash
git add config/nvim/init.lua
git rm -f config/nvim/lazy-lock.json 2>/dev/null; true
git commit -m "rewrite init.lua for lze (remove lazy.nvim bootstrap)"
```

---

### Task 5: Rewrite plugin configs — eager plugins

**Files:**
- Modify: `config/nvim/lua/plugins/theme.lua`
- Modify: `config/nvim/lua/plugins/snacks.lua`
- Modify: `config/nvim/lua/plugins/rustaceanvim.lua`

**Step 1: Rewrite theme.lua**

The colorscheme is loaded before INIT_MAIN by Nix (via `before = ["INIT_MAIN"]`). Its config runs from the Nix DAG. But we still need to call setup from Lua. Since it loads before init.lua, we use a config string in Nix OR we call setup in init.lua.

Simpler approach: Since earthtone loads eagerly before INIT_MAIN, we set it up in a separate init file. But actually, the easiest approach is: let the Nix spec handle loading, and call setup from the plugin config file which init.lua will source.

Replace `theme.lua`:

```lua
-- earthtone.nvim is loaded eagerly by Nix (before INIT_MAIN)
-- Just call setup here
require('earthtone').setup { background = 'light' }
```

**Step 2: Rewrite snacks.lua**

Replace entire file:

```lua
-- snacks.nvim is loaded eagerly by Nix
require('snacks').setup {
  bigfile = { enabled = true },
  image = { enabled = false },
  input = {},
  notifier = { enabled = true },
  picker = {
    ui_select = true,
  },
}

vim.keymap.set('n', '<leader>g', function()
  require('snacks').lazygit()
end, { desc = 'Lazy[g]it' })

vim.keymap.set('n', '<leader>l', function()
  require('snacks').lazygit.log()
end, { desc = 'git [l]ogs' })
```

**Step 3: Rewrite rustaceanvim.lua**

Replace entire file:

```lua
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
```

**Step 4: Verify syntax**

Run: `for f in config/nvim/lua/plugins/theme.lua config/nvim/lua/plugins/snacks.lua config/nvim/lua/plugins/rustaceanvim.lua; do luac -p "$f" && echo "$f OK"; done`
Expected: All OK.

**Step 5: Commit**

```bash
git add config/nvim/lua/plugins/theme.lua config/nvim/lua/plugins/snacks.lua config/nvim/lua/plugins/rustaceanvim.lua
git commit -m "rewrite eager plugin configs for lze"
```

---

### Task 6: Rewrite plugin configs — misc.lua (split into individual files)

The `misc.lua` file contains many plugins. Each needs its own lze spec. Some are eager, some are lazy.

**Files:**
- Modify: `config/nvim/lua/plugins/misc.lua` (complete rewrite)

**Step 1: Rewrite misc.lua**

Replace entire file with lze specs:

```lua
-- nvim-lspconfig: loaded on BufReadPre
require('lze').load {
  { 'nvim-lspconfig', event = 'BufReadPre' },
}

-- guess-indent: loaded on BufReadPre
require('lze').load {
  {
    'guess-indent.nvim',
    event = 'BufReadPre',
    after = function()
      require('guess-indent').setup {}
    end,
  },
}

-- auto-session: loaded eagerly by Nix, just call setup
require('auto-session').setup {
  suppressed_dirs = { '~/', '~/Repos', '~/Downloads', '/' },
}

-- noice.nvim: loaded on VeryLazy (DeferredUIEnter in lze)
require('lze').load {
  {
    'noice.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('noice').setup {
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = false,
        },
      }
    end,
  },
}

-- marks.nvim
require('lze').load {
  {
    'marks.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('marks').setup {}
    end,
  },
}

-- todo-comments.nvim
require('lze').load {
  {
    'todo-comments.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('todo-comments').setup { signs = false }
    end,
  },
}

-- nvim-early-retirement
require('lze').load {
  {
    'nvim-early-retirement',
    event = 'DeferredUIEnter',
    after = function()
      require('early-retirement').setup {}
    end,
  },
}

-- diffview.nvim
require('lze').load {
  {
    'diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
  },
}

-- crates.nvim
require('lze').load {
  {
    'crates.nvim',
    ft = 'toml',
    after = function()
      require('crates').setup {}
    end,
  },
}

-- lazydev.nvim
require('lze').load {
  {
    'lazydev.nvim',
    ft = 'lua',
    after = function()
      require('lazydev').setup {
        library = {
          { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        },
      }
    end,
  },
}

-- baleia.nvim
require('lze').load {
  {
    'baleia.nvim',
    keys = {
      { '<leader>cA', desc = '[A]nsi colorize' },
    },
    after = function()
      local baleia = require('baleia').setup {}
      vim.api.nvim_create_user_command('BaleiaColorize', function()
        baleia.once(vim.api.nvim_get_current_buf())
      end, {})
      vim.keymap.set('n', '<leader>cA', '<cmd>BaleiaColorize<cr>', { desc = '[A]nsi colorize' })
    end,
  },
}

-- vim-tidal-lua
require('lze').load {
  {
    'vim-tidal-lua',
    ft = 'tidal',
    after = function()
      require('vim-tidal-lua').setup {
        ghci = 'ghci',
        boot = vim.fn.expand '~/.config/tidal/Tidal.ghci',
        sc_enable = false,
      }
    end,
  },
}
```

**Step 2: Verify syntax**

Run: `luac -p config/nvim/lua/plugins/misc.lua`
Expected: No errors.

**Step 3: Commit**

```bash
git add config/nvim/lua/plugins/misc.lua
git commit -m "rewrite misc.lua plugin configs for lze"
```

---

### Task 7: Rewrite plugin configs — completion

**Files:**
- Modify: `config/nvim/lua/plugins/blink-cmp.lua`
- Modify: `config/nvim/lua/plugins/blink-pairs.lua`

**Step 1: Rewrite blink-cmp.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'blink.cmp',
    event = 'DeferredUIEnter',
    after = function()
      require('blink.cmp').setup {
        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
          providers = {
            lsp = {
              name = 'lsp',
              module = 'blink.cmp.sources.lsp',
              fallbacks = { 'buffer' },
              score_offset = 90,
            },
            path = {
              name = 'Path',
              module = 'blink.cmp.sources.path',
              score_offset = 25,
              min_keyword_length = 3,
              fallbacks = { 'snippets', 'buffer' },
              opts = {
                trailing_slash = false,
                label_trailing_slash = true,
                get_cwd = function(context)
                  return vim.fn.expand(('#%d:p:h'):format(context.bufnr))
                end,
                show_hidden_files_by_default = true,
              },
            },
            buffer = {
              name = 'Buffer',
              max_items = 3,
              module = 'blink.cmp.sources.buffer',
              min_keyword_length = 2,
              score_offset = 50,
            },
            snippets = {
              name = 'snippets',
              max_items = 10,
              min_keyword_length = 2,
              module = 'blink.cmp.sources.snippets',
              score_offset = 70,
            },
            lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
          },
        },
        appearance = { nerd_font_variant = 'mono' },
        cmdline = { enabled = true },
        signature = { enabled = true },
        completion = {
          trigger = { show_on_trigger_character = true },
          list = {
            selection = { preselect = true, auto_insert = true },
          },
          menu = {
            draw = {
              padding = { 0, 1 },
              components = {
                kind_icon = {
                  text = function(ctx)
                    return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' '
                  end,
                },
              },
            },
          },
          documentation = { auto_show = true },
        },
        fuzzy = { implementation = 'rust' },
        keymap = {
          preset = 'enter',
          ['<Tab>'] = { 'snippet_forward', 'fallback' },
          ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
          ['<C-y>'] = { 'select_and_accept' },
          ['<Up>'] = { 'select_prev' },
          ['<Down>'] = { 'select_next' },
          ['<C-p>'] = { 'select_prev', 'fallback' },
          ['<C-n>'] = { 'select_next', 'fallback' },
          ['<S-j>'] = { 'scroll_documentation_up', 'fallback' },
          ['<S-k>'] = { 'scroll_documentation_down', 'fallback' },
          ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
          ['<C-e>'] = { 'hide', 'fallback' },
        },
      }
    end,
  },
}
```

**Step 2: Rewrite blink-pairs.lua**

Replace entire file:

```lua
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
```

**Step 3: Verify syntax**

Run: `for f in config/nvim/lua/plugins/blink-cmp.lua config/nvim/lua/plugins/blink-pairs.lua; do luac -p "$f" && echo "$f OK"; done`
Expected: All OK.

**Step 4: Commit**

```bash
git add config/nvim/lua/plugins/blink-cmp.lua config/nvim/lua/plugins/blink-pairs.lua
git commit -m "rewrite completion plugin configs for lze"
```

---

### Task 8: Rewrite plugin configs — treesitter

**Files:**
- Modify: `config/nvim/lua/plugins/treesitter.lua`

**Step 1: Rewrite treesitter.lua**

Replace entire file. Remove `ensure_installed`, `auto_install`, and `build` — Nix manages all parsers.

```lua
require('lze').load {
  {
    'nvim-treesitter',
    event = 'BufReadPre',
    after = function()
      require('nvim-treesitter.configs').setup {
        -- Parsers are managed by Nix (collateGrammars), no ensure_installed needed
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer' },
            goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer' },
            goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer' },
            goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer' },
          },
        },
      }
    end,
  },
}

require('lze').load {
  {
    'nvim-treesitter-context',
    event = 'BufReadPre',
    after = function()
      require('treesitter-context').setup {}
    end,
  },
}
```

**Step 2: Verify syntax**

Run: `luac -p config/nvim/lua/plugins/treesitter.lua`
Expected: No errors.

**Step 3: Commit**

```bash
git add config/nvim/lua/plugins/treesitter.lua
git commit -m "rewrite treesitter config for lze (Nix-managed parsers)"
```

---

### Task 9: Rewrite plugin configs — navigation

**Files:**
- Modify: `config/nvim/lua/plugins/fzf.lua`
- Modify: `config/nvim/lua/plugins/neo-tree.lua`
- Modify: `config/nvim/lua/plugins/flash.lua`
- Modify: `config/nvim/lua/plugins/harpoon.lua`

**Step 1: Rewrite fzf.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'fzf-lua',
    keys = {
      { '<leader>fh', '<cmd>FzfLua help_tags<cr>', desc = '[h]elp' },
      { '<leader>fk', '<cmd>FzfLua keymaps<cr>', desc = '[k]eymaps' },
      { '<leader>ff', '<cmd>FzfLua files<cr>', desc = '[f]iles' },
      { '<leader>fz', '<cmd>FzfLua builtin<cr>', desc = 'f[z]f' },
      { '<leader>fg', '<cmd>FzfLua live_grep<cr>', desc = '[g]rep' },
      { '<leader>fd', '<cmd>FzfLua diagnostics_document<cr>', desc = '[d]ocument diagnostics' },
      { '<leader>fr', '<cmd>FzfLua resume<cr>', desc = '[r]esume' },
      { "'", '<cmd>FzfLua marks<cr>', mode = { 'n', 'v' }, desc = 'Marks' },
      { '<leader>fb', '<cmd>FzfLua buffers<cr>', desc = '[b]uffers' },
      { '<leader>fc', '<cmd>FzfLua git_bcommits<cr>', desc = 'buffer [c]ommits' },
      { '<leader>fm', '<cmd>Noice fzf<cr>', desc = '[m]essages' },
      { 'gd', '<cmd>FzfLua lsp_definitions<cr>', desc = 'goto [d]efinition' },
      { 'gR', '<cmd>FzfLua lsp_references<cr>', desc = 'goto [R]eferences (fzf-lua)' },
      { 'gI', '<cmd>FzfLua lsp_implementations<cr>', desc = 'goto [I]mplementation' },
      { '<leader>fi', '<cmd>FzfLua lsp_typedefs<cr>', desc = 'type def[i]nition' },
      { '<leader>fs', '<cmd>FzfLua lsp_document_symbols<cr>', desc = 'document [s]ymbols' },
      { '<leader>fw', '<cmd>FzfLua lsp_live_workspace_symbols<cr>', desc = '[w]orkspace symbols' },
    },
    after = function()
      require('fzf-lua').setup {
        files = {
          cmd = 'fd --type f --hidden --follow --exclude .git || find . -type f',
        },
        winopts = {
          border = 'none',
          preview = { border = 'noborder' },
        },
        grep = {
          actions = { ['ctrl-g'] = false },
        },
      }

      vim.keymap.set('n', '<leader>.', function()
        require('fzf-lua').blines {
          previewer = false,
          winopts = { height = 0.40, width = 0.60, row = 0.40 },
        }
      end, { desc = 'buffer fuzz search' })

      vim.keymap.set('n', '<leader>fn', function()
        require('fzf-lua').files {
          prompt = 'Neovim Config> ',
          cwd = vim.fn.stdpath 'config',
        }
      end, { desc = '[n]eovim files' })

      vim.keymap.set('n', '<leader>ft', function()
        require('fzf-lua').git_worktrees {
          actions = {
            ['default'] = function(selected)
              local new_wt = selected[1]:match '^(%S+)'
              local old_wt = vim.fn.getcwd()
              local current_file = vim.fn.expand '%:p'
              local rel_path = current_file:gsub('^' .. vim.pesc(old_wt) .. '/', '')
              vim.cmd('cd ' .. new_wt)
              local new_file = new_wt .. '/' .. rel_path
              if vim.fn.filereadable(new_file) == 1 then
                vim.cmd('edit ' .. new_file)
              end
            end,
          },
        }
      end, { desc = 'work[t]rees' })
    end,
  },
}
```

**Step 2: Rewrite neo-tree.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'neo-tree.nvim',
    cmd = 'Neotree',
    after = function()
      require('neo-tree').setup {
        default_component_configs = {
          file_operations = { timeout = 0 },
        },
        filesystem = {
          commands = {
            delete = function(state)
              local inputs = require 'neo-tree.ui.inputs'
              local path = state.tree:get_node().path
              local msg = 'Are you sure you want to delete ' .. path .. '?'
              inputs.confirm(msg, function(confirmed)
                if confirmed then
                  vim.fn.jobstart({ 'rm', '-rf', path }, {
                    detach = true,
                    on_exit = function()
                      require('neo-tree.sources.manager').refresh 'filesystem'
                    end,
                  })
                end
              end)
            end,
          },
          filtered_items = { visible = true },
          follow_current_file = { enabled = true, leave_dirs_open = false },
          hijack_netrw_behavior = 'open_current',
          window = {
            popup = { border = 'none', title = '' },
            border = 'none',
            mappings = {
              ['e'] = 'none',
              ['h'] = function()
                vim.cmd 'Neotree float git_status'
              end,
              ['f'] = function()
                vim.cmd 'Neotree float filesystem'
              end,
              ['b'] = function()
                vim.cmd 'Neotree float buffers'
              end,
            },
          },
        },
      }
    end,
  },
}
```

**Step 3: Rewrite flash.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'flash.nvim',
    keys = {
      {
        'l',
        function()
          require('flash').jump()
        end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash',
      },
      {
        'k',
        function()
          require('flash').treesitter()
        end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash Treesitter',
      },
      {
        'r',
        function()
          require('flash').remote()
        end,
        mode = 'o',
        desc = 'Remote Flash',
      },
      {
        'R',
        function()
          require('flash').treesitter_search()
        end,
        mode = { 'o', 'x' },
        desc = 'Treesitter Search',
      },
      {
        '<c-s>',
        function()
          require('flash').toggle()
        end,
        mode = 'c',
        desc = 'Toggle Flash Search',
      },
    },
  },
}
```

**Step 4: Rewrite harpoon.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'harpoon2',
    keys = (function()
      local keys = {
        {
          '<leader>a',
          function()
            require('harpoon'):list():add()
          end,
          desc = 'harpoon [a]dd',
        },
        {
          '<leader>p',
          function()
            local h = require 'harpoon'
            h.ui:toggle_quick_menu(h:list())
          end,
          desc = 'har[p]oon',
        },
      }
      for i = 1, 9 do
        keys[#keys + 1] = {
          '<leader>' .. i,
          function()
            require('harpoon'):list():select(i)
          end,
          desc = 'which_key_ignore',
        }
      end
      keys[#keys + 1] = {
        '<leader>0',
        function()
          require('harpoon'):list():select(10)
        end,
        desc = 'which_key_ignore',
      }
      return keys
    end)(),
    after = function()
      require('harpoon'):setup()
    end,
  },
}
```

**Step 5: Verify syntax**

Run: `for f in config/nvim/lua/plugins/fzf.lua config/nvim/lua/plugins/neo-tree.lua config/nvim/lua/plugins/flash.lua config/nvim/lua/plugins/harpoon.lua; do luac -p "$f" && echo "$f OK"; done`
Expected: All OK.

**Step 6: Commit**

```bash
git add config/nvim/lua/plugins/fzf.lua config/nvim/lua/plugins/neo-tree.lua config/nvim/lua/plugins/flash.lua config/nvim/lua/plugins/harpoon.lua
git commit -m "rewrite navigation plugin configs for lze"
```

---

### Task 10: Rewrite plugin configs — git, UI, debug, testing

**Files:**
- Modify: `config/nvim/lua/plugins/gitsigns.lua`
- Modify: `config/nvim/lua/plugins/lualine.lua`
- Modify: `config/nvim/lua/plugins/which-key.lua`
- Modify: `config/nvim/lua/plugins/dashboard.lua`
- Modify: `config/nvim/lua/plugins/dap.lua`
- Modify: `config/nvim/lua/plugins/neotest.lua`
- Modify: `config/nvim/lua/plugins/trouble.lua`

**Step 1: Rewrite gitsigns.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'gitsigns.nvim',
    event = 'BufReadPre',
    after = function()
      require('gitsigns').setup {
        signs = {
          add = { text = '󰌪' },
          change = { text = '' },
          delete = { text = '󱋙' },
          topdelete = { text = '' },
          changedelete = { text = '󰬳' },
          untracked = { text = '󰹦' },
        },
        on_attach = function(bufnr)
          local gitsigns = require 'gitsigns'

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          map('n', ']g', function()
            if vim.wo.diff then
              vim.cmd.normal { ']c', bang = true }
            else
              gitsigns.nav_hunk 'next'
            end
          end, { desc = 'next [g]it hunk' })

          map('n', '[g', function()
            if vim.wo.diff then
              vim.cmd.normal { '[c', bang = true }
            else
              gitsigns.nav_hunk 'prev'
            end
          end, { desc = 'prev [g]it hunk' })
          map('v', '<leader>hs', function()
            gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = 'stage git hunk' })
          map('v', '<leader>hr', function()
            gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = 'reset git hunk' })
          map('n', '<leader>hs', gitsigns.stage_hunk, { desc = '[s]tage hunk' })
          map('n', '<leader>hr', gitsigns.reset_hunk, { desc = '[r]eset hunk' })
          map('n', '<leader>hS', gitsigns.stage_buffer, { desc = '[S]tage buffer' })
          map('n', '<leader>hR', gitsigns.reset_buffer, { desc = '[R]eset buffer' })
          map('n', '<leader>hp', gitsigns.preview_hunk, { desc = '[p]review hunk' })
          map('n', '<leader>hb', gitsigns.blame_line, { desc = '[b]lame line' })
          map('n', '<leader>hd', gitsigns.diffthis, { desc = '[d]iff against index' })
          map('n', '<leader>hD', function()
            gitsigns.diffthis '@'
          end, { desc = '[D]iff against last commit' })
          map('n', '<leader>hB', gitsigns.toggle_current_line_blame, { desc = 'toggle [B]lame' })
          map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'preview [i]nline' })
          map('n', '<leader>hh', function()
            gitsigns.setqflist 'all'
          end, { desc = 'file [h]istory' })
        end,
      }
    end,
  },
}
```

**Step 2: Rewrite lualine.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'lualine.nvim',
    event = 'DeferredUIEnter',
    after = function()
      local base_opts = {
        options = { theme = 'earthtone' },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = {
            { 'filename', path = 3 },
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      }

      local trouble = require 'trouble'
      local symbols = trouble.statusline {
        mode = 'lsp_document_symbols',
        groups = {},
        title = false,
        filter = { range = true },
        format = '{kind_icon}{symbol.name:Normal}',
        hl_group = 'lualine_c_normal',
      }

      table.insert(base_opts.sections.lualine_c, {
        symbols.get,
        cond = symbols.has,
      })

      require('lualine').setup(base_opts)
    end,
  },
}
```

**Step 3: Rewrite which-key.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'which-key.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('which-key').setup {
        icons = {
          mappings = false,
          keys = vim.g.have_nerd_font and {} or {
            Up = '<Up> ',
            Down = '<Down> ',
            Left = '<Left> ',
            Right = '<Right> ',
            C = '<C-…> ',
            M = '<M-…> ',
            D = '<D-…> ',
            S = '<S-…> ',
            CR = '<CR> ',
            Esc = '<Esc> ',
            ScrollWheelDown = '<ScrollWheelDown> ',
            ScrollWheelUp = '<ScrollWheelUp> ',
            NL = '<NL> ',
            BS = '<BS> ',
            Space = '<Space> ',
            Tab = '<Tab> ',
            F1 = '<F1>',
            F2 = '<F2>',
            F3 = '<F3>',
            F4 = '<F4>',
            F5 = '<F5>',
            F6 = '<F6>',
            F7 = '<F7>',
            F8 = '<F8>',
            F9 = '<F9>',
            F10 = '<F10>',
            F11 = '<F11>',
            F12 = '<F12>',
          },
        },
        spec = {
          { '<leader>s', group = '[s]plit' },
          { '<leader>f', group = '[f]ind' },
          { '<leader>q', group = '[q]uickreplace' },
          { '<leader>c', group = '[c]ode' },
          { '<leader>d', group = '[d]ebug' },
          { '<leader>b', group = 'trou[b]le' },
          { '<leader>t', group = '[t]est' },
          { '<leader>h', group = '[h]unk', mode = { 'n', 'v' } },
        },
      }
    end,
  },
}
```

**Step 4: Rewrite dashboard.lua**

Replace entire file:

```lua
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
```

**Step 5: Rewrite dap.lua (remove mason)**

Replace entire file:

```lua
require('lze').load {
  {
    'nvim-dap',
    keys = {
      {
        '<leader>dc',
        function()
          require('dap').continue()
        end,
        desc = 'start/[c]ontinue',
      },
      {
        '<leader>di',
        function()
          require('dap').step_into()
        end,
        desc = 'step [i]nto',
      },
      {
        '<leader>dr',
        function()
          require('dap').step_over()
        end,
        desc = 'step ove[r]',
      },
      {
        '<leader>do',
        function()
          require('dap').step_out()
        end,
        desc = 'step [o]ut',
      },
      {
        '<leader>db',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = '[b]reakpoint',
      },
      {
        '<leader>du',
        function()
          require('dapui').toggle()
        end,
        desc = 'toggle [u]i',
      },
    },
    after = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      dap.defaults.fallback.terminal_win_cmd = 'enew'
      dapui.setup {
        icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
        controls = {
          icons = {
            pause = '⏸',
            play = '▶',
            step_into = '⏎',
            step_over = '⏭',
            step_out = '⏮',
            step_back = 'b',
            run_last = '▶▶',
            terminate = '⏹',
            disconnect = '⏏',
          },
        },
      }
      vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
      vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
      local breakpoint_icons = vim.g.have_nerd_font
          and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
        or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
      for type, icon in pairs(breakpoint_icons) do
        local tp = 'Dap' .. type
        local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
        vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
      end
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close
      require('dap-go').setup { delve = {} }
    end,
  },
}
```

**Step 6: Rewrite neotest.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'neotest',
    cmd = 'Neotest',
    keys = {
      {
        '<leader>tt',
        function()
          require('neotest').run.run()
        end,
        desc = 'run [t]est',
      },
      {
        '<leader>tf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = 'run [f]ile',
      },
      {
        '<leader>to',
        function()
          require('neotest').summary.toggle()
        end,
        desc = '[o]verview',
      },
      {
        '<leader>tp',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'output [p]anel',
      },
      {
        '<leader>tr',
        function()
          require('neotest').run.run_last()
        end,
        desc = '[r]e-run last',
      },
      {
        '<leader>tx',
        function()
          require('neotest').run.stop()
        end,
        desc = 'e[x]it',
      },
      {
        '<leader>td',
        function()
          require('neotest').run.run { strategy = 'dap' }
        end,
        desc = '[d]ebug test',
      },
    },
    after = function()
      local adapters = {
        require 'rustaceanvim.neotest',
        require 'neotest-python' {
          dap = { justMyCode = false },
          pytest_discover_instances = true,
        },
        require 'neotest-vitest',
        require 'neotest-foundry',
      }
      if vim.fn.executable 'go' == 1 then
        table.insert(adapters, require 'neotest-golang')
      end
      require('neotest').setup { adapters = adapters }
    end,
  },
}
```

**Step 7: Rewrite trouble.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'trouble.nvim',
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
```

**Step 8: Verify syntax**

Run: `for f in config/nvim/lua/plugins/gitsigns.lua config/nvim/lua/plugins/lualine.lua config/nvim/lua/plugins/which-key.lua config/nvim/lua/plugins/dashboard.lua config/nvim/lua/plugins/dap.lua config/nvim/lua/plugins/neotest.lua config/nvim/lua/plugins/trouble.lua; do luac -p "$f" && echo "$f OK"; done`
Expected: All OK.

**Step 9: Commit**

```bash
git add config/nvim/lua/plugins/gitsigns.lua config/nvim/lua/plugins/lualine.lua config/nvim/lua/plugins/which-key.lua config/nvim/lua/plugins/dashboard.lua config/nvim/lua/plugins/dap.lua config/nvim/lua/plugins/neotest.lua config/nvim/lua/plugins/trouble.lua
git commit -m "rewrite git, UI, debug, testing plugin configs for lze"
```

---

### Task 11: Rewrite plugin configs — remaining utilities

**Files:**
- Modify: `config/nvim/lua/plugins/conform.lua`
- Modify: `config/nvim/lua/plugins/grug-far.lua`
- Modify: `config/nvim/lua/plugins/go-nvim.lua`
- Modify: `config/nvim/lua/plugins/markdown.lua`
- Modify: `config/nvim/lua/plugins/mini.lua`
- Modify: `config/nvim/lua/plugins/outline.lua`
- Modify: `config/nvim/lua/plugins/nvim-ufo.lua`
- Modify: `config/nvim/lua/plugins/yanky.lua`

**Step 1: Rewrite conform.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'conform.nvim',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    after = function()
      require('conform').setup {
        notify_on_error = false,
        format_on_save = function(bufnr)
          local disable_filetypes = { c = true, cpp = true }
          local lsp_format_opt
          if disable_filetypes[vim.bo[bufnr].filetype] then
            lsp_format_opt = 'never'
          else
            lsp_format_opt = 'fallback'
          end
          return { timeout_ms = 500, lsp_format = lsp_format_opt }
        end,
        formatters_by_ft = {
          lua = { 'stylua' },
          go = { 'golangci_lint' },
        },
        formatters = {
          golangci_lint = {
            command = 'golangci-lint',
            args = { 'run', '--fix', '$FILENAME' },
            stdin = false,
          },
        },
      }
    end,
  },
}
```

**Step 2: Rewrite grug-far.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'grug-far.nvim',
    cmd = 'GrugFar',
    keys = {
      {
        '<leader>qg',
        function()
          local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
          require('grug-far').open {
            transient = true,
            prefills = { filesFilter = ext and ext ~= '' and '*.' .. ext or nil },
          }
        end,
        mode = { 'n', 'v' },
        desc = '[g]lobal',
      },
      {
        '<leader>qw',
        function()
          local grug = require 'grug-far'
          if vim.fn.mode():match '[vV]' then
            grug.with_visual_selection()
          else
            local buf_name = vim.api.nvim_buf_get_name(0)
            grug.open { transient = true, prefills = { paths = buf_name ~= '' and buf_name or nil } }
          end
        end,
        mode = { 'n', 'v' },
        desc = '[w]ithin buffer/selection',
      },
    },
    after = function()
      require('grug-far').setup {}
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'grug-far',
        callback = function()
          vim.keymap.set({ 'i', 'n' }, '<Esc>', '<Cmd>stopinsert | bd!<CR>', { buffer = true })
        end,
      })
    end,
  },
}
```

**Step 3: Rewrite go-nvim.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'go.nvim',
    ft = { 'go', 'gomod' },
    after = function()
      require('go').setup {}
    end,
  },
}
```

**Step 4: Rewrite markdown.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'render-markdown.nvim',
    ft = 'markdown',
    after = function()
      require('render-markdown').setup {
        latex = { enabled = false },
      }
    end,
  },
}
```

**Step 5: Rewrite mini.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'mini.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.cursorword').setup()
      require('mini.trailspace').setup()
      require('mini.indentscope').setup {
        symbol = '│',
        options = {
          try_as_border = true,
          indent_at_cursor = true,
        },
        draw = {
          delay = 0,
          animation = require('mini.indentscope').gen_animation.none(),
        },
      }
      vim.api.nvim_create_autocmd({ 'FileType', 'TermOpen', 'BufEnter' }, {
        pattern = '*',
        callback = function()
          if vim.bo.buftype == 'terminal' or vim.bo.filetype == 'fzf' or vim.fn.bufname():match 'fzf' then
            vim.b.miniindentscope_disable = true
          end
        end,
      })
    end,
  },
}
```

**Step 6: Rewrite outline.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'outline.nvim',
    cmd = { 'Outline', 'OutlineOpen' },
    keys = {
      { '<leader>co', '<cmd>Outline<CR>', desc = '[o]utline' },
    },
    after = function()
      require('outline').setup {}
    end,
  },
}
```

**Step 7: Rewrite nvim-ufo.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'nvim-ufo',
    event = 'BufReadPost',
    after = function()
      require('ufo').setup {
        provider_selector = function()
          return { 'treesitter', 'indent' }
        end,
      }
    end,
  },
}
```

**Step 8: Rewrite yanky.lua**

Replace entire file:

```lua
require('lze').load {
  {
    'yanky.nvim',
    event = 'DeferredUIEnter',
    keys = {
      { 'P', '<Plug>(YankyPutBefore)', mode = { 'n', 'x' }, desc = 'Put before' },
      { 'gp', '<Plug>(YankyGPutAfter)', mode = { 'n', 'x' }, desc = 'GPut after' },
      { 'gP', '<Plug>(YankyGPutBefore)', mode = { 'n', 'x' }, desc = 'GPut before' },
      { '<c-p>', '<Plug>(YankyPreviousEntry)', desc = 'Yanky previous' },
      { '<c-n>', '<Plug>(YankyNextEntry)', desc = 'Yanky next' },
    },
    after = function()
      require('yanky').setup {
        preserve_cursor_position = { enabled = true },
      }
    end,
  },
}

require('lze').load {
  {
    'substitute.nvim',
    keys = {
      {
        's',
        function()
          require('substitute').operator()
        end,
        desc = 'Substitute',
      },
      {
        'ss',
        function()
          require('substitute').line()
        end,
        desc = 'Substitute line',
      },
      {
        'S',
        function()
          require('substitute').eol()
        end,
        desc = 'Substitute to EOL',
      },
      {
        's',
        function()
          require('substitute').visual()
        end,
        mode = 'x',
        desc = 'Substitute',
      },
    },
    after = function()
      require('substitute').setup {
        on_substitute = function(event)
          require('yanky.integration').substitute()(event)
        end,
        highlight_substituted_text = { enabled = true, timer = 300 },
      }
    end,
  },
}
```

**Step 9: Verify syntax**

Run: `for f in config/nvim/lua/plugins/conform.lua config/nvim/lua/plugins/grug-far.lua config/nvim/lua/plugins/go-nvim.lua config/nvim/lua/plugins/markdown.lua config/nvim/lua/plugins/mini.lua config/nvim/lua/plugins/outline.lua config/nvim/lua/plugins/nvim-ufo.lua config/nvim/lua/plugins/yanky.lua; do luac -p "$f" && echo "$f OK"; done`
Expected: All OK.

**Step 10: Commit**

```bash
git add config/nvim/lua/plugins/conform.lua config/nvim/lua/plugins/grug-far.lua config/nvim/lua/plugins/go-nvim.lua config/nvim/lua/plugins/markdown.lua config/nvim/lua/plugins/mini.lua config/nvim/lua/plugins/outline.lua config/nvim/lua/plugins/nvim-ufo.lua config/nvim/lua/plugins/yanky.lua
git commit -m "rewrite remaining utility plugin configs for lze"
```

---

### Task 12: Delete nix-paths.lua and lazy-lock.json

**Files:**
- Delete: `config/nvim/lua/nix-paths.lua` (if it exists as a tracked file — it's generated by HM, but check)
- Delete: `config/nvim/lazy-lock.json` (if tracked)

**Step 1: Check if files are tracked**

Run: `git ls-files config/nvim/lazy-lock.json config/nvim/lua/nix-paths.lua`
Expected: Shows tracked files (if any).

**Step 2: Remove tracked files**

Run: `git rm -f config/nvim/lazy-lock.json 2>/dev/null; git rm -f config/nvim/lua/nix-paths.lua 2>/dev/null; true`

**Step 3: Add to .gitignore if needed**

If `lazy-lock.json` was tracked, it's no longer needed. No gitignore change needed since these files simply won't exist.

**Step 4: Commit (if any changes)**

```bash
git diff --cached --quiet || git commit -m "remove lazy-lock.json and nix-paths.lua"
```

---

### Task 13: Update CLAUDE.md and clean up references

**Files:**
- Modify: `CLAUDE.md` (update architecture docs, remove lazy.nvim references)
- Modify: `home/common/default.nix:251` (remove nvim-runtime symlink if no longer needed)

**Step 1: Update CLAUDE.md**

In the "Config Files (dotfiles)" section, update the nvim entry to mention nix-wrapper-modules instead of `recursive = true` / HM injection.

In the "Path Templating" section, update the `nix-paths.lua` description to mention `nix-info` plugin instead.

**Step 2: Remove nvim-runtime symlink**

In `home/common/default.nix`, remove line 251:
```nix
".local/share/nvim-runtime".source = "${pkgs.neovim-unwrapped}/share/nvim/runtime";
```

This was for `.luarc.json` to find the Neovim runtime. The wrapper handles runtime paths.

**Step 3: Commit**

```bash
git add CLAUDE.md home/common/default.nix
git commit -m "update docs for nix-wrapper-modules migration"
```

---

### Task 14: Build and validate

**Step 1: Run nix flake check**

Run: `nix flake check`
Expected: No errors.

**Step 2: Run linting**

Run: `just check`
Expected: All checks pass.

**Step 3: Attempt build (dry run)**

Run: `nix build .#darwinConfigurations.macbook.system --dry-run`
Expected: Shows what would be built, no evaluation errors.

**Step 4: Apply**

Run: `just switch`
Expected: Configuration applies successfully. Neovim is available as `nvim`.

**Step 5: Verify Neovim works**

Run: `nvim --headless +q`
Expected: No errors on startup.

Run: `nvim --headless +"lua print(vim.inspect(require('nix-info')))" +q`
Expected: Prints the nix-info table with configPath.

**Step 6: Commit any fixups**

```bash
git add -A
git diff --cached --quiet || git commit -m "fix: post-migration adjustments"
```

---

### Task 15: Clean up lazy.nvim artifacts

**Step 1: Remove lazy.nvim data directory**

After confirming everything works:

Run: `rm -rf ~/.local/share/nvim/lazy`
Expected: Old lazy.nvim plugin directory removed.

**Step 2: Final verification**

Open Neovim, verify:
- Theme loads (earthtone light background)
- Completion works (open a `.lua` file, trigger completion)
- Treesitter highlighting works
- LSP works (open a `.nix` file, check diagnostics)
- Keymaps work (`<leader>ff` opens fzf, `<leader>g` opens lazygit)
- Session restoration works

No commit needed — this is runtime cleanup.
