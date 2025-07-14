local Gmarks = require("Beez.codemarks.gmarks")
local Marks = require("Beez.codemarks.marks")

---@class Beez.codemarks.stack
---@field name string
---@field root string
---@field gmarks Beez.codemarks.gmarks
---@field marks Beez.codemarks.marks
Stack = {}
Stack.__index = Stack

---@class Beez.codemarks.stackdata
---@field stack string
---@field root string
---@field gmarks Beez.codemarks.gmarkdata[]
---@field marks Beez.codemarks.markdata[]

--- Creates a new Stack object
--- @param data Beez.codemarks.stackdata
---@return Beez.codemarks.stack
function Stack:new(data)
  local s = {}
  setmetatable(s, Stack)

  s.name = data.stack
  s.root = data.root
  s.gmarks = Gmarks:new(data.stack, data.gmarks)
  s.marks = Marks:new(data.stack, data.marks)

  return s
end

--- Updates the stack
---@param updates {name?: string}
---@return boolean
function Stack:update(updates)
  local updated = false
  if updates.name ~= nil and updates.name ~= self.name then
    self.name = updates.name
    updated = true
  end
  return updated
end

--- Serialize the stack into a stack data table
---@return Beez.codemarks.stackdata
function Stack:serialize()
  local data = {
    stack = self.name,
    root = self.root,
    gmarks = self.gmarks:serialize(),
    marks = self.marks:serialize(),
  }
  return data
end

--- Removes the last mark from the list
---@return Beez.codemarks.markdata?
function Stack:pop()
  local mark = self.marks:pop()
  return mark
end

return Stack
