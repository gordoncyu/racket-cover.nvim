
local M = {}

M.path_separator = "/"
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1
if M.is_windows == true then
    M.path_separator = "\\"
end

---Joins arbitrary number of paths together.
---@param ... string The paths to join.
---@return string
function M.path_join(...)
    local args = {...}
    if #args == 0 then
        return ""
    end

    local all_parts = {}
    if type(args[1]) =="string" and args[1]:sub(1, 1) == M.path_separator then
        all_parts[1] = ""
    end

    for _, arg in ipairs(args) do
        local arg_parts = vim.fn.split(arg, M.path_separator)
        vim.list_extend(all_parts, arg_parts)
    end
    return table.concat(all_parts, M.path_separator)
end

---Writes a string to a file
---@param file_path string
---@param content string
---@return string? io_errmsg
function M.write_to_file(file_path, content)
    local file, err = io.open(file_path, "w")
    if err or not file then
        return err
    end
    file:write(content)
    file:close()
end

---Reads from a file as a string
---@param file_path string
---@return string? content
---@return string? io_errmsg
function M.read_from_file(file_path)
  local file, err = io.open(file_path, "r")
  if err or not file then
    return nil, err
  end
  local content = file:read("*a")
  file:close()
  return content, nil
end

---Gets the byte number of the line for the given buf_or_path, like vim.fn.line2byte
---@param buf_or_path integer | string
---@param line_number integer
---@return integer?
---@return string? errmsg
function M.line2byte(buf_or_path, line_number)
    local bufnr
    if type(buf_or_path) == 'number' then
        bufnr = buf_or_path
    elseif type(buf_or_path) == 'string' then
        bufnr = vim.fn.bufadd(buf_or_path)
        if bufnr == 0 then
            return nil, "vim failed to load buffer: " .. buf_or_path
        end
        vim.fn.bufload(bufnr)
    else
        error('Invalid argument: expected buffer number or file path')
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_number < 1 or line_number > line_count + 1 then
        return -1
    end
    if line_number == 1 then
        return 1
    end
    local total_bytes = 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_number - 1, true)
    for _, line in ipairs(lines) do
        total_bytes = total_bytes + #line + 1 -- +1 for newline character
    end
    return total_bytes + 1
end

---Gets the line number of the byte for the given buf_or_path, like vim.fn.byte2line
---@param buf_or_path integer | string
---@param byte integer
---@return integer?
---@return string? errmsg
function M.byte2line(buf_or_path, byte)
    local bufnr
    if type(buf_or_path) == 'number' then
        bufnr = buf_or_path
    elseif type(buf_or_path) == 'string' then
        bufnr = vim.fn.bufadd(buf_or_path)
        if bufnr == 0 then
            return nil, "vim failed to load buffer: " .. buf_or_path
        end
        vim.fn.bufload(bufnr)
    else
        error('Invalid argument: expected buffer number or file path')
    end

    if byte < 1 then
        return -1
    end
    local total_bytes = 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local total_buffer_bytes = 0
    for _, line in ipairs(lines) do
        total_buffer_bytes = total_buffer_bytes + #line + 1
    end
    if byte > total_buffer_bytes then
        return -1
    end
    total_bytes = 0
    for i, line in ipairs(lines) do
        local line_length = #line + 1 -- +1 for newline character
        total_bytes = total_bytes + line_length
        if byte <= total_bytes then
            return i
        end
    end
    return -1
end

---Merges two tables, preferring values from the first table when keys overlap.
--- @param preferred table? The first table.
--- @param default table? The second table.
--- @return table merged The merged table.
function M.merge_tables(preferred, default)
    local merged = {}
    if default ~= nil then
        for k, v in pairs(default) do
            merged[k] = v
        end
    end
    if preferred ~= nil then
        for k, v in pairs(preferred) do
            merged[k] = v
        end
    end
    return merged
end

return M
