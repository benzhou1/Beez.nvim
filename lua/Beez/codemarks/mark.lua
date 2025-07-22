---@class Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer
---@field root string

---@class Beez.codemarks.mark: Beez.codemarks.markdata
local Mark = {}
Mark.__index = Mark

--- Create a Mark object
---@param data Beez.codemarks.markdata
---@return Beez.codemarks.mark
function Mark:new(data)
  local c = {}
  setmetatable(c, Mark)
  c.file = data.file
  c.lineno = data.lineno
  c.col = data.col
  c.root = data.root
  return c
end

--- Returns a unique key for the mark
---@return string
function Mark:key()
  return Mark.key_from_data(self:serialize())
end

--- Returns a unique key for the mark from data
---@param data Beez.codemarks.markdata
---@return string
function Mark.key_from_data(data)
  return data.root .. ":" .. data.file .. ":" .. data.lineno
end

--- Serialize the mark
---@return Beez.codemarks.markdata
function Mark:serialize()
  local data = {
    file = self.file,
    lineno = self.lineno,
    col = self.col,
    root = self.root,
  }
  return data
end

return Mark
