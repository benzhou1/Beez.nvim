---@class Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer

---@class Beez.codemarks.markdataout : Beez.codemarks.markdata
---@field stack string

---@class Beez.codemarks.mark: Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer
---@field stack string
local Mark = {}
Mark.__index = Mark

--- Create a Mark object
---@param stack string
---@param data Beez.codemarks.markdata
---@return Beez.codemarks.mark
function Mark:new(stack, data)
  local c = {}
  setmetatable(c, Mark)
  c.file = data.file
  c.lineno = data.lineno
  c.col = data.col
  c.stack = stack
  return c
end

--- Returns a unique key for the mark
---@return string
function Mark:key()
  return self.file .. ":" .. self.lineno
end

--- Returns a unique key for the mark from data
---@param data Beez.codemarks.markdata
---@return string
function Mark.key_from_data(data)
  return data.file .. ":" .. data.lineno
end

--- Serialize the mark
---@return Beez.codemarks.markdataout
function Mark:serialize()
  local data = {
    file = self.file,
    lineno = self.lineno,
    col = self.col,
    stack = self.stack,
  }
  return data
end

return Mark
