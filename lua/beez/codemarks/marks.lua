local Mark = require("beez.codemarks.mark")
local u = require("beez.u")

---@class Beez.codemarks.marks
---@field marks Beez.codemarks.mark[]
---@field keys table<string, boolean>
Marks = {}
Marks.__index = Marks

--- Creates a new instance of Marks
---@param marks Beez.codemarks.markdata[]
---@return Beez.codemarks.marks
function Marks:new(marks)
  local m = {}
  setmetatable(m, Marks)
  m.marks = {}
  m.keys = {}
  for _, _m in ipairs(marks) do
    local mark = Mark:new(_m)
    m.marks[mark.file] = m.marks[mark.file] or {}
    table.insert(m.marks[mark.file], mark)
    m.keys[mark:key()] = true
  end
  return m
end

--- Filter marks based on options
---@param opts? {path?: string}
---@return Beez.codemarks.mark[]
function Marks:list(opts)
  opts = opts or {}
  local path = opts.path or vim.api.nvim_buf_get_name(0)
  local marks = self.marks[path] or {}

  -- Sort mark by line number
  table.sort(marks, function(a, b)
    return a.lineno < b.lineno
  end)
  return marks
end

--- Toggles a mark on current line
function Marks:toggle()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local key = Mark.key_from_data(file_path, pos[1])
  if self.keys[key] then
    self:del()
  else
    self:add()
  end
end

--- Add mark on current line
--- @param opts? table
function Marks:add(opts)
  opts = opts or {}
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = u.os.read_line_at(file_path, pos[1]) or ""
  ---@type Beez.codemarks.markdata
  local data = {
    file = file_path,
    lineno = pos[1],
    col = pos[2],
    line = line,
  }

  local mark = Mark:new(data)
  local key = mark:key()
  if self.keys[key] then
    vim.notify("Mark already exists at this location", vim.log.levels.WARN)
    return
  end

  self.marks[mark.file] = self.marks[mark.file] or {}
  table.insert(self.marks[mark.file], mark)
  self.keys[key] = true
  vim.notify("Created mark at: " .. mark.lineno, vim.log.levels.INFO)
end

--- Delete a mark on current line
function Marks:del()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local marks = self.marks[file_path]
  if marks == nil then
    return
  end

  local mark = u.tables.remove(marks, function(mark)
    return mark.file == file_path and mark.lineno == pos[1]
  end)
  if mark ~= nil then
    self.keys[mark:key()] = nil
  end
end

--- Serialize the marks to a table
---@return Beez.codemarks.markdata[]
function Marks:serialize()
  local marks = {}
  for _, _marks in pairs(self.marks) do
    for _, v in ipairs(_marks) do
      table.insert(marks, v:serialize())
    end
  end
  return marks
end

--- Go to the next mark from current cursor position
function Marks:next()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local marks = self.marks[file_path] or {}
  if marks == nil then
    return
  end

  local mark = marks[1]
  for _, m in ipairs(marks) do
    if m.lineno > pos[1] then
      mark = m
      break
    end
  end
  if mark ~= nil then
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    vim.cmd("normal! zz")
  end
end

--- Go to the previous mark from current cursor position
function Marks:prev()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local marks = self.marks[file_path] or {}
  if marks == nil then
    return
  end

  local mark = marks[#marks]
  for _, m in ipairs(marks) do
    if m.lineno < pos[1] then
      mark = m
      break
    end
  end
  if mark ~= nil then
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    vim.cmd("normal! zz")
  end
end

--- Clears all marks for current file
function Marks:clear()
  local file_path = vim.api.nvim_buf_get_name(0)
  local marks = self.marks[file_path] or {}
  if marks == nil then
    return
  end

  for _, mark in ipairs(marks) do
    self.keys[mark:key()] = nil
  end
  self.marks[file_path] = nil
end

return Marks
