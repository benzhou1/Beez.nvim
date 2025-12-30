---@class Beez.jj.ui.JJView
---@field tree Beez.jj.ui.JJStatusTree
---@field udiff Beez.jj.ui.UnifiedDiff
JJView = {}
JJView.__index = JJView

--- Instaintiates a new JJView
---@return Beez.jj.ui.JJView
function JJView:new()
  local UnifiedDiff = require("Beez.jj.ui.unified_diff")
  local JJStatusTree = require("Beez.jj.ui.status_tree")
  local j = {}
  setmetatable(j, JJView)

  j.tree = JJStatusTree.new()
  j.udiff = UnifiedDiff.new()
  return j
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Show unified diff for specified file path
---@param filepath string
---@param cb? fun()
function JJView:show_unified_diff(filepath, cb)
  self.udiff:render(filepath, function()
    if cb ~= nil then
      cb()
    end
  end)
end

--- Move to a file in the status tree and diff
---@param offset integer
---@param cb? fun()
function JJView:status_move_to_file(offset, cb)
  if not self.tree:is_focused() then
    return
  end

  local ok = self.tree:move_to_file(offset)
  if not ok then
    return
  end

  local filepath = self.tree:get_filepath()
  if filepath == nil then
    return
  end
  self:show_unified_diff(filepath, cb)
end

--- Focus the diff view
function JJView:focus_diff()
  self.udiff:focus()
end

--- Focus the status tree
function JJView:focus_tree()
  self.tree:focus()
end

--- Scroll the diffview by specified number of lines
---@param lines integer
function JJView:scroll_diff(lines)
  self.udiff:scroll(lines)
end

--- Renders jj view
function JJView:render()
  -- Create layout
  vim.cmd("tabnew")
  -- Render status tree
  self.tree:render(function()
    self.tree:map(self)
    -- Then diff the first file
    self:status_move_to_file(1, function()
      self.tree:focus()
      -- Map keybinds to diff view only once
      self.udiff:map(self)
    end)
  end)
end

return JJView
