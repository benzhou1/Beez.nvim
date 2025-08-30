---@class Beez.codemarks.markdata
---@field file string
---@field lineno integer
---@field col integer
---@field line string

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
  c.line = data.line
  return c
end

--- Update the mark
---@param updates {lineno?: integer}
function Mark:update(updates)
  if updates.lineno then
    self.lineno = updates.lineno
  end
end

--- Returns a unique key for the mark
---@return string
function Mark:key()
  local data = self:serialize()
  return Mark.key_from_data(data.file, data.lineno)
end

--- Returns a unique key for the mark from data
---@param path string
---@param lineno integer
---@return string
function Mark.key_from_data(path, lineno)
  return path .. ":" .. lineno
end

--- Serialize the mark
---@return Beez.codemarks.markdata
function Mark:serialize()
  local data = {
    file = self.file,
    lineno = self.lineno,
    col = self.col,
    line = self.line,
  }
  return data
end

return Mark
