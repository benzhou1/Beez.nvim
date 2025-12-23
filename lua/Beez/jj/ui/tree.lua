---@class Beez.jj.Tree
---@field left_dir string
---@field right_dir string
---@field output_dir string
---@field buf integer
---@field winid integer
---@field tree NuiTree
Tree = {}
Tree.__index = Tree

--- Instantiates a new Tree
---@param left_dir string
---@param right_dir string
---@param output_dir string
---@return Beez.jj.Tree
function Tree:new(left_dir, right_dir, output_dir)
  local NuiTree = require("nui.tree")
  local t = {}
  setmetatable(t, Tree)

  local buf = vim.api.nvim_create_buf(false, true)
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

  self.tree:set_nodes(nodes)
  self.tree:render()
  self.winid = vim.api.nvim_get_current_win()
  vim.schedule(function()
    vim.api.nvim_set_current_buf(self.tree.bufnr)

    vim.bo[self.tree.bufnr].filetype = "Beezjjtree"
    -- Remove line numbers
    vim.wo[self.winid].number = false
    -- Read only
    vim.bo[self.tree.bufnr].modifiable = false

    cb()
  end)
end

function Tree:focus()
  vim.api.nvim_set_current_win(self.winid)
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

function Tree:next()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] + 1
  local last_line = vim.api.nvim_buf_line_count(0)
  if pos[1] == last_line then
    return false
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  return true
end

function Tree:prev()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] - 1
  if pos[1] == 1 then
    return false
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  return true
end

function Tree:resize(width)
  vim.api.nvim_win_set_width(self.winid, width)
end

function Tree:get_selected_path()
  local node = self:_get_node()
  if node == nil then
    return
  end
  return node.data.rel_path
end

function Tree:set_right_keymaps()
  local u = require("Beez.u")
  local lifecycle = require("vscode-diff.render.lifecycle")
  local actions = require("vscode-diff.render.keymaps").actions
  local _, _right_buf = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())

  u.keymaps.set({
    {
      "q",
      function()
        vim.cmd("cq")
      end,
      buffer = _right_buf,
      desc = "Quit and ignore changes",
    },
    {
      "<leader>e",
      function()
        self:focus()
      end,
      buffer = _right_buf,
      desc = "Focus the file tree window",
    },
    {
      "<leader><cr>",
      function()
        vim.cmd("qa")
      end,
      buffer = _right_buf,
      desc = "Quit and apply changes",
    },
    {
      "<tab>",
      function()
        self:next_file()
      end,
      buffer = _right_buf,
      desc = "Move to the next file",
    },
    {
      "<s-tab>",
      function()
        self:prev_file()
      end,
      buffer = _right_buf,
      desc = "Move to the previous file",
    },
    {
      "dp",
      function()
        local node = self:_get_node()
        if node == nil then
          return
        end
        local left_buf, right_buf = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
        if right_buf == nil then
          vim.notify("No right buffer found", vim.log.levels.ERROR)
          return
        end

        local hunk, _ = actions.find_hunk_at_cursor(vim.api.nvim_get_current_tabpage(), left_buf)
        if not hunk then
          vim.notify("No hunk at cursor position", vim.log.levels.WARN)
          return
        end

        -- Get lines from right buffer
        local hunk_lines = vim.api.nvim_buf_get_lines(
          right_buf,
          hunk.modified.start_line - 1,
          hunk.modified.end_line - 1,
          false
        )
        -- Load output buffer
        local output_filepath = vim.fs.joinpath(self.output_dir, node.data.rel_path)
        local output_buf = vim.fn.bufadd(output_filepath)
        -- Ignore swapfile?
        vim.bo[output_buf].swapfile = false
        -- Replace lines in output buffer
        vim.api.nvim_buf_set_lines(
          output_buf,
          hunk.original.start_line - 1,
          hunk.original.end_line - 1,
          false,
          hunk_lines
        )
        -- Save
        vim.api.nvim_buf_call(output_buf, function()
          vim.cmd("write")
        end)

        -- Call diff get on the right to remove the hunk
        actions.diff_get(vim.api.nvim_win_get_tabpage(0), left_buf, right_buf)()
        vim.api.nvim_buf_call(right_buf, function()
          vim.cmd("write")
        end)
      end,
      buffer = _right_buf,
    },
  })
end

return Tree
