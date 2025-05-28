local u = require("Beez.u")
local M = {}

-- for path in input:gmatch("([%w%./_%-]+/[%w%./_%-]+%.%w+:%d+)") do
--- Infer the full path of a truncated path
---@param truncated_path string
---@return string?
local function infer_truncated_path(truncated_path)
  local path = truncated_path:match("^.*/(lua/.+)$")
  if path == nil then
    return
  end
  local found = vim.api.nvim_get_runtime_file(path, false)
  if #found >= 0 then
    return found[1]
  end
end

--- Match generic line for path
---@param line string
---@return string?, string?
local function match_path(line)
  local path = line:match("([%w%./_%-%(%)]+/[%w%./_%-%(%)]+%.%w+)")
  if path ~= nil then
    if path:startswith("...") or not path:startswith("/") then
      path = infer_truncated_path(path)
      if path == nil then
        return nil, nil
      end
    end
    return path, nil
  end
  return nil, nil
end

--- Match lua style line for path and line no
---@param line string
---@return string?, string?
local function match_lua_path(line)
  local path = line:match("([%w%./_%-%(%)%~]+/[%w%./_%-%(%)]+%.%w+:%d+)")
  if path == nil then
    path = line:match("([%w%./_%-%(%)%~]+/[%w%./_%-%(%)]+%.%w+%s)")
  end
  if path ~= nil then
    local lineno = path:match(":(%d+)")
    if lineno ~= nil then
      path = path:sub(1, #path - #lineno - 1)
    end
    if path:startswith("...") then
      path = infer_truncated_path(path)
      if path == nil then
        return nil, nil
      end
    end
    if path:startswith("~") then
      path = vim.fn.expand(path)
    end
    return path, lineno or "1"
  end
  return nil, nil
end

--- Parse a line for lua trackback details
---@param line string
---@return string[]?
local function match_lua_traceback(line)
  local path, lineno, text =
    line:match("([%w%./_%-%(%)]+/[%w%./_%-%(%)]+%.%w+):(%d+):(.*)")
  if path ~= nil then
    if path:startswith("...") then
      path = infer_truncated_path(path)
      if path == nil then
        return
      end
    end
    return { path, lineno, text }
  end
end

--- Get the lua trackback entries for buffer
---@param lines string[]
---@return vim.quickfix.entry[]
local function get_traceback_entries_lua(lines)
  local qflist = {}
  local unique = {}
  for _, line in ipairs(lines) do
    local match = match_lua_traceback(line)
    local col = 1
    local end_col = 200
    if match ~= nil then
      ---@type vim.quickfix.entry
      local qf = {
        filename = match[1],
        lnum = tonumber(match[2]),
        text = match[3],
        col = col,
        end_col = end_col,
      }
      local key = qf.filename .. ":" .. qf.lnum
      if not unique[key] then
        unique[key] = true
        table.insert(qflist, qf)
      end
    end
  end
  return qflist
end

--- Match python style line for path and line no
---@param line string
---@return string?, string?
local function match_python_path(line)
  local path = line:match('([%w%./_%-%(%)]+/[%w%./_%-%(%)]+%.%w+", line %d+)')
  if path ~= nil then
    local lineno = line:match('", line (%d+),')
    if lineno ~= nil then
      path = path:sub(1, #path - #lineno - 8)
    end
    return path, lineno
  end
  return nil, nil
end

--- Parse a line for python trackback details
---@param line string
---@param next_line string
---@return string[]?
local function match_python_traceback(line, next_line)
  local path, lineno, text = line:match('File "(/.-%.py)", line (%d+), in (.+)')
  if path ~= nil then
    return { path, lineno, text .. ": " .. u.strs.trim(next_line) }
  end
end

--- Get the python trackback entries for buffer
---@param lines string[]
---@return vim.quickfix.entry[]
local function get_traceback_entries_python(lines)
  local qflist = {}
  for i, line in ipairs(lines) do
    local next_line = lines[i + 1]
    local match = match_python_traceback(line, next_line)
    local col = 1
    local end_col = 200
    if match ~= nil then
      ---@type vim.quickfix.entry
      local qf = {
        filename = match[1],
        lnum = tonumber(match[2]),
        text = match[3],
        pattern = lines[i + 1],
        col = col,
        end_col = end_col,
      }
      table.insert(qflist, qf)
    end
  end
  return qflist
end

--- Gets all the file paths from the current buffer and creates a quickfix list.
function M.create_qf_of_paths()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ft = vim.bo[bufnr].filetype
  local entries = {}

  if ft == "python" then
    entries = get_traceback_entries_python(lines)
  elseif ft == "lua" then
    entries = get_traceback_entries_lua(lines)
  end

  if #entries > 0 then
    vim.fn.setqflist(entries, "r")
    vim.cmd("Trouble qflist open")
  end
end

--- Go to file version that opens the file in the previous window
function M.go_to_file()
  local line = vim.fn.getline(".")
  local path, lineno
  path, lineno = match_lua_path(line)
  if path == nil or lineno == nil then
    path, lineno = match_python_path(line)
  end
  if path == nil or lineno == nil then
    path, lineno = match_path(line)
  end

  if path ~= nil then
    vim.cmd("wincmd p")
    vim.cmd("e " .. path)
    if lineno ~= nil then
      vim.cmd(lineno)
    end
  else
    require("snacks.notify").notify(
      "No path found on current line...",
      { level = "warn" }
    )
  end
end

return M
