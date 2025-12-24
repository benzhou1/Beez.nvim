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
  d.rtree = require("Beez.jj.ui.tree"):new("Right tree", left_dir, right_dir, output_dir)
  d.otree = require("Beez.jj.ui.tree"):new("Output tree", left_dir, output_dir, right_dir)
  d.diff = require("Beez.jj.ui.diff"):new(left_dir, right_dir, output_dir)
  d.diffing_right = true
  return d
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

function DiffEditor:render()
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
  self.rtree:render(function()
    -- Second render the output tree
    vim.api.nvim_set_current_win(otree_winid)
    self.otree:render(function()
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
    rel_path = self.rtree:get_selected_path()
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
    rel_path = self.rtree:get_selected_path()
    if not ok then
      return
    end
  else
    local ok = self.otree:prev()
    rel_path = self.rtree:get_selected_path()
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
  if type(diffing_right) == "function" then
    cb = diffing_right
    diffing_right = nil
  end
  if diffing_right == nil then
    diffing_right = true
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
    self:resize()
    self:set_left_keymaps()
    self:set_right_keymaps()
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
    self:show_diff(self.diff.rel_path, false)
    self.otree:select_path(self.diff.rel_path)
    self.otree:show_cursor_line()
    self.rtree:hide_cursor_line()
  else
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

function DiffEditor:diff_put()
  if not self.diff:is_focused() then
    return
  end
  local ok = self.diff:put()
end

-----------------------------------------------------------------------------------------------
--- KEYMAPS
-----------------------------------------------------------------------------------------------
function DiffEditor:set_tree_keymaps()
  local u = require("Beez.u")
  local quit = {
    "q",
    function()
      self:quit()
    end,
    desc = "Quit and ignore changes",
  }
  local apply_and_quit = {
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

  u.keymaps.set({
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, quit),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, quit),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, apply_and_quit),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, apply_and_quit),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, next_file),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, next_file),
    vim.tbl_deep_extend("keep", { buffer = self.rtree.buf }, prev_file),
    vim.tbl_deep_extend("keep", { buffer = self.otree.buf }, prev_file),
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

function DiffEditor:set_right_keymaps()
  local u = require("Beez.u")
  local lifecycle = require("vscode-diff.render.lifecycle")
  local _, _right_buf = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
  local buffer = _right_buf

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
      "<leader>r",
      function()
        self:focus_rtree()
      end,
      buffer = buffer,
      desc = "Focus the file tree window",
    },
    {
      "<leader>o",
      function()
        self:focus_otree()
      end,
      buffer = buffer,
      desc = "Focus the file tree window",
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
      "dp",
      function()
        self:diff_put()
      end,
      buffer = buffer,
    },
    {
      "<leader>t",
      function()
        self:toggle_other_diff()
      end,
      desc = "Toggle between original/output diff",
      buffer = buffer,
    },
  })
end

function DiffEditor:set_left_keymaps()
  local u = require("Beez.u")
  local lifecycle = require("vscode-diff.render.lifecycle")
  local _left_buf, _ = lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
  local buffer = _left_buf

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
      "<leader>e",
      function()
        self.rtree:focus()
      end,
      buffer = buffer,
      desc = "Focus the file tree window",
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
  })
end

return DiffEditor
