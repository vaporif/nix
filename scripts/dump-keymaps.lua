-- Dump all neovim keymaps by parsing source files
-- Usage: nvim -l scripts/dump-keymaps.lua [config_dir]
-- Parses vim.keymap.set, map(), and keys={} tables including multiline entries

local config_dir = arg[1] or "config/nvim/lua"

local out = {}
local function add(s)
	out[#out + 1] = s or ""
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return {}
	end
	local result = {}
	for line in f:lines() do
		result[#result + 1] = line
	end
	f:close()
	return result
end

local function find_lua_files(dir)
	local handle = io.popen('find "' .. dir .. '" -name "*.lua" -type f | sort')
	if not handle then
		return {}
	end
	local result = {}
	for line in handle:lines() do
		result[#result + 1] = line
	end
	handle:close()
	return result
end

local function count_char(s, ch)
	local n = 0
	for _ in s:gmatch("%" .. ch) do
		n = n + 1
	end
	return n
end

-- Extract brace-balanced or paren-balanced block starting at line i
local function extract_block(file_lines, i, open, close)
	local block = {}
	local depth = 0
	for j = i, #file_lines do
		block[#block + 1] = file_lines[j]
		depth = depth + count_char(file_lines[j], open) - count_char(file_lines[j], close)
		if depth <= 0 then
			return block, j
		end
	end
	return block, #file_lines
end

-- Parse a block (joined string) for desc
local function get_desc(s)
	return s:match("desc%s*=%s*'([^']+)'") or s:match('desc%s*=%s*"([^"]+)"')
end

-- Parse a keys table entry block for lhs, mode, desc
local function parse_keys_entry(block_str)
	local desc = get_desc(block_str)
	if not desc or desc == "" or desc:match("which_key_ignore") then
		return nil
	end

	-- lhs is the first quoted string after the OUTER opening {
	-- Anchor to start of block to avoid matching nested { like mode = { 'n' }
	local lhs = block_str:match("^%s*{%s*'([^']+)'") or block_str:match('^%s*{%s*"([^"]+)"')
	if not lhs then
		-- multiline: { \n 'lhs', ...
		lhs = block_str:match("^%s*{%s*\n%s*'([^']+)'") or block_str:match('^%s*{%s*\n%s*"([^"]+)"')
	end
	if not lhs then
		return nil
	end

	-- mode: explicit mode = '...' or mode = { ... }, default 'n'
	local mode = "n"
	local mode_tbl = block_str:match("mode%s*=%s*(%b{})")
	if mode_tbl then
		local modes = {}
		for m in mode_tbl:gmatch("'([^']+)'") do
			modes[#modes + 1] = m
		end
		mode = table.concat(modes, ",")
	else
		local mode_str = block_str:match("mode%s*=%s*'([^']+)'") or block_str:match('mode%s*=%s*"([^"]+)"')
		if mode_str then
			mode = mode_str
		end
	end

	return { lhs = lhs, mode = mode, desc = desc }
end

-- Parse vim.keymap.set(...) block for lhs, mode, desc
local function parse_keymap_set(block_str)
	local desc = get_desc(block_str)
	if not desc or desc == "" or desc:match("which_key_ignore") then
		return nil
	end

	-- mode: first arg — 'mode' or { 'n', 'v', ... }
	local mode = "n"
	local mode_tbl = block_str:match("vim%.keymap%.set%(%s*(%b{})")
	if mode_tbl then
		local modes = {}
		for m in mode_tbl:gmatch("'([^']+)'") do
			modes[#modes + 1] = m
		end
		mode = table.concat(modes, ",")
	else
		local m = block_str:match("vim%.keymap%.set%(%s*'([^']+)'")
		if m then
			mode = m
		end
	end

	-- lhs: second arg after mode
	local lhs
	if mode_tbl then
		lhs = block_str:match("vim%.keymap%.set%(%s*%b{}%s*,%s*'([^']+)'")
			or block_str:match('vim%.keymap%.set%(%s*%b{}%s*,%s*"([^"]+)"')
	else
		lhs = block_str:match("vim%.keymap%.set%(%s*'[^']*'%s*,%s*'([^']+)'")
			or block_str:match('vim%.keymap%.set%(%s*"[^"]*"%s*,%s*"([^"]+)"')
	end

	if not lhs then
		return nil
	end

	return { lhs = lhs, mode = mode, desc = desc }
end

-- Parse map('lhs', func, { desc = '...' }) — local wrapper in gitsigns/lsp
local function parse_map_call(block_str)
	-- First check for { desc = '...' } style
	local desc = get_desc(block_str)
	if not desc then
		-- Positional desc: map('lhs', expr, 'desc')
		-- Find last quoted string before closing paren
		local all_strings = {}
		for s in block_str:gmatch("'([^']+)'") do
			all_strings[#all_strings + 1] = s
		end
		if #all_strings >= 2 then
			desc = all_strings[#all_strings]
		end
	end
	if not desc or desc == "" then
		return nil
	end

	-- Mode: first arg if it's a single-char mode string
	local mode = "n"
	local first_arg = block_str:match("map%(%s*'([^']+)'")
	if first_arg and #first_arg <= 3 and first_arg:match("^[nvixosc]+$") then
		mode = first_arg
		-- lhs is second arg
		local lhs = block_str:match("map%(%s*'[^']*'%s*,%s*'([^']+)'")
		if lhs then
			return { lhs = lhs, mode = mode, desc = desc }
		end
	else
		-- map(lhs, func, desc) — no explicit mode (LSP pattern, mode is 'n' from wrapper)
		local lhs = first_arg
		if lhs then
			return { lhs = lhs, mode = mode, desc = desc }
		end
	end
	return nil
end

-- Parse treesitter-style data-driven loops:
--   for _, m in ipairs { {data}, {data} } do
--     vim.keymap.set({modes}, m[1], func, { desc = m[N] })
--   end
local function parse_treesitter_loops(file_lines)
	local keymaps = {}
	local i = 1
	while i <= #file_lines do
		local line = file_lines[i]
		if line:match("for%s+_,%s+%w+%s+in%s+ipairs%s*{") then
			-- Extract the data table (brace-balanced from the ipairs {)
			local data_block, data_end = extract_block(file_lines, i, "{", "}")
			local data_str = table.concat(data_block, "\n")

			-- Scan forward from after "} do" for the loop body (until "end")
			local body_lines = {}
			for j = data_end + 1, math.min(#file_lines, data_end + 20) do
				if file_lines[j]:match("^%s+end$") or file_lines[j]:match("^%s+end%s") then
					break
				end
				body_lines[#body_lines + 1] = file_lines[j]
			end
			local body_str = table.concat(body_lines, "\n")

			-- Find desc index: desc = m[N]
			local desc_idx = body_str:match("desc%s*=%s*%w+%[(%d+)%]")
			if desc_idx then
				desc_idx = tonumber(desc_idx)

				-- Find mode from vim.keymap.set in the loop body
				local mode = "n"
				local mode_tbl = body_str:match("vim%.keymap%.set%(%s*(%b{})")
				if mode_tbl then
					local modes = {}
					for m in mode_tbl:gmatch("'([^']+)'") do
						modes[#modes + 1] = m
					end
					mode = table.concat(modes, ",")
				else
					local m = body_str:match("vim%.keymap%.set%(%s*'([^']+)'")
					if m then
						mode = m
					end
				end

				-- Parse data entries from the ipairs table
				-- Skip the outer ipairs brace, match inner { ... } entries
				local inner = data_str:match("{(.+)}")
				if inner then
					for entry in inner:gmatch("%b{}") do
						local values = {}
						for v in entry:gmatch("'([^']+)'") do
							values[#values + 1] = v
						end
						if #values >= desc_idx then
							keymaps[#keymaps + 1] = { lhs = values[1], mode = mode, desc = values[desc_idx] }
						end
					end
				end
			end

			i = data_end + 1
		else
			i = i + 1
		end
	end
	return keymaps
end

-- Main parser for a file
local function parse_file(filepath)
	local file_lines = read_file(filepath)
	local keymaps = {}

	local i = 1
	while i <= #file_lines do
		local line = file_lines[i]

		-- vim.keymap.set(...)
		if line:match("vim%.keymap%.set%(") and not line:match("local%s+map%s*=") then
			local block, end_i = extract_block(file_lines, i, "(", ")")
			local block_str = table.concat(block, "\n")
			local km = parse_keymap_set(block_str)
			if km then
				keymaps[#keymaps + 1] = km
			end
			i = end_i + 1
		-- map('...', ...) — local wrapper calls (not the definition)
		elseif line:match("^%s+map%(") and not line:match("local%s+.-%s*map") and not line:match("nvim_set_keymap") then
			local block, end_i = extract_block(file_lines, i, "(", ")")
			local block_str = table.concat(block, "\n")
			local km = parse_map_call(block_str)
			if km then
				keymaps[#keymaps + 1] = km
			end
			i = end_i + 1
		-- keys table entries: { ... } inside keys = { ... }
		-- Detect by indent: entry-level { is typically at 6+ spaces
		elseif line:match("^%s%s%s%s%s%s+{") and not line:match("keys%s*=") and not line:match("^%s*%-%-") then
			local block, end_i = extract_block(file_lines, i, "{", "}")
			local block_str = table.concat(block, "\n")
			-- Only parse if it looks like a keymap entry (has desc or a key-like first string)
			if block_str:match("desc%s*=") then
				local km = parse_keys_entry(block_str)
				if km then
					keymaps[#keymaps + 1] = km
				end
			end
			i = end_i + 1
		else
			i = i + 1
		end
	end

	-- Also check for treesitter-style data-driven loops
	local ts_keymaps = parse_treesitter_loops(file_lines)
	for _, km in ipairs(ts_keymaps) do
		keymaps[#keymaps + 1] = km
	end

	-- Parse blink.cmp-style keymap = { ['key'] = { 'action' } } config tables
	local in_keymap_block = false
	for _, line in ipairs(file_lines) do
		if line:match("keymap%s*=%s*{") then
			in_keymap_block = true
		elseif in_keymap_block then
			if line:match("^%s+}") and not line:match("%[") then
				in_keymap_block = false
			else
				local key, action = line:match("%[%s*'([^']+)'%s*%]%s*=%s*{%s*'([^']+)'")
				if key and action then
					keymaps[#keymaps + 1] = { lhs = key, mode = "i", desc = action }
				end
			end
		end
	end

	return keymaps
end

-- Category mapping
local categories = {
	["core/keymaps"] = "General",
	["core/lsp"] = "LSP (buffer-local)",
	["plugins/fzf"] = "Search (fzf-lua)",
	["plugins/flash"] = "Navigation (flash)",
	["plugins/harpoon"] = "Navigation (harpoon)",
	["plugins/gitsigns"] = "Git (gitsigns)",
	["plugins/difftastic"] = "Git (difftastic)",
	["plugins/snacks"] = "Git (snacks)",
	["plugins/trouble"] = "Diagnostics (trouble)",
	["plugins/outline"] = "Diagnostics (outline)",
	["plugins/dap"] = "Debug (DAP)",
	["plugins/neotest"] = "Testing (neotest)",
	["plugins/grug-far"] = "Search & Replace (grug-far)",
	["plugins/yanky"] = "Editing (yanky/substitute)",
	["plugins/treesitter"] = "Treesitter Textobjects",
	["plugins/mini"] = "Editing (mini)",
	["plugins/blink-cmp"] = "Completion (blink.cmp)",
	["plugins/misc"] = "Misc",
}

local function category_for(filepath)
	for pattern, name in pairs(categories) do
		if filepath:find(pattern, 1, true) then
			return name
		end
	end
	local base = filepath:match("([^/]+)%.lua$")
	return base and ("Plugins (" .. base .. ")") or "Other"
end

local category_order = {
	"General",
	"LSP (buffer-local)",
	"Search (fzf-lua)",
	"Navigation (flash)",
	"Navigation (harpoon)",
	"Editing (yanky/substitute)",
	"Editing (mini)",
	"Treesitter Textobjects",
	"Git (gitsigns)",
	"Git (difftastic)",
	"Git (snacks)",
	"Search & Replace (grug-far)",
	"Diagnostics (trouble)",
	"Diagnostics (outline)",
	"Debug (DAP)",
	"Testing (neotest)",
	"Completion (blink.cmp)",
	"Misc",
}

-- Collect all keymaps from all files
local all_keymaps = {}
local files = find_lua_files(config_dir)

for _, filepath in ipairs(files) do
	local keymaps = parse_file(filepath)
	for _, km in ipairs(keymaps) do
		all_keymaps[#all_keymaps + 1] = km
	end
end

-- Regroup by leader prefix (matching which-key groups)
local prefix_groups = {
	{ prefix = "<leader>f", name = "Find (<leader>f)" },
	{ prefix = "<leader>c", name = "Code (<leader>c)" },
	{ prefix = "<leader>h", name = "Git Hunks (<leader>h)" },
	{ prefix = "<leader>d", name = "Debug (<leader>d)" },
	{ prefix = "<leader>t", name = "Test (<leader>t)" },
	{ prefix = "<leader>b", name = "Trouble (<leader>b)" },
	{ prefix = "<leader>q", name = "Search & Replace (<leader>q)" },
	{ prefix = "<leader>s", name = "Split (<leader>s)" },
}

local by_group = {}
local ungrouped = {}

for _, km in ipairs(all_keymaps) do
	local placed = false
	for _, pg in ipairs(prefix_groups) do
		if
			km.lhs:sub(1, #pg.prefix) == pg.prefix
			or km.lhs:sub(1, #pg.prefix) == pg.prefix:gsub("<leader>", "<Space>")
		then
			if not by_group[pg.name] then
				by_group[pg.name] = {}
			end
			by_group[pg.name][#by_group[pg.name] + 1] = km
			placed = true
			break
		end
	end
	if not placed then
		-- Group remaining by source-file category or fallback
		local cat
		if km.lhs:match("^[%[%]]") then
			cat = "Navigation ([] motions)"
		elseif km.lhs:match("^g") then
			cat = "Goto (g)"
		elseif km.lhs:match("^<leader>") then
			cat = "General (<leader>)"
		elseif km.lhs:match("^<[cC]%-") then
			cat = "Ctrl bindings"
		else
			cat = "Other"
		end
		if not by_group[cat] then
			by_group[cat] = {}
		end
		by_group[cat][#by_group[cat] + 1] = km
	end
end

-- Output
add("# Keymaps")
add("")
add("> Auto-generated by `just keymaps` from source files. Do not edit manually.")
add("")
add("## Neovim (Leader: Space)")
add("")

local function mode_display(m)
	return (m or "n"):gsub(",", " ")
end

-- Deduplicate within each group
for cat, keymaps in pairs(by_group) do
	local seen = {}
	local deduped = {}
	for _, km in ipairs(keymaps) do
		local key = km.lhs .. "|" .. km.mode .. "|" .. km.desc
		if not seen[key] then
			seen[key] = true
			deduped[#deduped + 1] = km
		end
	end
	by_group[cat] = deduped
end

local group_order = {
	"General (<leader>)",
	"Code (<leader>c)",
	"Find (<leader>f)",
	"Git Hunks (<leader>h)",
	"Search & Replace (<leader>q)",
	"Split (<leader>s)",
	"Debug (<leader>d)",
	"Test (<leader>t)",
	"Trouble (<leader>b)",
	"Goto (g)",
	"Navigation ([] motions)",
	"Ctrl bindings",
	"Completion (blink.cmp)",
	"Other",
}

-- Check for blink.cmp keymaps (not <leader> prefixed, handled separately)
for _, km in ipairs(all_keymaps) do
	if km.desc and km.desc:match("^s[a-z]") and km.lhs:match("^<[A-Z]") == nil then
		-- blink keymaps already in by_group via "Other" or "Ctrl bindings"
	end
end

-- Merge blink.cmp completion keymaps into their own group
local blink_keys = {}
for cat, keymaps in pairs(by_group) do
	local remaining = {}
	for _, km in ipairs(keymaps) do
		-- blink.cmp actions: snippet_forward, select_prev, etc.
		if
			km.desc:match("^snippet_")
			or km.desc:match("^select_")
			or km.desc:match("^scroll_")
			or km.desc == "show"
			or km.desc == "hide"
		then
			blink_keys[#blink_keys + 1] = km
		else
			remaining[#remaining + 1] = km
		end
	end
	by_group[cat] = remaining
end
if #blink_keys > 0 then
	by_group["Completion (blink.cmp)"] = blink_keys
end

-- Output ordered groups
for _, group in ipairs(group_order) do
	local keymaps = by_group[group]
	if keymaps and #keymaps > 0 then
		add("### " .. group)
		add("")
		add("| Key | Mode | Action |")
		add("|-----|------|--------|")
		for _, km in ipairs(keymaps) do
			local lhs = km.lhs:gsub("|", "\\|")
			add(string.format("| `%s` | %s | %s |", lhs, mode_display(km.mode), km.desc))
		end
		add("")
	end
end

-- Remaining groups not in order list
for group, keymaps in pairs(by_group) do
	local found = false
	for _, g in ipairs(group_order) do
		if g == group then
			found = true
			break
		end
	end
	if not found and #keymaps > 0 then
		add("### " .. group)
		add("")
		add("| Key | Mode | Action |")
		add("|-----|------|--------|")
		for _, km in ipairs(keymaps) do
			local lhs = km.lhs:gsub("|", "\\|")
			add(string.format("| `%s` | %s | %s |", lhs, mode_display(km.mode), km.desc))
		end
		add("")
	end
end

-- ===== Karabiner =====
local function parse_karabiner(filepath)
	local f = io.open(filepath, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		return {}
	end

	local keymaps = {}
	local key_display = {
		up_arrow = "Up",
		down_arrow = "Down",
		left_arrow = "Left",
		right_arrow = "Right",
		escape = "Escape",
		right_option = "Right Option",
	}

	for _, profile in ipairs(data.profiles or {}) do
		for _, rule in ipairs((profile.complex_modifications or {}).rules or {}) do
			for _, m in ipairs(rule.manipulators or {}) do
				local is_extend = false
				for _, cond in ipairs(m.conditions or {}) do
					if cond.name == "extend" and cond.value == 1 then
						is_extend = true
					end
				end

				if m.from and m.to and m.to[1] then
					local from = m.from.key_code
					local to = m.to[1]

					if is_extend and to.key_code and not to.modifiers then
						keymaps[#keymaps + 1] = {
							key = "CapsLock + " .. from,
							desc = key_display[to.key_code] or to.key_code,
							section = "extend",
						}
					elseif not is_extend and from ~= "caps_lock" and to.key_code then
						keymaps[#keymaps + 1] = {
							key = key_display[from] or from,
							desc = key_display[to.key_code] or to.key_code,
							section = "remap",
						}
					end
				end
			end
		end
	end
	return keymaps
end

-- ===== skhd =====
local function parse_skhd(filepath)
	local lines = read_file(filepath)
	local keymaps = {}
	for _, line in ipairs(lines) do
		local key, app = line:match('hyper%s*%-%s*(%w)%s*:%s*open%s+%-a%s+"([^"]+)"')
		if key then
			local comment = line:match("#%s*(.+)$")
			keymaps[#keymaps + 1] = {
				key = "hyper + " .. key,
				app = app,
				desc = comment and comment:match("^%s*(.-)%s*$") or app,
			}
		end
	end
	return keymaps
end

-- ===== WezTerm =====
local wezterm_action_names = {
	CloseCurrentPane = "Close pane",
	SplitVertical = "Split vertical",
	SplitHorizontal = "Split horizontal",
	TogglePaneZoomState = "Toggle pane zoom",
	PromptInputLine = "Rename tab",
	Search = "Search",
	ActivateCopyMode = "Copy mode",
	ShowLauncher = "Show launcher",
	ToggleFullScreen = "Toggle fullscreen",
	IncreaseFontSize = "Increase font size",
	DecreaseFontSize = "Decrease font size",
	ResetFontSize = "Reset font size",
	CopyTo = "Copy",
	PasteFrom = "Paste",
}

local function parse_wezterm(filepath)
	local lines = read_file(filepath)
	local sections = { main = {}, resize_pane = {}, move_tab = {} }
	local current_section = nil

	for i = 1, #lines do
		local line = lines[i]

		if line:match("^%s*keys%s*=%s*{") then
			current_section = "main"
		elseif line:match("^%s*resize_pane%s*=%s*{") then
			current_section = "resize_pane"
		elseif line:match("^%s*move_tab%s*=%s*{") then
			current_section = "move_tab"
		elseif line:match("^%s*mouse_bindings%s*=") or line:match("^%s*unix_domains%s*=") then
			current_section = nil
		end

		-- Detect key entry: { key = ... (single line) or {\n key = ... (multi-line)
		local block_start = nil
		if current_section and line:match("{%s*key%s*=") then
			block_start = i
		elseif current_section and line:match("^%s+{%s*$") and i < #lines and lines[i + 1]:match("^%s+key%s*=") then
			block_start = i
		end

		if block_start then
			local block, _ = extract_block(lines, block_start, "{", "}")
			local s = table.concat(block, " ")

			local key = s:match("key%s*=%s*'([^']+)'")
			local mods = s:match("mods%s*=%s*'([^']+)'")
			if not key then
				goto continue
			end

			local desc
			local action_name = s:match("act%.(%w+)")
			if action_name then
				if wezterm_action_names[action_name] then
					desc = wezterm_action_names[action_name]
				elseif action_name == "ActivatePaneDirection" then
					local dir = s:match("ActivatePaneDirection%s+'([^']+)'")
						or s:match("ActivatePaneDirection%s*%(('?[^')]+)'?%)")
					desc = dir and ("Pane " .. dir) or "Activate pane"
				elseif action_name == "AdjustPaneSize" then
					local dir = s:match("AdjustPaneSize%s*{%s*'([^']+)'")
					desc = dir and ("Resize " .. dir:lower()) or "Resize pane"
				elseif action_name == "MoveTabRelative" then
					local n = s:match("MoveTabRelative%((-?%d+)%)")
					desc = n and (tonumber(n) < 0 and "Move tab left" or "Move tab right") or "Move tab"
				elseif action_name == "ActivateKeyTable" then
					local name = s:match("name%s*=%s*'([^']+)'")
					desc = name and (name:gsub("_", " ") .. " mode") or "Key table"
				elseif action_name == "ShowLauncherArgs" then
					desc = "Fuzzy workspace switch"
				else
					desc = action_name:gsub("(%u)", " %1"):match("^%s*(.+)")
				end
			elseif s:match("toggle_split") then
				local dir = s:match("toggle_split%('([^']+)'")
				desc = dir and ("Toggle " .. dir:lower() .. " split") or "Toggle split"
			elseif s:match("'PopKeyTable'") then
				desc = "Exit mode"
			end

			if desc then
				local display_key = key
				if mods then
					local m = mods:gsub("LEADER", "Leader"):gsub("CMD", "Cmd"):gsub("CTRL", "Ctrl"):gsub("ALT", "Alt")
					display_key = m .. " + " .. key
				end

				local target = sections[current_section] or sections.main
				target[#target + 1] = { key = display_key, desc = desc }
			end

			::continue::
		end
	end
	return sections
end

-- ===== Yazi =====
local function parse_yazi(filepath)
	local lines = read_file(filepath)
	local keymaps = {}
	local current = nil

	for _, line in ipairs(lines) do
		if line:match("^%[%[mgr%.prepend_keymap%]%]") then
			if current and current.on and current.desc then
				keymaps[#keymaps + 1] = current
			end
			current = {}
		elseif current then
			local on = line:match("^on%s*=%s*%[(.+)%]")
			if on then
				local keys = {}
				for k in on:gmatch('"([^"]+)"') do
					keys[#keys + 1] = k
				end
				current.on = table.concat(keys, " ")
			end
			local desc = line:match('^desc%s*=%s*"([^"]+)"')
			if desc then
				current.desc = desc
			end
			local run = line:match("^run%s*=%s*(.+)")
			if run and not current.desc then
				if run:match("nvim") then
					current.desc = "Open in Neovim"
				else
					current.desc = run:match("^'([^']+)'") or run:match('^"([^"]+)"') or run
				end
			end
		end
	end
	if current and current.on and current.desc then
		keymaps[#keymaps + 1] = current
	end
	return keymaps
end

-- ===== Output other apps =====

-- Karabiner + skhd
local karabiner_keymaps = parse_karabiner("config/karabiner/karabiner.json")
local skhd_keymaps = parse_skhd("system/darwin/services.nix")

if #karabiner_keymaps > 0 or #skhd_keymaps > 0 then
	add("## System (Karabiner + skhd)")
	add("")

	-- Extend layer arrows
	local extend = {}
	local remap = {}
	for _, km in ipairs(karabiner_keymaps) do
		if km.section == "extend" then
			extend[#extend + 1] = km
		else
			remap[#remap + 1] = km
		end
	end

	if #extend > 0 then
		add("### Extend Layer (CapsLock held)")
		add("")
		add("| Key | Action |")
		add("|-----|--------|")
		for _, km in ipairs(extend) do
			add(string.format("| `%s` | %s |", km.key, km.desc))
		end
		add("")
	end

	if #skhd_keymaps > 0 then
		add("### App Shortcuts (Hyper = CapsLock)")
		add("")
		add("| Key | App |")
		add("|-----|-----|")
		for _, km in ipairs(skhd_keymaps) do
			add(string.format("| `%s` | %s |", km.key, km.app))
		end
		add("")
	end

	if #remap > 0 then
		add("### Remapping")
		add("")
		add("| Key | Action |")
		add("|-----|--------|")
		for _, km in ipairs(remap) do
			add(string.format("| `%s` | %s |", km.key, km.desc))
		end
		add("")
	end
end

-- WezTerm
local wez = parse_wezterm("config/wezterm/init.lua")
if #wez.main > 0 then
	add("## WezTerm (Leader: Ctrl+B)")
	add("")
	add("| Key | Action |")
	add("|-----|--------|")
	for _, km in ipairs(wez.main) do
		add(string.format("| `%s` | %s |", km.key, km.desc))
	end
	add("")

	if #wez.resize_pane > 0 then
		add("### Resize Pane Mode (Leader + r)")
		add("")
		add("| Key | Action |")
		add("|-----|--------|")
		for _, km in ipairs(wez.resize_pane) do
			add(string.format("| `%s` | %s |", km.key, km.desc))
		end
		add("")
	end

	if #wez.move_tab > 0 then
		add("### Move Tab Mode (Leader + m)")
		add("")
		add("| Key | Action |")
		add("|-----|--------|")
		for _, km in ipairs(wez.move_tab) do
			add(string.format("| `%s` | %s |", km.key, km.desc))
		end
		add("")
	end
end

-- Yazi
local yazi_keymaps = parse_yazi("config/yazi/keymap.toml")
if #yazi_keymaps > 0 then
	add("## Yazi (File Manager)")
	add("")
	add("| Key | Action |")
	add("|-----|--------|")
	for _, km in ipairs(yazi_keymaps) do
		add(string.format("| `%s` | %s |", km.on, km.desc))
	end
	add("")
end

io.write(table.concat(out, "\n") .. "\n")
