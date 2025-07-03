---@class Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer

---@class Beez.codemarks.mark: Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer
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
  return c
end

--- Serialize the mark
---@return Beez.codemarks.markdata
function Mark:serialize()
  local data = {
    file = self.file,
    lineno = self.lineno,
    col = self.col,
  }
  return data
end

return Mark
