local M = {}
local ui = require("native-find.ui")

-- Picker state
local state = {
	results = {},
	filtered_results = {},
	query = "",
	selected_idx = 1,
	finder = nil,
	previewer = nil,
	on_select = nil,
	prompt_prefix = "> ",
	is_live = false, -- Whether to re-run finder on each keystroke
}

-- Simple fuzzy matching function
local function fuzzy_match(str, pattern)
	if pattern == "" then
		return true, 0
	end

	local str_lower = str:lower()
	local pattern_lower = pattern:lower()
	local pattern_idx = 1
	local score = 0
	local consecutive = 0

	for i = 1, #str_lower do
		if str_lower:sub(i, i) == pattern_lower:sub(pattern_idx, pattern_idx) then
			pattern_idx = pattern_idx + 1
			consecutive = consecutive + 1
			-- Bonus for consecutive matches
			score = score + 1 + consecutive * 5

			if pattern_idx > #pattern_lower then
				return true, score
			end
		else
			consecutive = 0
		end
	end

	return pattern_idx > #pattern_lower, score
end

-- Score a result based on where matches occur
local function score_result(result, pattern)
	if pattern == "" then
		return 0
	end

	local search_text = result.display or result.value or tostring(result)
	local filename = result.filename or ""

	-- Try to match in filename first
	local filename_match, filename_score = fuzzy_match(filename, pattern)
	if filename_match then
		-- Big bonus for filename matches
		return filename_score * 10
	end

	-- Fall back to full path matching
	local full_match, full_score = fuzzy_match(search_text, pattern)
	if full_match then
		return full_score
	end

	return -1 -- No match
end

-- Filter results based on query
local function filter_results()
	-- For live finders, re-run the finder with the query
	if state.is_live then
		if type(state.finder) == "function" then
			state.results = state.finder(state.query) or {}
		end
		state.filtered_results = state.results
	else
		-- For static finders, do fuzzy matching with scoring
		if state.query == "" then
			state.filtered_results = state.results
		else
			local scored_results = {}
			for _, result in ipairs(state.results) do
				local score = score_result(result, state.query)
				if score >= 0 then
					table.insert(scored_results, { result = result, score = score })
				end
			end

			-- Sort by score (highest first)
			table.sort(scored_results, function(a, b)
				return a.score > b.score
			end)

			-- Extract just the results
			state.filtered_results = {}
			for _, item in ipairs(scored_results) do
				table.insert(state.filtered_results, item.result)
			end
		end
	end

	-- Reset selection if out of bounds
	if state.selected_idx > #state.filtered_results then
		state.selected_idx = 1
	end

	ui.update_results(state.filtered_results, state.selected_idx)
end

-- Update preview for current selection
local function update_preview()
	if not state.previewer or #state.filtered_results == 0 then
		ui.update_preview({})
		return
	end

	local selected = state.filtered_results[state.selected_idx]
	if selected then
		local preview_lines, filetype = state.previewer(selected)
		ui.update_preview(preview_lines or {}, filetype)
	end
end

-- Handle text input
local function on_text_changed()
	-- Get current line from prompt buffer
	local lines = vim.api.nvim_buf_get_lines(ui.state.prompt_buf, 0, -1, false)
	local line = lines[1] or ""

	-- Ensure prompt prefix is always present
	if not vim.startswith(line, state.prompt_prefix) then
		line = state.prompt_prefix
		vim.api.nvim_buf_set_lines(ui.state.prompt_buf, 0, -1, false, { line })
		-- Restore cursor position
		vim.schedule(function()
			if ui.state.prompt_win and vim.api.nvim_win_is_valid(ui.state.prompt_win) then
				vim.api.nvim_win_set_cursor(ui.state.prompt_win, { 1, #line })
			end
		end)
	end

	-- Strip prompt prefix to get actual query
	if vim.startswith(line, state.prompt_prefix) then
		state.query = line:sub(#state.prompt_prefix + 1)
	else
		state.query = ""
	end

	filter_results()
	update_preview()
end

-- Move selection up
local function move_selection_up()
	if state.selected_idx > 1 then
		state.selected_idx = state.selected_idx - 1
		ui.update_results(state.filtered_results, state.selected_idx)
		update_preview()
	end
end

-- Move selection down
local function move_selection_down()
	if state.selected_idx < #state.filtered_results then
		state.selected_idx = state.selected_idx + 1
		ui.update_results(state.filtered_results, state.selected_idx)
		update_preview()
	end
end

-- Select current item
local function select_current()
	-- Exit insert mode first
	local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
	vim.api.nvim_feedkeys(esc, "n", false)

	if #state.filtered_results == 0 then
		ui.close()
		return
	end

	local selected = state.filtered_results[state.selected_idx]
	ui.close()

	if state.on_select then
		state.on_select(selected)
	elseif selected.action then
		selected.action(selected)
	elseif selected.value then
		-- Default action: open file or execute command
		vim.cmd("edit " .. vim.fn.fnameescape(selected.value))
	end
end

-- Setup keymaps for picker
local function setup_keymaps()
	local opts = { noremap = true, silent = true, buffer = ui.state.prompt_buf }

	-- Prevent deleting the prompt prefix
	vim.keymap.set("i", "<BS>", function()
		local cursor = vim.api.nvim_win_get_cursor(ui.state.prompt_win)
		local col = cursor[2]
		-- Only allow backspace if we're past the prompt
		if col > #state.prompt_prefix then
			return "<BS>"
		end
		return ""
	end, { expr = true, noremap = true, silent = true, buffer = ui.state.prompt_buf })

	-- Navigation
	vim.keymap.set("i", "<C-n>", move_selection_down, opts)
	vim.keymap.set("i", "<C-p>", move_selection_up, opts)
	vim.keymap.set("i", "<Down>", move_selection_down, opts)
	vim.keymap.set("i", "<Up>", move_selection_up, opts)

	-- Selection
	vim.keymap.set("i", "<CR>", select_current, opts)
	vim.keymap.set("i", "<C-y>", select_current, opts)

	-- Close
	vim.keymap.set("i", "<Esc>", function()
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)
		vim.schedule(function()
			ui.close()
		end)
	end, opts)
	vim.keymap.set("i", "<C-c>", function()
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)
		vim.schedule(function()
			ui.close()
		end)
	end, opts)

	-- Text change autocmd
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		buffer = ui.state.prompt_buf,
		callback = on_text_changed,
	})
end

-- Start the picker
function M.start(opts)
	opts = opts or {}

	-- Initialize state
	state.query = opts.initial_query or ""
	state.selected_idx = 1
	state.finder = opts.finder
	state.previewer = opts.previewer
	state.on_select = opts.on_select
	state.prompt_prefix = opts.prompt or "> "
	state.is_live = opts.is_live or false

	-- Get initial results
	if type(state.finder) == "function" then
		state.results = state.finder(state.query) or {}
	else
		state.results = state.finder or {}
	end

	state.filtered_results = state.results

	-- Create UI
	ui.create()

	-- Setup keymaps
	setup_keymaps()

	-- Initial render
	ui.update_prompt(state.query, state.prompt_prefix)
	ui.update_results(state.filtered_results, state.selected_idx)
	update_preview()

	-- Start insert mode and move cursor to the right position
	vim.schedule(function()
		local insert = vim.api.nvim_replace_termcodes("i", true, false, true)
		vim.api.nvim_feedkeys(insert, "n", false)
		-- Send right arrow key to move cursor after the prompt and initial query
		local right_key = vim.api.nvim_replace_termcodes("<Right>", true, false, true)
		local total_offset = #state.prompt_prefix + #state.query
		for _ = 1, total_offset do
			vim.api.nvim_feedkeys(right_key, "n", false)
		end
	end)
end

return M
