local Gmark = require("beez.codemarks.gmark")
local c = require("beez.codemarks.config")

---@class Beez.codemarks.gmarks
---@field marks table<string, Beez.codemarks.gmark>
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
  for _, d in ipairs(data) do
    local mark = Gmark:new(d)
    local key = mark:key()
    c.marks[key] = mark
  end
  return c
end

--- Gets a specific mark by its data
---@param data Beez.codemarks.gmarkdata
---@return Beez.codemarks.gmark?
function Gmarks:get(data)
  local key = Gmark.key_from_data(data)
  return self.marks[key]
end

--- Filter marks based on options
---@param opts? {file?: string, root?: string}
---@return Beez.codemarks.gmark[]
function Gmarks:list(opts)
  opts = opts or {}
  local gmarks = {}
  for _, gmark in pairs(self.marks) do
    if opts.root then
      if gmark.root == opts.root then
        table.insert(gmarks, gmark)
      end
    elseif opts.file then
      if gmark.file == opts.file then
        table.insert(gmarks, gmark)
      end
    else
      table.insert(gmarks, gmark)
    end
  end

  table.sort(gmarks, function(a, b)
    return a.desc < b.desc
  end)
  return gmarks
end

--- Add a global mark
---@param desc string Describe the mark
function Gmarks:add(desc)
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local root = c.config.get_root()
  ---@type Beez.codemarks.gmarkdata
  local data = {
    desc = desc,
    file = file_path,
    lineno = pos[1],
    line = line,
    root = root,
  }
  local mark = Gmark:new(data)
  local key = mark:key()
  if self.marks[key] then
    vim.notify("Mark already exists...", vim.log.levels.WARN)
    return
  end

  self.marks[key] = mark
  vim.notify("Added mark: " .. desc, vim.log.levels.INFO)
end

--- Updates the data of a mark
---@param data Beez.codemarks.gmarkdata
---@param updates {desc?: string, lineno?: integer, line?: string}
---@return boolean
function Gmarks:update(data, updates)
  local updated = false
  local gmark = self:get(data)
  if gmark == nil then
    return false
  end

  local old_key = gmark:key()
  updated = gmark:update(updates)
  local new_key = gmark:key()
  -- lineno is updated, so we need to update the key
  if updates.lineno ~= nil and updated and old_key ~= new_key then
    self.marks[new_key] = gmark
    self.marks[old_key] = nil
  end
  return updated
end

--- Delete a mark
---@param data Beez.codemarks.gmarkdata
function Gmarks:del(data)
  local gmark = self:get(data)
  if gmark == nil then
    return
  end
  local key = gmark:key()
  self.marks[key] = nil
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
