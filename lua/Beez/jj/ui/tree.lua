---@class Beez.jj.Tree
---@field left_dir string
---@field right_dir string
---@field output_dir string
---@field buf integer
---@field winid integer
---@field tree NuiTree
---@field title string
Tree = {}
Tree.__index = Tree

--- Instantiates a new Tree
---@param left_dir string
---@param right_dir string
---@param output_dir string
---@return Beez.jj.Tree
function Tree:new(title, left_dir, right_dir, output_dir)
  local NuiTree = require("nui.tree")
  local t = {}
  setmetatable(t, Tree)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false

  t.title = title
  t.buf = buf
  t.winid = nil
  t.left_dir = left_dir
  t.right_dir = right_dir
  t.output_dir = output_dir
  t.tree = NuiTree({
    bufnr = buf,
    nodes = {},
    get_node_id = function(node)
      return node.data.rel_path
    end,
  })
  return t
end

function Tree:_get_node(lineno)
  lineno = lineno or vim.api.nvim_win_get_cursor(self.winid)[1]
  local node = self.tree:get_node(lineno)
  if node == nil then
    vim.notify("Could not find tree node at: " .. lineno, vim.log.levels.WARN)
    return
  end
  return node
end

function Tree:render(nodes, cb)
  local NuiLine = require("nui.line")
  local header = NuiLine()
  header:append(self.title, "Search")

  self.tree:set_nodes(nodes)
  self.tree:render(2)
  self.winid = vim.api.nvim_get_current_win()

  vim.schedule(function()
    vim.api.nvim_set_current_buf(self.tree.bufnr)
    -- This is so messed up... you have to set modifiable to true first
    -- and current buffer has to be opened first... while tree:render has no issues...
    vim.bo[self.buf].modifiable = true
    vim.bo[self.buf].readonly = false
    header:render(self.buf, 1, 1)

    -- Set cursor to second line because first line is the header
    pcall(vim.api.nvim_win_set_cursor, self.winid, { 2, 0 })

    vim.bo[self.tree.bufnr].filetype = "Beezjjtree"
    -- Remove line numbers
    vim.wo[self.winid].number = false
    -- Read only
    vim.bo[self.tree.bufnr].modifiable = false

    cb()
  end)
end

-----------------------------------------------------------------------------------------------
--- STATE
-----------------------------------------------------------------------------------------------
function Tree:get(rel_path)
  return self.tree:get_node(rel_path)
end

function Tree:is_focused()
  return vim.api.nvim_get_current_win() == self.winid
end

function Tree:get_selected_path()
  local node = self:_get_node()
  if node == nil then
    return
  end
  return node.data.rel_path
end

function Tree:select_path(rel_path)
  local line_count = vim.api.nvim_buf_line_count(self.buf)
  for i = 1, line_count do
    local node = self.tree:get_node(i)
    if node ~= nil and node.data.rel_path == rel_path then
      vim.api.nvim_win_set_cursor(self.winid, { i, 0 })
      return
    end
  end
end

function Tree:add_node(node, sort)
  local existing_node = self.tree:get_node(node.data.rel_path)
  if existing_node ~= nil then
    return
  end

  local nodes = self.tree:get_nodes()
  table.insert(nodes, node)
  if sort ~= nil then
    nodes = sort(nodes, sort)
  end
  self.tree:set_nodes(nodes)

  local curr_node = self.tree:get_node(vim.api.nvim_win_get_cursor(self.winid)[1])
  self.tree:render(2)
  -- Set the cursor back to the previously selected node
  if curr_node ~= nil then
    for i, n in ipairs(nodes) do
      if n.data.rel_path == curr_node.data.rel_path then
        vim.api.nvim_win_set_cursor(self.winid, { i + 1, 0 })
        return
      end
    end
  end
end

function Tree:remove_node(rel_path)
  local existing_node = self.tree:get_node(rel_path)
  if existing_node == nil then
    return
  end

  self.tree:remove_node(rel_path)
  self.tree:render(2)
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
function Tree:focus()
  vim.api.nvim_set_current_win(self.winid)
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  if pos[1] == 1 then
    pcall(vim.api.nvim_win_set_cursor, self.winid, { 2, pos[2] })
  end
end

function Tree:next()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] + 1
  local last_line = vim.api.nvim_buf_line_count(self.buf)
  if pos[1] == last_line then
    return false
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  return true
end

function Tree:prev()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] - 1
  if pos[1] == 2 then
    return false
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  return true
end

function Tree:hide_cursor_line()
  vim.api.nvim_set_option_value("cursorline", false, { scope = "local", win = self.winid })
end

function Tree:show_cursor_line()
  vim.api.nvim_set_option_value("cursorline", true, { scope = "local", win = self.winid })
end

function Tree:resize(width)
  vim.api.nvim_win_set_width(self.winid, width)
end

return Tree
