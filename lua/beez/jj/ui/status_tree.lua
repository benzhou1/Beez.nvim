---@class Beez.jj.ui.JJStatusTree
---@field buf number
---@field tree NuiTree
---@field root? string
JJStatusTree = {}
JJStatusTree.__index = JJStatusTree

--- Instantiates a new JJStatusTree
---@return Beez.jj.ui.JJStatusTree
function JJStatusTree.new()
  local t = {}
  local NuiTree = require("nui.tree")
  setmetatable(t, JJStatusTree)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].buftype = 'nofile'

  t.root = nil
  t.buf = buf
  t.tree = NuiTree({
    bufnr = buf,
    nodes = {},
    get_node_id = function(node)
      return node.data.rel_path or node.text
    end,
    prepare_node = function(node)
      local NuiLine = require("nui.line")
      local line = NuiLine()
      if node.data.status == nil then
        line:append(node.text, "String")
        return line
      end

      local s, shl, thl = "", "String", "String"
      if node.data.status == "M" then
        s, shl, thl = "M", "String", "String"
      elseif node.data.status == "A" then
        s, shl, thl = "A", "Added", "Added"
      elseif node.data.status == "D" then
        s, shl, thl = "D", "Search", "Search"
      elseif node.data.status == "R" then
        s, shl, thl = "R", "Search", "Search"
      elseif node.data.status == "C" then
        s, shl, thl = "C", "Search", "Search"
      end

      line:append(s, shl)
      line:append(" " .. node.data.rel_path, thl)
      return line
    end,
  })

  return t
end

-----------------------------------------------------------------------------------------------
--- STATE
-----------------------------------------------------------------------------------------------
--- Gets a tree node based on line number
---@param lineno? integer
---@return NuiTree.Node?
function JJStatusTree:get(lineno)
  lineno = lineno or vim.api.nvim_win_get_cursor(self.winid)[1]
  return self.tree:get_node(lineno)
end

--- Get the file path at specified line
---@param lineno? integer
---@return string?
function JJStatusTree:get_filepath(lineno)
  lineno = lineno or vim.api.nvim_win_get_cursor(self.winid)[1]
  local node = self:get(lineno)
  if node == nil then
    return
  end

  local filepath = vim.fs.joinpath(self.root, node.data.rel_path)
  return filepath
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Focus the tree
function JJStatusTree:focus()
  vim.api.nvim_set_current_win(self.winid)
end

--- Checks whether the tree is focused
---@return boolean
function JJStatusTree:is_focused()
  local curr_buf = vim.api.nvim_get_current_buf()
  local is_focused = curr_buf == self.buf
  return is_focused
end

--- Sets the tree window width
---@param width integer
function JJStatusTree:resize(width)
  vim.api.nvim_win_set_width(self.winid, width)
end

--- Move cursor to a file based on offset
---@param offset integer
---@return boolean
function JJStatusTree:move_to_file(offset)
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] + offset
  local node = self:get(lineno)
  if node == nil then
    while lineno > 1 and lineno < #self.tree.nodes do
      lineno = lineno + offset
      node = self:get(lineno)
      if node ~= nil then
        break
      end
    end
  end

  if node ~= nil then
    vim.api.nvim_win_set_cursor(self.winid, { lineno, 0 })
    return node.data.rel_path ~= nil
  end
  return false
end

--- Renders a tree based on jj status
---@param cb? fun()
function JJStatusTree:render(cb)
  local NuiTree = require("nui.tree")
  local commands = require("beez.jj.commands")

  -- Cache git root until next render
  local git_root = vim.fs.find(".git", { upward = true })[1]
  self.root = vim.fs.dirname(git_root)

  commands.st(function(err, status_lines)
    if err then
      vim.notify("Failed to render jj status tree", vim.log.levels.WARN)
      return
    end

    local lines = vim.split(status_lines, "\n")
    local nodes = {}
    for _, line in ipairs(lines) do
      local status, rel_path = line:match("^(%S)%s+(.+)$")
      if rel_path then
        -- Handle rename {old => new} pattern
        rel_path = rel_path:gsub("{([^}]+)}", function(brace_content)
          local _, after = brace_content:match("(.+)%s*=>%s*(.+)")
          if after then
            return after
          else
            return brace_content
          end
        end)
      end

      local node
      if status ~= nil then
        node = NuiTree.Node({ text = rel_path, data = { status = status, rel_path = rel_path } })
      else
        node = NuiTree.Node({ text = line, data = {} })
      end
      table.insert(nodes, node)
    end

    vim.schedule(function()
      self.tree:set_nodes(nodes)
      self.tree:render()
      self.winid = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_buf(self.buf)
      vim.wo[self.winid].number = false
      vim.wo[self.winid].relativenumber = false
      if cb then
        cb()
      end
    end)
  end)
end

--- Maps default keybinds to tree buffer
---@param view Beez.jj.ui.JJView
function JJStatusTree:map(view)
  local u = require("beez.u")
  local buffer = self.buf
  local keymaps = {
    quit = {
      "q",
      function()
        view:quit()
      end,
      desc = "Close view",
    },
    focus_diff = {
      "<cr>",
      function()
        view:focus_diff()
      end,
      desc = "Focus the diff view",
    },
    next_file = {
      "k",
      function()
        view:status_move_to_file(1)
      end,
      desc = "Move to the next file and diff",
    },
    prev_file = {
      "j",
      function()
        view:status_move_to_file(-1)
      end,
      desc = "Move to the previous file and diff",
    },
    scroll_diff_down = {
      "K",
      function()
        view:scroll_diff(20)
      end,
      desc = "Scroll diff view down",
    },
    scroll_diff_up = {
      "J",
      function()
        view:scroll_diff(-20)
      end,
      desc = "Scroll diff view up",
    },
  }

  for _, k in pairs(keymaps) do
    local keymap = vim.tbl_deep_extend("keep", { buffer = buffer }, k)
    u.keymaps.set({ keymap })
  end
end

return JJStatusTree
