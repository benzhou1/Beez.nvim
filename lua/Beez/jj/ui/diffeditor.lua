---@class Beez.jj.DiffEditor
---@field tree Beez.jj.Tree
---@field diff Beez.jj.Diff
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
  d.tree = require("Beez.jj.ui.tree"):new(left_dir, right_dir, output_dir)
  d.diff = require("Beez.jj.ui.diff"):new(left_dir, right_dir, output_dir)
  return d
end

function DiffEditor:render()
  vim.cmd("tabnew")

  self.tree:render(function()
    self:set_tree_keymaps()
    local rel_path = self.tree:get_selected_path()
    self:show_diff(rel_path)
  end)
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
  local ok = self.tree:next()
  if not ok then
    return
  end
  local selected_path = self.tree:get_selected_path()
  self:show_diff(selected_path)
end

function DiffEditor:prev_file()
  local ok = self.tree:prev()
  if not ok then
    return
  end
  local selected_path = self.tree:get_selected_path()
  self:show_diff(selected_path)
end

function DiffEditor:show_diff(rel_path)
  self.diff:render(rel_path, function()
    self:resize()
    self:set_left_keymaps()
    self:set_right_keymaps()
    vim.schedule(function()
      vim.schedule(function()
        self.tree:focus()
      end)
    end)
  end)
end

function DiffEditor:resize()
  self.tree:resize(self.tree_width)
  self.diff:resize(self.tree_width)
end

function DiffEditor:set_tree_keymaps()
  local u = require("Beez.u")
  local buffer = self.tree.buf

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
      "<cr>",
      function()
        self:focus_right()
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
      "<leader>e",
      function()
        self:focus_right()
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
        self.diff:put()
      end,
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
        self.tree:focus()
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
