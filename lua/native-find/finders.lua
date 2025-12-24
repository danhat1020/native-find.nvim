local M = {}

-- Find files using native Vim functionality
function M.files()
	-- Use Vim's native file finding with ** glob
	local saved_path = vim.o.path
	vim.o.path = vim.o.path .. ",**"

	-- Get all files recursively
	local files = vim.fn.glob("**/*", false, true)

	vim.o.path = saved_path

	-- Filter out directories and format results
	local results = {}
	for _, file in ipairs(files) do
		if vim.fn.isdirectory(file) == 0 then
			-- Extract filename and directory
			local filename = vim.fn.fnamemodify(file, ":t")
			local directory = vim.fn.fnamemodify(file, ":h")

			-- Display format: "filename - directory" or just "filename" if at root
			local display
			if directory == "." or directory == "" then
				display = filename
			else
				display = directory .. " -> " .. filename
			end

			table.insert(results, {
				value = file,
				display = display,
				filename = filename,
				action = function(item)
					vim.cmd("edit " .. vim.fn.fnameescape(item.value))
				end,
			})
		end
	end

	return results
end

-- Find open buffers
function M.buffers()
	local buffers = vim.api.nvim_list_bufs()
	local results = {}

	for _, buf in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				-- Extract filename and directory
				local filename = vim.fn.fnamemodify(name, ":t")
				local directory = vim.fn.fnamemodify(name, ":~:.:h")

				-- Display format: "filename - directory"
				local display
				if directory == "." or directory == "" then
					display = filename
				else
					display = directory .. " -> " .. filename
				end

				table.insert(results, {
					value = name,
					display = display,
					filename = filename,
					bufnr = buf,
					action = function(item)
						vim.api.nvim_set_current_buf(item.bufnr)
					end,
				})
			end
		end
	end

	return results
end

-- Buffer previewer
function M.buffer_previewer(item)
	if not item.bufnr then
		return {}
	end

	local lines = vim.api.nvim_buf_get_lines(item.bufnr, 0, 100, false)
	local filetype = vim.api.nvim_buf_get_option(item.bufnr, "filetype")

	return lines, filetype
end

-- Live grep using system grep or ripgrep
function M.live_grep(query)
	-- Don't search for empty query
	if not query or query == "" then
		return {}
	end

	-- Check if ripgrep is available, otherwise use grep
	local cmd
	if vim.fn.executable("rg") == 1 then
		cmd = string.format('rg -i --line-number --column --no-heading --color=never "%s"', query)
	else
		cmd = string.format('grep -irn "%s" .', query)
	end

	local output = vim.fn.systemlist(cmd)
	local results = {}

	for _, line in ipairs(output) do
		-- Parse grep output: filename:line:col:text or filename:line:text
		local file, lnum, text = line:match("^([^:]+):(%d+):.*:(.*)$")
		if not file then
			file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
		end

		if file and lnum and text then
			local filename = vim.fn.fnamemodify(file, ":t")
			local directory = vim.fn.fnamemodify(file, ":h")

			-- Display format: "filename:line - directory: text"
			local display
			if directory == "." or directory == "" then
				display = filename .. ":" .. lnum .. ": " .. text:gsub("^%s+", "")
			else
				display = filename .. ":" .. lnum .. " - " .. directory .. ": " .. text:gsub("^%s+", "")
			end

			table.insert(results, {
				value = line,
				display = display,
				file = file,
				lnum = tonumber(lnum),
				text = text,
				action = function(item)
					vim.cmd("edit " .. vim.fn.fnameescape(item.file))
					vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
				end,
			})
		end
	end

	return results
end

-- Grep specific word
function M.grep_word(query)
	-- Don't search for empty query
	if not query or query == "" then
		return {}
	end

	local cmd
	if vim.fn.executable("rg") == 1 then
		cmd = string.format('rg --line-number --column --no-heading --color=never "%s"', query)
	else
		cmd = string.format('grep -rn "%s" .', query)
	end

	local output = vim.fn.systemlist(cmd)
	local results = {}

	for _, line in ipairs(output) do
		local file, lnum, text = line:match("^([^:]+):(%d+):.*:(.*)$")
		if not file then
			file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
		end

		if file and lnum and text then
			table.insert(results, {
				value = line,
				display = file .. ":" .. lnum .. ": " .. text:gsub("^%s+", ""),
				file = file,
				lnum = tonumber(lnum),
				text = text,
				action = function(item)
					vim.cmd("edit " .. vim.fn.fnameescape(item.file))
					vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
				end,
			})
		end
	end

	return results
end

-- Grep previewer
function M.grep_previewer(item)
	if not item.file or not item.lnum then
		return {}
	end

	local lines = vim.fn.readfile(item.file)
	local start_line = math.max(1, item.lnum - 10)
	local end_line = math.min(#lines, item.lnum + 10)

	local preview_lines = {}
	for i = start_line, end_line do
		table.insert(preview_lines, lines[i])
	end

	-- Try to detect filetype from extension
	local filetype = vim.filetype.match({ filename = item.file }) or ""

	return preview_lines, filetype
end

-- Find help tags
function M.help_tags()
	local tags_files = vim.api.nvim_get_runtime_file("doc/tags", true)
	local results = {}
	local seen = {}

	for _, tags_file in ipairs(tags_files) do
		local lines = vim.fn.readfile(tags_file)
		for _, line in ipairs(lines) do
			local tag = line:match("^(%S+)")
			if tag and not seen[tag] then
				seen[tag] = true
				table.insert(results, {
					value = tag,
					display = tag,
					action = function(item)
						vim.cmd("help " .. item.value)
					end,
				})
			end
		end
	end

	return results
end

return M
