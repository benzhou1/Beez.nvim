---@class Beez.codemarks.gmarkdata
---@field desc string
---@field file string
---@field lineno integer
---@field line string

---@class Beez.codemarks.gmark: Beez.codemarks.gmarkdata
---@field line string
---@field desc string
---@field file string
---@field lineno integer
---@field stack string
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
  c.stack = ""
  return c
end

--- Serialize the mark
---@return Beez.codemarks.gmarkdata
function Gmark:serialize()
  local data = {
    desc = self.desc,
    file = self.file,
    lineno = self.lineno,
    line = self.line,
  }
  return data
end

--- Updates the mark's description
---@param desc string
function Gmark:set_desc(desc)
  self.desc = desc
end

--- Updates the mark's line number
---@param lineno integer
function Gmark:set_lineno(lineno)
  self.lineno = lineno
end

return Gmark
