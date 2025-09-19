local c = require("Beez.codestacks.config")

---@class Beez.codestacks.GlobalMark
---@field path string
---@field desc string
---@field line string
---@field lineno integer
---@field stack string

---@class Beez.codestacks.LocalMark
---@field path string
---@field lineno integer
---@field line string

---@class Beez.codestacks.Marks
---@field global_marks table<string, Beez.codestacks.GlobalMark>
---@field local_marks Beez.codestacks.LocalMark[]
Marks = {}
Marks.__index = Marks

--- Creates a new instance of Marks
---@param global_marks table<string, Beez.codestacks.GlobalMark>
---@param local_marks Beez.codestacks.LocalMark[]
---@return Beez.codestacks.Marks
function Marks:new(global_marks, local_marks)
  local m = {}
  setmetatable(m, Marks)

  m.global_marks = global_marks
  m.local_marks = local_marks
  return m
end


--- Filter marks based on options
---@param opts? {}
---@return Beez.codestacks.GlobalMark[]
function Marks:list_global(opts)
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
function Marks:add(desc)
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local root = c.config.get_root()
  ---@type Beez.codestacks.gmarkdata
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
---@param data Beez.codestacks.gmarkdata
---@param updates {desc?: string, lineno?: integer, line?: string}
---@return boolean
function Marks:update(data, updates)
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
---@param data Beez.codestacks.gmarkdata
function Marks:del(data)
  local gmark = self:get(data)
  if gmark == nil then
    return
  end
  local key = gmark:key()
  self.marks[key] = nil
end

--- Serialize the marks to a data table
--- @return Beez.codestacks.gmarkdata[]
function Marks:serialize()
  local data = {}
  for _, mark in pairs(self.marks) do
    table.insert(data, mark:serialize())
  end
  return data
end

return Marks
