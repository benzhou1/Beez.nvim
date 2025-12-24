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
  t.title = title
  t.buf = buf
  t.winid = nil
  t.left_dir = left_dir
  t.right_dir = right_dir
  t.output_dir = output_dir
  t.tree = NuiTree({
    bufnr = buf,
    nodes = {},
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

function Tree:_get_tree_nodes(dir_path)
  local u = require("Beez.u")
  local NuiTree = require("nui.tree")
  local nodes = {}

  for root, _, files in u.os.walk(dir_path) do
    for _, f in ipairs(files) do
      local path = vim.fs.joinpath(root, f)
      local rel_path = vim.fs.relpath(dir_path, path)
      nodes[rel_path] = NuiTree.Node({
        text = rel_path,
        data = { path = path, selected = false, rel_path = rel_path },
      })
    end
  end

  table.sort(nodes, function(a, b)
    return a.text < b.text
  end)
  return nodes
end

function Tree:render(cb)
  local nodes = {}
  local left_nodes = self:_get_tree_nodes(self.left_dir)
  local right_nodes = self:_get_tree_nodes(self.right_dir)
  for path, n in pairs(left_nodes) do
    table.insert(nodes, n)
    -- If a path does not exist in the right that means it has been deleted
    if not right_nodes[path] then
      n.data.status = "deleted"
    end
  end
  for path, n in pairs(right_nodes) do
    -- If a path does not exist in the left that means it has been added
    if not left_nodes[path] and path ~= "JJ-INSTRUCTIONS" then
      table.insert(nodes, n)
      n.data.status = "added"
    end
  end
  table.sort(nodes, function(a, b)
    return a.text < b.text
  end)

  local ns_id = vim.api.nvim_create_namespace("my_virtual_text")

  self.tree:set_nodes(nodes)
  self.tree:render(2)
  self.winid = vim.api.nvim_get_current_win()
  vim.schedule(function()
    vim.api.nvim_buf_set_extmark(self.tree.bufnr, ns_id, 1, 0, {
      virt_lines = { { { self.title, "Search" } } },
      virt_lines_above = true,
    })
    vim.api.nvim_set_current_buf(self.tree.bufnr)
    vim.api.nvim_win_set_cursor(self.winid, { 2, 0 })

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

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
function Tree:focus()
  vim.api.nvim_set_current_win(self.winid)
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
