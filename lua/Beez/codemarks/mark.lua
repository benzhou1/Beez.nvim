---@class Beez.codemarks.markdata
---@field desc string
---@field file string
---@field lineno integer
---@field root string
---@field line string

---@class Beez.codemarks.mark: Beez.codemarks.markdata
---@field line string
---@field desc string
---@field file string
---@field lineno integer
---@field root string
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
  c.desc = c.data.desc
  c.file = c.data.file
  c.lineno = c.data.lineno
  c.root = c.data.root
  c.line = c.data.line
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

--- Deserialize the mark
---@return Beez.codemarks.markdata
function Mark:deserialize()
  ---@diagnostic disable-next-line: return-type-mismatch
  return load(self.line)
end

--- Updates the mark's description
---@param desc string
function Mark:update_desc(desc)
  self.desc = desc
  self.data.desc = desc
end

--- Updates the mark's line number
---@param lineno integer
function Mark:update_lineno(lineno)
  self.lineno = lineno
  self.data.lineno = lineno
end

return Mark
