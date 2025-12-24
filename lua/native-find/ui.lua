local M = {}

-- UI state
M.state = {
	prompt_buf = nil,
	results_buf = nil,
	preview_buf = nil,
	prompt_win = nil,
	results_win = nil,
	preview_win = nil,
	ns_id = vim.api.nvim_create_namespace("native_find"),
}

-- Create floating window
local function create_float_win(buf, config)
	local win = vim.api.nvim_open_win(buf, false, config)
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:Normal")
	return win
end

-- Calculate window dimensions
local function get_window_config()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Split into sections: prompt (1 line), results (rest), preview (40%)
	local preview_width = math.floor(width * 0.4)
	local results_width = width - preview_width - 1
	local results_height = height - 3 -- Leave room for prompt and borders

	return {
		row = row,
		col = col,
		width = width,
		height = height,
		results_width = results_width,
		preview_width = preview_width,
		results_height = results_height,
	}
end

-- Create the UI
function M.create()
	local config = get_window_config()

	-- Create buffers
	M.state.prompt_buf = vim.api.nvim_create_buf(false, true)
	M.state.results_buf = vim.api.nvim_create_buf(false, true)
	M.state.preview_buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer options
	for _, buf in ipairs({ M.state.prompt_buf, M.state.results_buf, M.state.preview_buf }) do
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
	end

	-- Create prompt window (top)
	M.state.prompt_win = create_float_win(M.state.prompt_buf, {
		relative = "editor",
		row = config.row,
		col = config.col,
		width = config.width - 1,
		height = 1,
		style = "minimal",
		border = { "╭", "─", "╮", "│", "", "", "", "│" },
	})

	-- Create results window (bottom left)
	M.state.results_win = create_float_win(M.state.results_buf, {
		relative = "editor",
		row = config.row + 2,
		col = config.col,
		width = config.results_width,
		height = config.results_height,
		style = "minimal",
		border = { "├", "─", "┬", "│", "┴", "─", "╰", "│" },
	})

	-- Create preview window (bottom right)
	M.state.preview_win = create_float_win(M.state.preview_buf, {
		relative = "editor",
		row = config.row + 2,
		col = config.col + config.results_width + 1,
		width = config.preview_width,
		height = config.results_height,
		style = "minimal",
		border = { "", "─", "╮", "│", "╯", "─", "┴", "" },
	})

	-- Set cursor in prompt window
	vim.api.nvim_set_current_win(M.state.prompt_win)

	return M.state
end

-- Update prompt text
function M.update_prompt(text, prompt_prefix)
	if not M.state.prompt_buf or not vim.api.nvim_buf_is_valid(M.state.prompt_buf) then
		return
	end
	local full_line = prompt_prefix .. text
	vim.api.nvim_buf_set_lines(M.state.prompt_buf, 0, -1, false, { full_line })

	-- Set cursor position after the prompt prefix
	if M.state.prompt_win and vim.api.nvim_win_is_valid(M.state.prompt_win) then
		vim.api.nvim_win_set_cursor(M.state.prompt_win, { 1, #full_line })
	end
end

-- Update results list
function M.update_results(results, selected_idx)
	if not M.state.results_buf or not vim.api.nvim_buf_is_valid(M.state.results_buf) then
		return
	end

	-- Clear previous highlights
	vim.api.nvim_buf_clear_namespace(M.state.results_buf, M.state.ns_id, 0, -1)

	-- Format results
	local lines = {}
	for i, result in ipairs(results) do
		local display = result.display or result.value or tostring(result)
		lines[i] = display
	end

	-- Set lines
	vim.api.nvim_buf_set_lines(M.state.results_buf, 0, -1, false, lines)

	-- Highlight selected line
	if selected_idx and selected_idx > 0 and selected_idx <= #results then
		vim.api.nvim_buf_add_highlight(M.state.results_buf, M.state.ns_id, "Visual", selected_idx - 1, 0, -1)
	end

	-- Scroll to selection
	if M.state.results_win and vim.api.nvim_win_is_valid(M.state.results_win) then
		vim.api.nvim_win_set_cursor(M.state.results_win, { selected_idx or 1, 0 })
	end
end

-- Update preview pane
function M.update_preview(lines, filetype)
	if not M.state.preview_buf or not vim.api.nvim_buf_is_valid(M.state.preview_buf) then
		return
	end

	-- Set preview content
	vim.api.nvim_buf_set_lines(M.state.preview_buf, 0, -1, false, lines or {})

	-- Set filetype for syntax highlighting
	if filetype then
		vim.api.nvim_buf_set_option(M.state.preview_buf, "filetype", filetype)
	end
end

-- Close all windows and cleanup
function M.close()
	local wins = { M.state.prompt_win, M.state.results_win, M.state.preview_win }
	for _, win in ipairs(wins) do
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	M.state.prompt_win = nil
	M.state.results_win = nil
	M.state.preview_win = nil
	M.state.prompt_buf = nil
	M.state.results_buf = nil
	M.state.preview_buf = nil
end

return M
