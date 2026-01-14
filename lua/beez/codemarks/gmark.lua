---@class Beez.codemarks.gmarkdata
---@field desc string
---@field file string
---@field lineno integer
---@field line string
---@field root string

---@class Beez.codemarks.gmark: Beez.codemarks.gmarkdata
local Gmark = {}
Gmark.__index = Gmark

--- Create a Mark object
---@param data Beez.codemarks.gmarkdata
---@return Beez.codemarks.gmark
function Gmark:new(data)
  local c = {}
  setmetatable(c, Gmark)
  c.desc = data.desc
  c.file = data.file
  c.lineno = data.lineno
  c.line = data.line
  c.root = data.root
  return c
end

--- Returns a unique key for the mark
---@return string
function Gmark:key()
  return Gmark.key_from_data(self:serialize())
end

--- Returns a unique key for the mark from data
---@param data Beez.codemarks.gmarkdata
---@return string
function Gmark.key_from_data(data)
  return data.root .. ":" .. data.file .. ":" .. data.lineno
end

--- Serialize the mark
---@return Beez.codemarks.gmarkdata
function Gmark:serialize()
  local data = {
    desc = self.desc,
    file = self.file,
    lineno = self.lineno,
    line = self.line,
    root = self.root,
  }
  return data
end

--- Updates the marks data
---@param updates {desc?: string, lineno?: integer, line?: string}
---@return boolean
function Gmark:update(updates)
  local updated = false
  if updates.desc ~= nil then
    self.desc = updates.desc
    updated = true
  end
  if updates.lineno ~= nil then
    self.lineno = updates.lineno
    updated = true
  end
  if updates.line ~= nil then
    self.line = updates.line
    updated = true
  end
  return updated
end

return Gmark
