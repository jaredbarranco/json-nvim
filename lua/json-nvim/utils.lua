local M = {}

-- some of the functions below
-- are just in case

local function get_compact_jq(input)
	local cmd
	if vim.fn.has("win32") == 1 then
		local one_line = vim.fn.substitute(input, [[\n]], "", "g")
		cmd = string.format("echo %s | jq . -c", one_line)
		input = vim.fn.system(cmd)
		input = vim.fn.substitute(input, [[\n]], "", "g")
	else
		cmd = string.format("echo '%s' | jq . -c", input)
		input = vim.fn.system(cmd)
		input = input:gsub("[\n\r]", "")
	end

	return input
end

local function get_raw_jq(input)
	local cmd
	if vim.fn.has("win32") == 1 then
		local one_line = vim.fn.substitute(input, [[\n]], "", "g")
		cmd = string.format("echo %s | jq . -r", one_line)
		input = vim.fn.system(cmd)
		input = vim.fn.substitute(input, [[\n]], "", "g")
	else
		cmd = string.format("echo '%s' | jq . -r", input)
		input = vim.fn.system(cmd)
		input = input:gsub("[\n\r]", "")
	end

	return input
end

function M.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = math.abs(s_end[2] - s_start[2]) + 1
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
	lines[1] = string.sub(lines[1], s_start[3], -1)
	if n_lines == 1 then
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
	else
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
	end
	return table.concat(lines, "\n")
end

function M.get_selection_positions()
	return {
		s_start = vim.fn.getpos("'<"),
		s_end = vim.fn.getpos("'>"),
	}
end

function M.get_treesitter_root()
	local cur_node = vim.treesitter.get_node({})
	if cur_node == nil then
		error("can't get current node of treesitter")
	end
	local root = cur_node:tree():root():child(0)

	if root == nil then
		error("could not get root")
	end

	return root
end

function M.get_buffer_content_as_string()
	local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
	return table.concat(content, "\n")
end

function M.get_buffer_content_as_string_up_to_cursor_pos()
	local line, _ = vim.api.nvim_win_get_cursor(0)
	local content = vim.api.nvim_buf_get_lines(0, 0, line[1], false)
	return table.concat(content, "\n")
end

-- print content of all children of treesitter node
function M.get_tsnode_children_content(tsnode)
	local count = tsnode:child_count()
	local r = {}
	for i = 0, count - 1 do
		local child = tsnode:child(i)
		local buf_id = vim.api.nvim_get_current_buf()
		local content = vim.treesitter.get_node_text(child, buf_id)
		if content == nil then
			content = "child on index " .. i .. " was nil"
		end
		table.insert(r, content)
	end
	return r
end

-- gets the nearest array or object token to cursor
-- returns json content of that token
function M.get_nearest_token_and_content()
	local cur_node = vim.treesitter.get_node({})
	if cur_node == nil then
		-- token, content, is_error
		return nil, "", true
	end

	local target = cur_node
	while true do
		if target:type() == "array" or target:type() == "object" then
			break
		end
		target = target:parent()
	end

	local buf_id = vim.api.nvim_get_current_buf()
	local content = vim.treesitter.get_node_text(target, buf_id)

	-- token, content, is_error
	return target, content, false
end

function M.validate_jq_input(input)
	local is_invalid
	local cmd
	local result
	if vim.fn.has("win32") == 1 then
		local one_line = vim.fn.substitute(input, [[\n]], "", "g")
		cmd = string.format("echo %s | jq . -e", one_line)
		result = vim.fn.system(cmd)
		result = vim.fn.substitute(result, [[\n]], "", "g")

		is_invalid = result:find("jq . %-e") or result:find("error")
	else
		cmd = string.format("echo '%s' | jq -e .", input)
		result = vim.fn.system(cmd)

		is_invalid = result:find("error")
	end
	return is_invalid
end

function M.get_minified_jq(input)
	local result = get_compact_jq(input)
	return result
end

function M.replace_tsnode_text(node, replacement_text)
	local start_row, start_col, end_row, end_col = node:range()
	vim.api.nvim_buf_set_text(
		vim.api.nvim_get_current_buf(),
		start_row,
		start_col,
		end_row,
		end_col,
		{ replacement_text }
	)
end

function M.get_formatted_jq(input)
	local result
	local cmd
	if vim.fn.has("win32") == 1 then
		local one_line = vim.fn.substitute(input, [[\n]], "", "g")
		cmd = string.format("echo %s | jq .", one_line)
		result = vim.fn.system(cmd)
	else
		cmd = string.format("echo '%s' | jq .", input)
		result = vim.fn.system(cmd)
	end

	return result
end

function M.get_escaped_input(input)
	local compacted = get_compact_jq(input)

	local pattern = '([\\"])'
	local replacement = "\\%1"
	local escaped = compacted:gsub(pattern, replacement)
	escaped = '"' .. escaped .. '"'

	return escaped
end

function M.get_unescaped_input(input)
	local compacted = get_compact_jq(input)
	local raw = get_raw_jq(compacted)

	return raw
end

return M
