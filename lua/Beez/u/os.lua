local uv = vim.uv or vim.loop
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

--- Reads a specific line from a file using `sed`
---@param file_path string
---@param line_number integer
---@return string?
function M.read_line_at(file_path, line_number)
  local handle = io.popen(string.format("sed -n '%dp' %s", line_number, file_path))
  if handle then
    local line = handle:read("*l")
    handle:close()
    return line
  end
end

--- Gets the modified time of a file
---@param path string
---@return integer
function M.mtime(path)
  local stat = vim.uv.fs_stat(path)
  if stat then
    local mtime = stat.mtime.sec
    return mtime
  end
  return 0
end

--- Walk a directory path recursively similar to python walk
---@param dir_path string
---@return fun(): string, string[], string[]
function M.walk(dir_path)
  return coroutine.wrap(function()
    local stack = { dir_path }

    while #stack > 0 do
      local current = table.remove(stack)
      local dirs, files = {}, {}
      for name, type in vim.fs.dir(current) do
        local path = vim.fs.joinpath(current, name)
        if type == "directory" then
          table.insert(stack, path)
          table.insert(dirs, name)
        else
          table.insert(files, name)
        end
      end
      coroutine.yield(current, dirs, files)
    end
  end)
end

--- Copies a directory
---@param src string
---@param dest string
---@param opts? {chmod_mode: integer}
function M.copy_dir(src, dest, opts)
  opts = opts or {}

  uv.fs_mkdir(dest, 493) -- 0755
  for root, dirs, files in M.walk(src) do
    local relative_path = vim.fs.relpath(src, root)
    for _, d in ipairs(dirs) do
      local src_dir = vim.fs.joinpath(root, d)
      local dest_dir = vim.fs.joinpath(dest, relative_path, d)
      local stat = uv.fs_stat(src_dir)
      uv.fs_mkdir(dest_dir, stat.mode)
    end
    for _, f in ipairs(files) do
      local src_file = vim.fs.joinpath(root, f)
      local dest_file = vim.fs.joinpath(dest, relative_path, f)
      uv.fs_copyfile(src_file, dest_file)

      if opts.chmod_mode then
        uv.fs_chmod(dest_file, opts.chmod_mode)
      end
    end
  end
end

--- Compare 2 files and see if they are identical
---@param path1 string
---@param path2 string
---@return boolean
function M.is_file_same(path1, path2)
  local f1 = io.open(path1, "rb")
  local f2 = io.open(path2, "rb")
  if not f1 and not f2 then
    return true
  elseif not f1 or not f2 then
    return false
  end

  -- Compare sizes
  local size1 = f1:seek("end")
  local size2 = f2:seek("end")
  if size1 ~= size2 then
    f1:close()
    f2:close()
    return false
  end

  -- Compare contents in chunks
  f1:seek("set")
  f2:seek("set")
  local chunk_size = 4096
  while true do
    local b1 = f1:read(chunk_size)
    local b2 = f2:read(chunk_size)
    if b1 ~= b2 then
      f1:close()
      f2:close()
      return false
    end
    if not b1 then
      break
    end
  end

  f1:close()
  f2:close()
  return true
end

return M
