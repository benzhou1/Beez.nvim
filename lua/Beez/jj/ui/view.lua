---@class Beez.jj.ui.JJView
---@field sttree Beez.jj.ui.JJStatusTree
---@field logtree Beez.jj.ui.JJLogTree
---@field diff Beez.jj.ui.VscodeDiff
JJView = {}
JJView.__index = JJView

--- Instaintiates a new JJView
---@return Beez.jj.ui.JJView
function JJView.new()
  local JJStatusTree = require("Beez.jj.ui.status_tree")
  local JJLogTree = require("Beez.jj.ui.log_tree")
  local j = {}
  setmetatable(j, JJView)

  j.new_tab = true
  j.sttree = JJStatusTree.new()
  j.logtree = JJLogTree.new()
  return j
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Show unified diff for specified file path
---@param filepath string
---@param cb? fun()
function JJView:show_diff(filepath, cb)
  self.diff:render(filepath, function()
    self.sttree:focus()
    local tree_width = 60
    self.sttree:resize(tree_width)
    self.diff:resize(tree_width)
    if cb ~= nil then
      cb()
    end
  end)
end

--- Move to a file in the status tree and diff
---@param offset integer
---@param cb? fun()
function JJView:status_move_to_file(offset, cb)
  if not self.sttree:is_focused() then
    return
  end

  local ok = self.sttree:move_to_file(offset)
  if not ok then
    return
  end

  local filepath = self.sttree:get_filepath()
  if filepath == nil then
    return
  end
  self:show_diff(filepath, cb)
end

--- Focus the diff view
function JJView:focus_diff()
  self.diff:focus()
end

--- Focus the status sttree
function JJView:focus_tree()
  self.sttree:focus()
end

--- Scroll the diffview by specified number of lines
---@param lines integer
function JJView:scroll_diff(lines)
  self.diff:scroll(lines)
end

--- Cleanup and quits the view
function JJView:quit()
  if self.diff ~= nil then
    self.diff:cleanup()
  end
  self.logtree:cleanup()
  self.logtree:close()
end

--- Refresh the log view
---@param opts? table
function JJView:refresh(opts)
  opts = opts or {}
  self.logtree:render(function()
    self.logtree:map(self)
    self.logtree:focus()
    if opts.cb ~= nil then
      opts.cb()
    end
  end)
end

--- Renders jj view
function JJView:render(opts)
  opts = opts or {}

  -- Layout for log view
  if not self.logtree:is_opened() then
    vim.cmd("belowright split | enew")
  end
  self:refresh(opts)

  -- Render status tree
  -- self.sttree:render(function()
  --   self.sttree:map(self)
  --   vim.cmd("split")
  --   -- Then render log tree
  --   self.logtree:render(function()
  --     self.logtree:map(self)
  --     self.sttree:focus()
  --     -- Then diff the first file
  --     self:status_move_to_file(1, function()
  --       -- Map keybinds to diff view only once
  --       self.diff:map(self)
  --       self.sttree:focus()
  --     end)
  --   end)
  -- end)
end

return JJView
