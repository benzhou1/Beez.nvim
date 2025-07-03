local u = require("Beez.u")
local uv = vim.uv
local Gmark = require("Beez.codemarks.gmark")

--- Unique key for the global mark
---@param data Beez.codemarks.gmarkdata
---@return string
local function get_key(data)
  return data.file .. ":" .. data.lineno
end

---@class Beez.codemarks.gmarks
---@field marks Beez.codemarks.gmark[]
---@field keys table<string, boolean>
---@field file_to_marks table<string, Beez.codemarks.gmark[]>
Gmarks = {}
Gmarks.__index = Gmarks

---@class codemarks.gmarks.opts
---@field marks_file string

--- Creates a new instance of Marks
---@param data Beez.codemarks.gmarkdata[]
---@return Beez.codemarks.gmarks
function Gmarks:new(data)
  local c = {}
  setmetatable(c, Gmarks)
  -- load marks file
  c.marks = {}
  c.keys = {}
  c.file_to_marks = {}
  for _, d in ipairs(data) do
    local mark = Gmark:new(d)
    table.insert(c.marks, mark)
    local key = get_key(d)
    c.keys[key] = true
    c.file_to_marks[d.file] = c.file_to_marks[d.file] or {}
    table.insert(c.file_to_marks[d.file], mark)
  end
  return c
end

--- Filter marks based on options
---@param opts? {file?: string}
---@return Beez.codemarks.gmark[]
function Gmarks:list(opts)
  opts = opts or {}
  local gmarks = {}
  if opts.file then
    local marks = self.file_to_marks[opts.file]
    return marks or {}
  end
  for _, gmark in pairs(self.marks) do
    table.insert(gmarks, gmark)
  end
  return gmarks
end

--- Add a global mark
---@param desc string Describe the mark
function Gmarks:add(desc)
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  ---@type Beez.codemarks.gmarkdata
  local data = {
    desc = desc,
    file = file_path,
    lineno = pos[1],
    line = line,
  }
  local mark = Gmark:new(data)
  local key = get_key(data)
  if self.keys[key] then
    vim.notify("Mark already exists...", vim.log.levels.WARN)
    return
  end

  table.insert(self.marks, mark)
  self.keys[key] = true
  self.file_to_marks[data.file] = self.file_to_marks[data.file] or {}
  table.insert(self.file_to_marks[data.file], mark)
  vim.notify("Added mark: " .. desc, vim.log.levels.INFO)
end

--- Updates the data of a mark
---@param data Beez.codemarks.gmarkdata
---@param updates {desc: string?}
---@param cb function?
function Gmarks:update(data, updates)
  local mark = self:get(data)
  local updated = false
  if mark ~= nil then
    if updates.desc ~= nil then
      mark:update_desc(updates.desc)
      updated = true
    end
    if updated then
      self:save({
        cb = function()
          vim.notify("Updated mark...", vim.log.levels.INFO)
          if cb ~= nil then
            cb()
          end
        end,
      })
    end
  end
end

--- Delete a mark
---@param data Beez.codemarks.gmarkdata
function Gmarks:del(data)
  local key = get_key(data)
  if self.marks[key] then
    self.marks[key] = nil
    self:save({
      cb = function()
        vim.notify("Mark deleted...", vim.log.levels.INFO)
      end,
    })
  end
end

--- Serialize the marks to a data table
--- @return Beez.codemarks.gmarkdata[]
function Gmarks:serialize()
  local data = {}
  for _, mark in pairs(self.marks) do
    table.insert(data, mark:serialize())
  end
  return data
end

return Gmarks
