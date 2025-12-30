
---@class Changes
---@field changes Change[]
Changes = {}
Changes.__index = Changes

function Changes:new()
  local c = {}
  setmetatable(c, Changes)

  c.changes = {}
  return c
end

function Changes:_add(change, line_num, from, to, hunk)
  self.changes[line_num] = {
    change = change,
    to = to,
    from = from,
    curr = line_num,
    hunk = hunk,
  }

  -- Update the line numbers of subsequent changes
  local new_changes = {}
  for _, c in pairs(self.changes) do
    if c.curr > line_num and change ~= "D" then
      c.curr = c.curr + 1
    end
    new_changes[c.curr] = c
  end
  self.changes = new_changes
end

function Changes:list(opts)
  opts = opts or {}
  local changes = {}

  for _, c in pairs(self.changes) do
    if opts.hunk ~= nil then
      if opts.hunk == c.hunk then
        table.insert(changes, c)
      end
    else
      table.insert(changes, c)
    end
  end
  return changes
end

function Changes:get(line_num)
  local change = self.changes[line_num]
  return change
end

function Changes:remove(change)
  self.changes[change.curr] = nil
  if change.change == "D" then
    return
  end

  -- Update the line numbers of subsequent changes
  local new_changes = {}
  for _, c in pairs(self.changes) do
    if c.curr > change.curr then
      c.curr = c.curr - 1
    end
    new_changes[c.curr] = c
  end
  self.changes = new_changes
end

function Changes:add(line_num, from, to, hunk)
  self:_add("A", line_num, from, to, hunk)
end

function Changes:del(line_num, from, to, hunk)
  self:_add("D", line_num, from, to, hunk)
end

return Changes
