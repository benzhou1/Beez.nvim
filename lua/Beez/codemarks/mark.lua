---@class Beez.codemarks.markdata
---@field file string
---@field lineno integer

---@class Beez.codemarks.mark: Beez.codemarks.markdata
---@field data Beez.codemarks.markdata
local Mark = {}
Mark.__index = Mark

--- Create a Mark object
---@param data Beez.codemarks.markdata
---@return Beez.codemarks.mark
function Mark:new(data)
  local c = {}
  setmetatable(c, Mark)
  c.data = data
  c.file = c.data.file
  c.lineno = c.data.lineno
  return c
end

--- Create a Mark object from a line
---@param line string
---@return Beez.codemarks.mark
function Mark.from_line(line)
  ---@type Beez.codemarks.markdata
  local data = vim.fn.json_decode(line)
  return Mark:new(data)
end

--- Serialize the mark
---@return string
function Mark:serialize()
  local line = vim.fn.json_encode(self.data)
  return line
end

return Mark
