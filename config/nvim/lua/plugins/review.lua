local settings = (_G.nixInfo and _G.nixInfo.settings or {}).gitlab or {}

local function git(args)
  local res = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  return vim.trim(res.stdout)
end
local function base_ref()
  local head = git { 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD' }
  if head then
    return (head:gsub('^refs/remotes/', ''))
  end
  for _, ref in ipairs { 'origin/main', 'origin/master', 'main', 'master' } do
    if git { 'rev-parse', '--verify', '--quiet', ref } then
      return ref
    end
  end
  return nil
end
local function with_base(fn)
  local base = base_ref()
  if not base then
    vim.notify('No base branch found (origin/HEAD, main, master)', vim.log.levels.WARN)
    return
  end
  local remote, branch = base:match '^([^/]+)/(.+)$'
  if not remote then
    fn(base)
    return
  end
  vim.system({ 'git', 'fetch', '--quiet', remote, branch }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('fetch ' .. base .. ' failed, diffing against the stale ref', vim.log.levels.WARN)
      end
      fn(base)
    end)
  end)
end

local function pick_mr()
  vim.system({ 'glab', 'mr', 'list', '--output', 'json' }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('glab mr list failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
        return
      end
      local ok, mrs = pcall(vim.json.decode, res.stdout)
      if not ok or type(mrs) ~= 'table' or #mrs == 0 then
        vim.notify('No open merge requests', vim.log.levels.INFO)
        return
      end

      local items = {}
      for _, mr in ipairs(mrs) do
        table.insert(items, {
          text = string.format('!%d  %s  (%s → %s)', mr.iid, mr.title, mr.source_branch, mr.target_branch),
          iid = tostring(mr.iid),
        })
      end

      require('snacks').picker.pick {
        title = 'Merge Requests',
        items = items,
        format = 'text',
        confirm = function(picker, item)
          picker:close()
          if not item then
            return
          end
          vim.system({ 'glab', 'mr', 'checkout', item.iid }, { text = true }, function(co)
            vim.schedule(function()
              if co.code ~= 0 then
                vim.notify('glab mr checkout failed: ' .. (co.stderr or ''), vim.log.levels.ERROR)
                return
              end
              vim.cmd 'checktime'
              with_base(function(base)
                vim.cmd('DiffviewOpen ' .. base .. '...HEAD --imply-local')
              end)
            end)
          end)
        end,
      }
    end)
  end)
end

local function map(lhs, rhs, desc, mode)
  vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
end
map('<leader>cvb', function()
  with_base(function(base)
    vim.cmd('DiffviewOpen ' .. base .. '...HEAD --imply-local')
  end)
end, 'vs [b]ase branch')

map('<leader>cvl', function()
  with_base(function(base)
    vim.cmd('DiffviewFileHistory --range=' .. base .. '...HEAD')
  end)
end, 'commit-by-commit [l]og')

map('<leader>cvf', function()
  with_base(function(base)
    vim.cmd('Difft ' .. base .. '...HEAD')
  end)
end, 'structural di[f]f vs base')

map('<leader>cvq', '<cmd>DiffviewClose<CR>', '[q]uit diff view')
map('<leader>cvo', pick_mr, 'check[o]ut an MR')
map('<leader>cvw', function()
  vim.system({ 'glab', 'mr', 'view', '--web' }, { text = true }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify('glab mr view failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
      end)
    end
  end)
end, 'open MR in [w]eb')

if not settings.enable then
  return
end
local function auth_provider()
  local function slurp(path)
    if path == nil or path == '' then
      return nil
    end
    local fd = io.open(path, 'r')
    if not fd then
      return nil
    end
    local content = fd:read '*a'
    fd:close()
    return vim.trim(content)
  end

  local token = slurp(settings.token_path) or vim.env.GITLAB_TOKEN
  if not token then
    vim.notify('No GitLab token: ' .. tostring(settings.token_path) .. ' is unreadable and $GITLAB_TOKEN is unset', vim.log.levels.ERROR)
    return nil, nil, 'missing token'
  end
  return token, slurp(settings.url_path) or vim.env.GITLAB_URL, nil
end

local function gl(action)
  return function()
    require('gitlab')[action]()
  end
end

require('lze').load {
  {
    'gitlab.nvim',
    keys = {
      { '<leader>cvr', gl 'review', desc = 'start [r]eview' },
      { '<leader>cvR', gl 'reload_review', desc = '[R]eload review' },
      { '<leader>cvm', gl 'choose_merge_request', desc = 'choose [m]erge request' },
      { '<leader>cvs', gl 'summary', desc = 'MR [s]ummary' },
      { '<leader>cvd', gl 'toggle_discussions', desc = '[d]iscussion tree' },
      { '<leader>cvn', gl 'create_note', desc = '[n]ote on the MR' },
      { '<leader>cvD', gl 'publish_all_drafts', desc = 'publish [D]rafts' },
      { '<leader>cva', gl 'approve', desc = '[a]pprove' },
      { '<leader>cvA', gl 'revoke', desc = 'revoke [A]pproval' },
      { '<leader>cvp', gl 'pipeline', desc = '[p]ipeline' },
      { '<leader>cvc', gl 'create_comment', desc = '[c]omment on line' },
      { '<leader>cvc', gl 'create_multiline_comment', desc = '[c]omment on range', mode = 'v' },
      { '<leader>cvS', gl 'create_comment_suggestion', desc = '[S]uggestion', mode = 'v' },
    },
    after = function()
      require('gitlab').setup {
        auth_provider = auth_provider,
        server = { binary = settings.binary },
        keymaps = { global = { disable_all = true } },
      }
    end,
  },
}
