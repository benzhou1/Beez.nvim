local M = { cache = {} }

--- Is os windows
---@return boolean
function M.is_win()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

function M.is_mac()
  return vim.fn.has("mac") == 1
end

--- Read the contents of a file
---@param path string
---@return string
M.read_file = function(path)
  local a = require("plenary.async")
  local err, fd = a.uv.fs_open(path, "r", 438)
  assert(not err, err)

  ---@diagnostic disable-next-line: redefined-local
  local err, stat = a.uv.fs_fstat(fd)
  assert(not err, err)

  ---@diagnostic disable-next-line: redefined-local
  local err, data = a.uv.fs_read(fd, stat.size, 0)
  assert(not err, err)

  ---@diagnostic disable-next-line: redefined-local
  local err = a.uv.fs_close(fd)
  assert(not err, err)

  return data
end

--- Read all the lines from a file
---@param path string
---@return table<string>
function M.read_lines(path)
  local file = io.open(path, "r")

  -- Read all lines
  local lines = {}
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end
  return lines
end

--- Reads the first line of a file
---@param file_path string
---@return string
function M.read_first_line(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return ""
  end
  local first_line = file:read("*l")
  file:close()
  return first_line
end

return M
