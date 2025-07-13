local Mark = require("Beez.codemarks.mark")

---@class Beez.codemarks.marks
---@field marks Beez.codemarks.mark[]
---@field keys table<string, boolean>
---@field archive Beez.codemarks.mark[]
---@field history Beez.codemarks.mark[]
---@field stack string
Marks = {}
Marks.__index = Marks

--- Creates a new instance of Marks
---@param stack string
---@param marks Beez.codemarks.markdata[]
---@return Beez.codemarks.marks
function Marks:new(stack, marks)
  local c = {}
  setmetatable(c, Marks)
  c.marks = {}
  c.keys = {}
  c.archive = {}
  c.history = {}
  c.stack = stack
  for _, m in ipairs(marks) do
    local mark = Mark:new(stack, m)
    table.insert(c.marks, mark)
    c.keys[mark:key()] = true
  end
  return c
end

--- Filter marks based on options
---@param opts? {file: string?}
---@return Beez.codemarks.mark[]
function Marks:list(opts)
  opts = opts or {}
  local marks = {}
  for _, mark in ipairs(self.marks) do
    if opts.file then
      if mark.file == opts.file then
        table.insert(marks, mark)
      end
    else
      table.insert(marks, mark)
    end
  end
  return marks
end

--- Add mark on current line
--- @param opts? {history?: boolean}
function Marks:add(opts)
  opts = opts or {}
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  ---@type Beez.codemarks.markdata
  local data = {
    file = file_path,
    lineno = pos[1],
    col = pos[2],
  }

  local mark = Mark:new(self.stack, data)
  local key = mark:key()
  if self.keys[key] then
    vim.notify("Mark already exists at this location", vim.log.levels.WARN)
    return
  end

  if opts.history then
    table.insert(self.history, mark)
  else
    table.insert(self.marks, mark)
    self.keys[key] = true
    vim.notify("Created mark at: " .. mark.lineno, vim.log.levels.INFO)
  end
end

--- Delete a mark
---@param data Beez.codemarks.markdata
function Marks:del(data)
  local key = Mark.key_from_data(data)
  if self.marks[key] then
    self.marks[key] = nil
    self:save({
      cb = function()
        vim.notify("Mark deleted...", vim.log.levels.INFO)
      end,
    })
  end
end

--- Serialize the marks to a table
---@return Beez.codemarks.markdata[]
function Marks:serialize()
  local marks = {}
  for _, mark in pairs(self.marks) do
    table.insert(marks, mark:serialize())
  end
  return marks
end

--- Removes and returns the last mark
---@return Beez.codemarks.mark?
function Marks:pop()
  if #self.marks == 0 then
    vim.notify("No marks to pop", vim.log.levels.WARN)
    return
  end
  local mark = table.remove(self.marks)
  local key = mark:key()
  self.keys[key] = nil
  self:add({ history = true })
  table.insert(self.archive, mark)
  return mark
end

--- Undo the last pop operation
function Marks:undo()
  local archived_mark = table.remove(self.archive)
  local prev_mark = table.remove(self.history)
  if archived_mark == nil then
    return
  end

  local key = archived_mark:key()
  table.insert(self.marks, archived_mark)
  self.keys[key] = archived_mark
  return prev_mark
end

--- Clears all marks
function Marks:clear()
  self.marks = {}
  self.keys = {}
end

return Marks
