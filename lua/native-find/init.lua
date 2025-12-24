local M = {}

local picker = require("native-find.picker")
local finders = require("native-find.finders")

-- Find files using native :find with ** globbing
function M.find_files()
	picker.start({
		prompt = "Find files: ",
		finder = finders.files,
	})
end

-- Find open buffers
function M.find_buffers()
	picker.start({
		prompt = "Find buffers: ",
		finder = finders.buffers,
		previewer = finders.buffer_previewer,
	})
end

-- Live grep using native grep/rg
function M.live_grep()
	picker.start({
		prompt = "Live grep: ",
		finder = finders.live_grep,
		previewer = finders.grep_previewer,
		is_live = true,
	})
end

-- Search help documentation
function M.find_help()
	picker.start({
		prompt = "Find help: ",
		finder = finders.help_tags,
	})
end

-- Grep word under cursor
function M.grep_word_under_cursor()
	local word = vim.fn.expand("<cword>")
	picker.start({
		prompt = "Grep: ",
		finder = finders.grep_word,
		previewer = finders.grep_previewer,
		is_live = true,
		initial_query = word,
	})
end

-- Grep WORD under cursor
function M.grep_WORD_under_cursor()
	local word = vim.fn.expand("<cWORD>")
	picker.start({
		prompt = "Grep: ",
		finder = finders.grep_word,
		previewer = finders.grep_previewer,
		is_live = true,
		initial_query = word,
	})
end

-- Generic picker for custom tables
function M.pick(items, opts)
	opts = opts or {}
	picker.start({
		prompt = opts.prompt or "Select: ",
		finder = function()
			return items
		end,
		on_select = opts.on_select,
	})
end

-- Setup function for user configuration
function M.setup(opts)
	opts = opts or {}
	-- Future: Add configuration options here
end

return M
