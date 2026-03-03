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
