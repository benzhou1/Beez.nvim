---@class Beez.codemarks.gmarkdata
---@field desc string
---@field file string
---@field lineno integer
---@field root string
---@field line string

---@class Beez.codemarks.gmark: Beez.codemarks.gmarkdata
---@field line string
---@field desc string
---@field file string
---@field lineno integer
---@field root string
---@field data Beez.codemarks.gmarkdata
local Gmark = {}
Gmark.__index = Gmark

--- Create a Mark object
---@param data Beez.codemarks.gmarkdata
---@return Beez.codemarks.gmark
function Gmark:new(data)
  local c = {}
  setmetatable(c, Gmark)
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
---@return Beez.codemarks.gmark
function Gmark.from_line(line)
  ---@type Beez.codemarks.gmarkdata
  local data = vim.fn.json_decode(line)
  return Gmark:new(data)
end

--- Serialize the mark
---@return string
function Gmark:serialize()
  local line = vim.fn.json_encode(self.data)
  return line
end

--- Updates the mark's description
---@param desc string
function Gmark:update_desc(desc)
  self.desc = desc
  self.data.desc = desc
end

--- Updates the mark's line number
---@param lineno integer
function Gmark:update_lineno(lineno)
  self.lineno = lineno
  self.data.lineno = lineno
end

return Gmark
