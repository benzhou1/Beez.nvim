---@class Beez.dbfp.query
---@field paragraph string[]
---@field comment string
---@field query string
Query = {}
Query.__index = Query

--- Instantiates a new Query object
---@param paragraph string[]
---@return Beez.dbfp.query
function Query:new(paragraph)
  local q = {}
  setmetatable(q, Query)

  q.paragraph = paragraph
  q.comment = ""
  q.query = ""

  q:deserialize()
  return q
end

--- Parses queries from a paragraph
function Query:deserialize()
  ---@diagnostic disable-next-line: param-type-mismatch
  if self.paragraph[1]:startswith("-- ") then
    ---@diagnostic disable-next-line: undefined-field
    self.comment = self.paragraph[1]:sub(4):trimr()
  else
    ---@diagnostic disable-next-line: undefined-field
    self.comment = self.paragraph[1]:trimr()
  end
  self.query = table.concat(self.paragraph, "\n", 2)
end

--- Returns a table of lines representing the query
---@return string[]
function Query:serialize()
  local lines = {}
  if self.comment ~= "" then
    table.insert(lines, "-- " .. self.comment)
  end
  for _, line in ipairs(self.paragraph) do
    table.insert(lines, line)
  end
  return lines
end

return Query
