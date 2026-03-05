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
	"Misc",
}

-- Collect keymaps
local by_category = {}
local files = find_lua_files(config_dir)

for _, filepath in ipairs(files) do
	local keymaps = parse_file(filepath)
	if #keymaps > 0 then
		local cat = category_for(filepath)
		if not by_category[cat] then
			by_category[cat] = {}
		end
		for _, km in ipairs(keymaps) do
			by_category[cat][#by_category[cat] + 1] = km
		end
	end
end

-- Output
add("# Neovim Keymaps")
add("")
add("> Auto-generated by `just keymaps` from source files. Do not edit manually.")
add("")

local function mode_display(m)
	return (m or "n"):gsub(",", " ")
end

-- Deduplicate within each category
for cat, keymaps in pairs(by_category) do
	local seen = {}
	local deduped = {}
	for _, km in ipairs(keymaps) do
		local key = km.lhs .. "|" .. km.mode .. "|" .. km.desc
		if not seen[key] then
			seen[key] = true
			deduped[#deduped + 1] = km
		end
	end
	by_category[cat] = deduped
end

-- Ordered categories
for _, cat in ipairs(category_order) do
	local keymaps = by_category[cat]
	if keymaps and #keymaps > 0 then
		add("## " .. cat)
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

-- Remaining categories
for cat, keymaps in pairs(by_category) do
	local found = false
	for _, c in ipairs(category_order) do
		if c == cat then
			found = true
			break
		end
	end
	if not found and #keymaps > 0 then
		add("## " .. cat)
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

io.write(table.concat(out, "\n") .. "\n")
