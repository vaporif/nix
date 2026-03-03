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
      local breakpoint_icons = vim.g.have_nerd_font and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
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
