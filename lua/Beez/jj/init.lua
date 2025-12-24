local M = {}
local S = {
  tree = {
    width = 30,
    winid = nil,
    buf = nil,
    tree = nil,
  },
  original = {
    winid = nil,
    buf = nil,
    dir_path = nil,
  },
  modified = {
    winid = nil,
    buf = nil,
    dir_path = nil,
  },
  left_dir = nil,
  right_dir = nil,
  output_dir = nil,
  curr_path = nil,
}
local H = {}

function H.register_usercmds()
  vim.api.nvim_create_user_command("BeezDiffEditor", function(params)
    local args = params.fargs
    if #args < 2 then
      vim.notify(
        "Error: BeezDiffEditor expects three arguments (left, right[, output])",
        vim.log.levels.ERROR
      )
      return
    end
    require("hunk").start(args[1], args[2], args[3])
  end, {
    nargs = "*",
  })
end

function M.setup(opts)
  opts = opts or {}
  H.register_usercmds()
end

OriginalTree = {}
OriginalTree.__index = OriginalTree

function OriginalTree:new(left_dir, right_dir, output_dir)
  local NuiTree = require("nui.tree")
  local t = {}
  setmetatable(t, OriginalTree)

  local buf = vim.api.nvim_create_buf(false, true)
  t.width = 70
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

function OriginalTree:_get_tree_nodes(dir_path)
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

function OriginalTree:render(cb)
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
    if not left_nodes[path] then
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
    self:set_tree_keymaps()
    cb()
  end)
end

function OriginalTree:focus()
  vim.api.nvim_set_current_win(self.winid)
end

function OriginalTree.focus_right()
  local lifecycle = require("vscode-diff.render.lifecycle")
  local _, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
  if right_winid ~= nil then
    vim.api.nvim_set_current_win(right_winid)
  end
end

function OriginalTree:_get_node(lineno)
  lineno = lineno or vim.api.nvim_win_get_cursor(self.winid)[1]
  local node = self.tree:get_node(lineno)
  if node == nil then
    vim.notify("Could not find tree node at: " .. lineno, vim.log.levels.WARN)
    return
  end
  return node
end

function OriginalTree:diff(lineno)
  lineno = lineno or vim.api.nvim_win_get_cursor(self.winid)[1]
  local lifecycle = require("vscode-diff.render.lifecycle")
  local view = require("vscode-diff.render.view")
  local node = self:_get_node(lineno)
  if node == nil then
    return
  end

  local left_filepath = vim.fs.joinpath(self.left_dir, node.data.rel_path)
  local right_filepath = vim.fs.joinpath(self.right_dir, node.data.rel_path)

  local left_winid, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
  -- If no diff is currently opened then create a new window for the diff
  if left_winid == nil or right_winid == nil then
    -- We have to open a file for some reason...
    vim.cmd("vsplit " .. left_filepath)
    ---@type SessionConfig
    local session_config = {
      mode = "standalone",
      git_root = nil,
      original_path = left_filepath,
      modified_path = right_filepath,
      original_revision = nil,
      modified_revision = nil,
      new_tab = false,
    }
    view.create(session_config)
  -- Otherwise update the existing diff
  else
    ---@type SessionConfig
    local session_config = {
      mode = "standalone",
      git_root = nil,
      original_path = left_filepath,
      modified_path = right_filepath,
      original_revision = nil,
      modified_revision = nil,
      new_tab = false,
    }
    view.update(vim.api.nvim_get_current_tabpage(), session_config, true)
  end

  vim.schedule(function()
    self:update_widths()
    self:set_left_keymaps()
    self:set_right_keymaps()
    vim.schedule(function()
      vim.schedule(function()
        self:focus()
      end)
    end)
  end)
end

function OriginalTree:next_file()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] + 1
  local last_line = vim.api.nvim_buf_line_count(0)
  if pos[1] == last_line then
    return
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  self:diff()
end

function OriginalTree:prev_file()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  local lineno = pos[1] - 1
  if pos[1] == 1 then
    return
  end
  vim.api.nvim_win_set_cursor(self.winid, { lineno, pos[2] })
  self:diff()
end

function OriginalTree:update_widths()
  local lifecycle = require("vscode-diff.render.lifecycle")
  -- Set the tree window width
  vim.api.nvim_win_set_width(self.winid, self.width)

  -- Even out the width for the diff windows
  local width = math.floor((vim.o.columns - self.width) / 2)
  local left_winid, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
  if left_winid ~= nil then
    vim.api.nvim_win_set_width(left_winid, width)
  end
  if right_winid ~= nil then
    vim.api.nvim_win_set_width(right_winid, width)
  end
end

function OriginalTree:set_tree_keymaps()
  local u = require("Beez.u")
  local lifecycle = require("vscode-diff.render.lifecycle")
  local buffer = self.tree.bufnr

  u.keymaps.set({
    {
      "q",
      function()
        vim.cmd("cq")
      end,
      buffer = buffer,
      desc = "Quit and ignore changes",
    },
    {
      "<cr>",
      function()
        local _, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
        if right_winid ~= nil then
          vim.api.nvim_set_current_win(right_winid)
        end
      end,
      buffer = buffer,
      desc = "Open selected file in diff editors",
    },
    {
      "k",
      function()
        self:next_file()
      end,
      buffer = buffer,
    },
    {
      "j",
      function()
        self:prev_file()
      end,
      buffer = buffer,
    },
  })
end

function OriginalTree:set_left_keymaps()
  local u = require("Beez.u")
  local lifecycle = require("vscode-diff.render.lifecycle")
  local _left_buf, _ = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())

  u.keymaps.set({
    {
      "q",
      function()
        vim.cmd("cq")
      end,
      buffer = _left_buf,
      desc = "Quit and ignore changes",
    },
    {
      "<leader>e",
      function()
        self:focus()
      end,
      buffer = _left_buf,
      desc = "Focus the file tree window",
    },
    {
      "<leader><cr>",
      function()
        vim.cmd("qa")
      end,
      buffer = _left_buf,
      desc = "Quit and apply changes",
    },
  })
end

function OriginalTree:set_right_keymaps()
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

function M.diffeditor(left_dir, right_dir, output_dir)
  local u = require("Beez.u")

  -- Make a copy of the right since it is read only
  -- local new_right_dir = right_dir .. "_beez_diff_editor_tmp"
  -- u.os.copy_dir(right_dir, new_right_dir, { chmod_mode = chmod_mode })
  -- right_dir = new_right_dir
  vim.fn.delete(right_dir, "rf")
  u.os.copy_dir(output_dir, right_dir, { chmod_mode = chmod_mode })

  -- Make output the same as left, by deleting it and then copying left to output and make sure its writable
  vim.fn.delete(output_dir, "rf")
  -- Read write
  -- 420 decimal == 0o644 octal
  -- 0o644 = rw-r--r--
  local chmod_mode = 420
  u.os.copy_dir(left_dir, output_dir, { chmod_mode = chmod_mode })

  -- Create a new tab to keep windows clean
  -- vim.cmd("tabnew")

  local diffeditor = require("Beez.jj.ui.diffeditor"):new(left_dir, right_dir, output_dir)
  diffeditor:render()
end

return M
