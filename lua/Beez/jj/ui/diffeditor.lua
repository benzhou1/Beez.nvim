local uv = vim.uv or vim.loop

local function sort_tree_nodes(nodes)
  -- Sort nodes by length and alphabetically
  table.sort(nodes, function(a, b)
    if #a.data.path == #b.data.path then
      return a.text < b.text
    else
      return #a.data.path < #b.data.path
    end
  end)
  return nodes
end

---@class Beez.jj.DiffEditor
---@field left_dir string
---@field right_dir string
---@field output_dir string
---@field rtree Beez.jj.Tree
---@field otree Beez.jj.Tree
---@field diff Beez.jj.Diff
---@field tree_width integer
---@field diffing_right boolean
DiffEditor = {}
DiffEditor.__index = DiffEditor

--- Instantiate a new DiffEditor
---@param left_dir string
---@param right_dir string
---@param output_dir string
---@return Beez.jj.DiffEditor
function DiffEditor:new(left_dir, right_dir, output_dir)
  local d = {}
  setmetatable(d, DiffEditor)

  d.tree_width = 50
  d.left_dir = left_dir
  d.right_dir = right_dir
  d.output_dir = output_dir
  d.rtree = require("Beez.jj.ui.tree"):new("New commit tree", left_dir, right_dir, output_dir)
  d.otree = require("Beez.jj.ui.tree"):new("Original commit tree", left_dir, output_dir, right_dir)
  d.diff = require("Beez.jj.ui.diff"):new(left_dir, right_dir, output_dir)
  d.diffing_right = true
  return d
end

local function get_files_as_tree_nodes(dir_path)
  local u = require("Beez.u")
  local NuiTree = require("nui.tree")
  local nodes = {}

  for root, _, files in u.os.walk(dir_path) do
    for _, f in ipairs(files) do
      local path = vim.fs.joinpath(root, f)
      local rel_path = vim.fs.relpath(dir_path, path)
      assert(rel_path ~= nil, "Could not get relative path for: " .. path)
      nodes[rel_path] = NuiTree.Node({
        text = rel_path,
        data = { path = path, rel_path = rel_path, status = "modified" },
      })
    end
  end

  table.sort(nodes, function(a, b)
    return a.text < b.text
  end)
  return nodes
end

function DiffEditor:_setup_autocmds()
  local events = require("nui.utils.autocmd").event
  vim.api.nvim_create_autocmd({ events.WinEnter }, {
    callback = function(_)
      local curr_winid = vim.api.nvim_get_current_win()
      if curr_winid == self.rtree.winid then
        self.rtree:show_cursor_line()
        self.otree:hide_cursor_line()
      end
      if curr_winid == self.otree.winid then
        self.otree:show_cursor_line()
        self.rtree:hide_cursor_line()
      end
    end,
  })
end

function DiffEditor:_get_rtree_nodes()
  local nodes = {}
  local left_nodes = get_files_as_tree_nodes(self.left_dir)
  local right_nodes = get_files_as_tree_nodes(self.right_dir)
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
  nodes = sort_tree_nodes(nodes)
  return nodes
end

function DiffEditor:_update_file_statuses()
  local u = require("Beez.u")
  local NuiTree = require("nui.tree")
  local rel_path = self.diff.rel_path
  local is_diff_focused = self.diff:is_focused()

  local function add_to_otree()
    local right_node = self.rtree:get(rel_path)
    if right_node == nil then
      return
    end
    local output_node = NuiTree.Node({
      text = right_node.text,
      data = {
        status = right_node.data.status,
        path = vim.fs.joinpath(self.output_dir, rel_path),
        rel_path = rel_path,
      },
    })
    self.otree:add_node(output_node, sort_tree_nodes)
  end

  local function add_to_rtree()
    local output_node = self.otree:get(rel_path)
    if output_node == nil then
      return
    end
    local right_node = NuiTree.Node({
      text = output_node.text,
      data = {
        status = output_node.data.status,
        path = vim.fs.joinpath(self.output_dir, rel_path),
        rel_path = rel_path,
      },
    })
    self.rtree:add_node(right_node, sort_tree_nodes)
  end

  local function remove_from_rtree()
    self.rtree:remove_node(rel_path)
    local selected_path = self.rtree:get_selected_path()
    -- Move to next file
    if selected_path ~= nil then
      self:show_diff(selected_path, function()
        if not is_diff_focused then
          self:focus_rtree()
        end
      end)

    -- Right tree is empty now, move to output tree
    else
      selected_path = self.otree:get_selected_path()
      self:show_diff(rel_path, false, function()
        if not is_diff_focused then
          self:focus_otree()
        end
      end)
      self.otree:show_cursor_line()
    end
  end

  local function remove_from_otree()
    self.otree:remove_node(rel_path)
    local selected_path = self.otree:get_selected_path()
    -- Move to next file
    if selected_path ~= nil then
      self:show_diff(selected_path, false, function()
        if not is_diff_focused then
          self:focus_otree()
        end
      end)

    -- Output tree is empty now, move back to right tree
    else
      selected_path = self.rtree:get_selected_path()
      self:show_diff(selected_path, function()
        if not is_diff_focused then
          self:focus_rtree()
        end
      end)
      self.rtree:show_cursor_line()
    end
  end

  local left_filepath = vim.fs.joinpath(self.left_dir, rel_path)
  local right_filepath = vim.fs.joinpath(self.right_dir, rel_path)
  local output_filepath = vim.fs.joinpath(self.output_dir, rel_path)
  local output_same_as_left = u.os.is_file_same(left_filepath, output_filepath)
  local right_same_as_left = u.os.is_file_same(left_filepath, right_filepath)

  -- This means there is at least one change present in output
  -- Add the file to the output tree if not already present
  if not output_same_as_left then
    add_to_otree()
  end

  -- This means there is at least one change present in right
  -- Add the file to the right tree if not already present
  if not right_same_as_left then
    add_to_rtree()
  end

  -- This means that there are no changes present in output
  -- Remove the file from the output tree
  if output_same_as_left then
    remove_from_otree()
  end

  -- This means that there are no more changes on the right
  -- Remove the file from the right tree
  if right_same_as_left then
    remove_from_rtree()
  end
end

function DiffEditor:render()
  -- Populate the right tree
  local right_tree_nodes = self:_get_rtree_nodes()
  -- Create laytout first
  vim.cmd("tabnew")
  local rtree_winid = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local diff_winid = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")
  vim.cmd("split")
  local otree_winid = vim.api.nvim_get_current_win()

  -- First render the right tree
  vim.api.nvim_set_current_win(rtree_winid)
  self.rtree:render(right_tree_nodes, function()
    -- Second render the output tree
    vim.api.nvim_set_current_win(otree_winid)
    -- Output tree will be empty until changes are put in it
    self.otree:render({}, function()
      self:set_tree_keymaps()

      -- Finally render the first diff
      vim.api.nvim_set_current_win(diff_winid)
      local rel_path = self.rtree:get_selected_path()
      self:show_diff(rel_path, function()
        self:focus_prev_tree()
        self.otree:hide_cursor_line()
        self:_setup_autocmds()
      end)
    end)
  end)
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
function DiffEditor:scroll_diff(lines)
  local _, right_winid = self.diff:get_windows()
  if right_winid == nil then
    return
  end
  local pos = vim.api.nvim_win_get_cursor(right_winid)
  pcall(vim.api.nvim_win_set_cursor, right_winid, { pos[1] + lines, pos[2] })
  vim.api.nvim_win_call(right_winid, function()
    vim.cmd("normal! zz")
  end)
end

function DiffEditor:toggle_file_change()
  local left_filepath = vim.fs.joinpath(self.left_dir, self.diff.rel_path)
  local right_filepath = vim.fs.joinpath(self.right_dir, self.diff.rel_path)
  local output_filepath = vim.fs.joinpath(self.output_dir, self.diff.rel_path)
  local node
  if self.diffing_right then
    node = self.rtree:get(self.diff.rel_path)
  else
    node = self.otree:get(self.diff.rel_path)
  end

  -- Handle when files are deleted
  if node ~= nil and node.data.status == "deleted" then
    if self.diffing_right then
      -- Delete file in output
      uv.fs_unlink(output_filepath, function()
        vim.schedule(function()
          -- Need to reload the buffer since the file got deleted
          local output_buf = vim.fn.bufnr(output_filepath)
          if output_buf > 0 then
            vim.api.nvim_buf_call(output_buf, function()
              vim.api.nvim_command("edit")
            end)
          end

          -- Copy file from left to right
          uv.fs_copyfile(left_filepath, right_filepath, function()
            uv.fs_chmod(right_filepath, 420) -- 420 is decimal for 0644 (rw-r--r--)
            vim.schedule(function()
              -- Need to reload the buffer since the file changed from the copy
              local right_buf = vim.fn.bufnr(right_filepath)
              if right_buf > 0 then
                vim.api.nvim_buf_call(right_buf, function()
                  vim.api.nvim_command("edit")
                end)
              end
              self:_update_file_statuses()
            end)
          end)
        end)
      end)
    else
      -- Delete file in right
      uv.fs_unlink(right_filepath, function()
        vim.schedule(function()
          -- Need to reload the buffer since the file got deleted
          local right_buf = vim.fn.bufnr(right_filepath)
          if right_buf > 0 then
            vim.api.nvim_buf_call(right_buf, function()
              vim.api.nvim_command("edit")
            end)
          end
          -- Copy file from left to output
          uv.fs_copyfile(left_filepath, output_filepath, function()
            uv.fs_chmod(output_filepath, 420) -- 420 is decimal for 0644 (rw-r--r--)
            vim.schedule(function()
              -- Need to reload the buffer since the file changed from the copy
              local output_buf = vim.fn.bufnr(output_filepath)
              if output_buf > 0 then
                vim.api.nvim_buf_call(output_buf, function()
                  vim.api.nvim_command("edit")
                end)
              end
              self:_update_file_statuses()
            end)
          end)
        end)
      end)
    end
    return
  end

  -- Handle if file is added
  if node ~= nil and node.data.status == "added" then
    if self.diffing_right then
      -- First copy right to output
      uv.fs_copyfile(right_filepath, output_filepath, function()
        vim.schedule(function()
          -- Need to reload the buffer since the file got copied
          local output_buf = vim.fn.bufnr(output_filepath)
          if output_buf > 0 then
            vim.api.nvim_buf_call(output_buf, function()
              vim.api.nvim_command("edit")
            end)
          end

          -- Then delete the right file, so that it will be same as left
          uv.fs_unlink(right_filepath, function()
            vim.schedule(function()
              -- Need to reload the buffer since the file got deleted
              local right_buf = vim.fn.bufnr(right_filepath)
              if right_buf > 0 then
                vim.api.nvim_buf_call(right_buf, function()
                  vim.api.nvim_command("edit")
                end)
              end

              vim.schedule(function()
                self:_update_file_statuses()
              end)
            end)
          end)
        end)
      end)
    else
      -- First copy output to right
      uv.fs_copyfile(output_filepath, right_filepath, function()
        vim.schedule(function()
          -- Need to reload the buffer since the file got copied
          local right_buf = vim.fn.bufnr(right_filepath)
          if right_buf > 0 then
            vim.api.nvim_buf_call(right_buf, function()
              vim.api.nvim_command("edit")
            end)
          end

          -- Then delete the output file, so that it will be same as left
          uv.fs_unlink(output_filepath, function()
            vim.schedule(function()
              -- Need to reload the buffer since the file got deleted
              local output_buf = vim.fn.bufnr(output_filepath)
              if output_buf > 0 then
                vim.api.nvim_buf_call(output_buf, function()
                  vim.api.nvim_command("edit")
                end)
              end

              vim.schedule(function()
                self:_update_file_statuses()
              end)
            end)
          end)
        end)
      end)
    end
    return
  end

  if self.diffing_right then
    -- Copy right to output
    uv.fs_copyfile(right_filepath, output_filepath, function()
      -- Copy left to right
      uv.fs_copyfile(left_filepath, right_filepath, function()
        uv.fs_chmod(right_filepath, 420) -- 420 is decimal for 0644 (rw-r--r--)
        vim.schedule(function()
          self:_update_file_statuses()
        end)
      end)
    end)
  else
    -- Copy output to right
    uv.fs_copyfile(output_filepath, right_filepath, function()
      -- Copy left to output
      uv.fs_copyfile(left_filepath, output_filepath, function()
        uv.fs_chmod(output_filepath, 420) -- 420 is decimal for 0644 (rw-r--r--)
        vim.schedule(function()
          self:_update_file_statuses()
        end)
      end)
    end)
  end
end

function DiffEditor:toggle_hunk_change()
  if not self.diff:is_focused() then
    return
  end
  local ok = self.diff:put()
  if ok then
    self:_update_file_statuses()
  end
end

function DiffEditor:focus_rtree()
  self.rtree:focus()
  self:show_curr_diff(function()
    self.rtree:focus()
  end)
end

function DiffEditor:focus_otree()
  self.otree:focus()
  self.diffing_right = false
  self:show_curr_diff(function()
    self.otree:focus()
  end)
end

function DiffEditor:focus_other_tree()
  if self.rtree:is_focused() then
    self:focus_otree()
    self:show_curr_diff(function()
      self:focus_otree()
    end)
  elseif self.otree:is_focused() then
    self:focus_rtree()
    self:show_curr_diff(function()
      self:focus_rtree()
    end)
  end
end

function DiffEditor:focus_prev_tree()
  if self.rtree:is_focused() or self.otree:is_focused() then
    return
  end
  if self.diffing_right then
    self:focus_rtree()
  else
    self:focus_otree()
  end
end

function DiffEditor:focus_right()
  self.diff:focus()
end

function DiffEditor:quit()
  vim.cmd("cq")
end

function DiffEditor:apply_and_quit()
  vim.cmd("qa")
end

function DiffEditor:next_file()
  local is_diff_focused = self.diff:is_focused()
  local rel_path
  if self.diffing_right then
    local ok = self.rtree:next()
    rel_path = self.rtree:get_selected_path()
    if not ok then
      return
    end
  else
    local ok = self.otree:next()
    rel_path = self.otree:get_selected_path()
    if not ok then
      return
    end
  end
  self:show_diff(rel_path, self.diffing_right, function()
    if not is_diff_focused then
      if self.diffing_right then
        self.rtree:focus()
      else
        self.otree:focus()
      end
    end
  end)
end

function DiffEditor:prev_file()
  local is_diff_focused = self.diff:is_focused()
  local rel_path
  if self.diffing_right then
    local ok = self.rtree:prev()
    if not ok then
      return
    end
    rel_path = self.rtree:get_selected_path()
  else
    local ok = self.otree:prev()
    if not ok then
      return
    end
    rel_path = self.otree:get_selected_path()
  end
  self:show_diff(rel_path, self.diffing_right, function()
    if not is_diff_focused then
      if self.diffing_right then
        self.rtree:focus()
      else
        self.otree:focus()
      end
    end
  end)
end

function DiffEditor:show_curr_diff(cb)
  if self.rtree:is_focused() then
    local selected_path = self.rtree:get_selected_path()
    self:show_diff(selected_path, cb)
  else
    local selected_path = self.otree:get_selected_path()
    self:show_diff(selected_path, false, cb)
  end
end

function DiffEditor:show_diff(rel_path, diffing_right, cb)
  local lifecycle = require("vscode-diff.render.lifecycle")
  if type(diffing_right) == "function" then
    cb = diffing_right
    diffing_right = nil
  end
  if diffing_right == nil then
    diffing_right = true
  end
  if rel_path == self.diff.rel_path and diffing_right == self.diffing_right then
    return
  end

  if not diffing_right then
    self.diff:update_paths({
      right_dir = self.output_dir,
      output_dir = self.right_dir,
      require_new_diff_results = true,
    })
  else
    self.diff:update_paths({
      right_dir = self.right_dir,
      output_dir = self.output_dir,
      require_new_diff_results = false,
    })
  end
  self.diff:render(rel_path, function()
    local left_buf, right_buf = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
    -- Make left not modifiable
    vim.bo[left_buf].modifiable = false
    -- Make right not modifiable
    if diffing_right then
      vim.bo[right_buf].modifiable = false
    end

    self:resize()
    self:set_left_keymaps(left_buf)
    self:set_right_keymaps(right_buf)

    vim.schedule(function()
      vim.schedule(function()
        if cb ~= nil then
          cb()
        end
      end)
    end)
  end)
  self.diffing_right = diffing_right
end

function DiffEditor:toggle_other_diff()
  if not self.diff:is_focused() then
    return
  end
  if self.diffing_right then
    local output_node = self.otree:get(self.diff.rel_path)
    if output_node == nil then
      vim.notify("No changes in original commit tree for this file", vim.log.levels.WARN)
      return
    end

    self:show_diff(self.diff.rel_path, false)
    self.otree:select_path(self.diff.rel_path)
    self.otree:show_cursor_line()
    self.rtree:hide_cursor_line()
  else
    local right_node = self.rtree:get(self.diff.rel_path)
    if right_node == nil then
      vim.notify("No changes in new commit tree for this file", vim.log.levels.WARN)
      return
    end

    self:show_diff(self.diff.rel_path)
    self.rtree:select_path(self.diff.rel_path)
    self.rtree:show_cursor_line()
    self.otree:hide_cursor_line()
  end
end

function DiffEditor:resize()
  self.rtree:resize(self.tree_width)
  self.otree:resize(self.tree_width)
  self.diff:resize(self.tree_width)
end

-----------------------------------------------------------------------------------------------
--- KEYMAPS
-----------------------------------------------------------------------------------------------
function DiffEditor:set_tree_keymaps()
  local u = require("Beez.u")
  local actions = require("vscode-diff.render.keymaps").actions
  local quit = {
    "q",
    function()
      self:quit()
    end,
    desc = "Quit and ignore changes",
  }
  local focus_diff = {
    "<cr>",
    function()
      self:focus_right()
    end,
    desc = "Open selected file in diff editors",
  }
  local next_file = {
    "k",
    function()
      self:next_file()
    end,
    desc = "Move to the next file and diff",
  }
  local prev_file = {
    "j",
    function()
      self:prev_file()
    end,
    desc = "Move to the previous file and diff",
  }
  local toggle_file_change = {
    "<space>",
    function()
      self:toggle_file_change()
    end,
    desc = "Toggle entire file changed",
  }
  local apply_and_quit = {
    "\\<cr>",
    function()
      vim.cmd("qa")
    end,
    desc = "Apply all changes and quit",
  }
  local scroll_diff_down = {
    "K",
    function()
      self:scroll_diff(20)
    end,
    desc = "Scroll diff down",
  }
  local scroll_diff_up = {
    "J",
    function()
      self:scroll_diff(-20)
    end,
    desc = "Scroll diff up",
  }
  local scroll_to_next_hunk = {
    "<f7>",
    function()
      local left_buf, _ = self.diff:get_buffers()
      self:focus_right()
      actions.navigate_next_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      vim.cmd("normal! zz")
      self:focus_prev_tree()
    end,
    desc = "Scroll to next hunk",
  }
  local scroll_to_prev_hunk = {
    "<s-f7>",
    function()
      local left_buf, _ = self.diff:get_buffers()
      self:focus_right()
      actions.navigate_prev_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      vim.cmd("normal! zz")
      self:focus_prev_tree()
    end,
    desc = "Scroll to previous hunk",
  }

  u.keymaps.set({
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, quit),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, quit),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, focus_diff),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, focus_diff),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, next_file),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, next_file),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, prev_file),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, prev_file),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, toggle_file_change),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, toggle_file_change),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, apply_and_quit),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, apply_and_quit),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, scroll_diff_down),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, scroll_diff_down),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, scroll_diff_up),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, scroll_diff_up),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, scroll_to_next_hunk),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, scroll_to_next_hunk),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, scroll_to_prev_hunk),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, scroll_to_prev_hunk),
    {
      "<c-k>",
      function()
        self:focus_other_tree()
      end,
      desc = "Focus the output file tree window",
      buffer = self.rtree.buf,
    },
    {
      "<c-j>",
      function()
        self:focus_other_tree()
      end,
      desc = "Focus the right file tree window",
      buffer = self.otree.buf,
    },
  })
end

function DiffEditor:set_right_keymaps(buffer)
  local actions = require("vscode-diff.render.keymaps").actions
  local u = require("Beez.u")
  u.keymaps.set({
    {
      "q",
      function()
        self:quit()
      end,
      buffer = buffer,
      desc = "Quit and ignore changes",
    },
    {
      "-",
      function()
        self:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
    {
      "<c-j>",
      function()
        self:focus_rtree()
      end,
      buffer = buffer,
      desc = "Focus the original commit tree window",
    },
    {
      "<c-k>",
      function()
        self:focus_otree()
      end,
      buffer = buffer,
      desc = "Focus the new commit tree window",
    },
    {
      "<leader><cr>",
      function()
        self:apply_and_quit()
      end,
      buffer = buffer,
      desc = "Quit and apply changes",
    },
    {
      "<tab>",
      function()
        self:next_file()
      end,
      buffer = buffer,
      desc = "Move to the next file",
    },
    {
      "<s-tab>",
      function()
        self:prev_file()
      end,
      buffer = buffer,
      desc = "Move to the previous file",
    },
    {
      "<space>",
      function()
        self:toggle_hunk_change()
      end,
      buffer = buffer,
    },
    {
      "\\\\",
      function()
        self:toggle_other_diff()
      end,
      desc = "Toggle between original/output diff",
      buffer = buffer,
    },
    {
      "<f7>",
      function()
        local left_buf, _ = self.diff:get_buffers()
        actions.navigate_next_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      end,
      desc = "Navigate to the next hunk",
    },
    {
      "<s-f7>",
      function()
        local left_buf, _ = self.diff:get_buffers()
        actions.navigate_prev_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      end,
      desc = "Navigate to the prev hunk",
    },
  })
end

function DiffEditor:set_left_keymaps(buffer)
  local u = require("Beez.u")
  u.keymaps.set({
    {
      "q",
      function()
        self:quit()
      end,
      buffer = buffer,
      desc = "Quit and ignore changes",
    },
    {
      "-",
      function()
        self:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
    {
      "<c-j>",
      function()
        self:focus_rtree()
      end,
      buffer = buffer,
      desc = "Focus the original commit tree window",
    },
    {
      "<c-k>",
      function()
        self:focus_otree()
      end,
      buffer = buffer,
      desc = "Focus the new commit tree window",
    },
    {
      "<tab>",
      function()
        self:next_file()
      end,
      buffer = buffer,
      desc = "Move to the next file",
    },
    {
      "<s-tab>",
      function()
        self:prev_file()
      end,
      buffer = buffer,
      desc = "Move to the previous file",
    },
  })
end

return DiffEditor
