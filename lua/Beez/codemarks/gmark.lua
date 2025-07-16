---@class Beez.codemarks.gmarkdata
---@field desc string
---@field file string
---@field lineno integer
---@field line string

---@class Beez.codemarks.gmarkdataout : Beez.codemarks.gmarkdata
---@field stack string

---@class Beez.codemarks.gmark: Beez.codemarks.gmarkdata
---@field line string
---@field desc string
---@field file string
---@field lineno integer
---@field stack string
local Gmark = {}
Gmark.__index = Gmark

--- Create a Mark object
---@param stack string
---@param data Beez.codemarks.gmarkdata
---@return Beez.codemarks.gmark
function Gmark:new(stack, data)
  local c = {}
  setmetatable(c, Gmark)
  c.desc = data.desc
  c.file = data.file
  c.lineno = data.lineno
  c.line = data.line
  c.stack = stack
  return c
end

--- Returns a unique key for the mark
---@return string
function Gmark:key()
  return self.file .. ":" .. self.lineno
end

--- Returns a unique key for the mark from data
---@param data Beez.codemarks.gmarkdataout
---@return string
function Gmark.key_from_data(data)
  return data.file .. ":" .. data.lineno
end

--- Serialize the mark
---@return Beez.codemarks.gmarkdataout
function Gmark:serialize()
  local data = {
    desc = self.desc,
    file = self.file,
    lineno = self.lineno,
    line = self.line,
    stack = self.stack,
  }
  return data
end

--- Updates the marks data
---@param updates {desc?: string, lineno?: integer}
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
  return updated
end

return Gmark
