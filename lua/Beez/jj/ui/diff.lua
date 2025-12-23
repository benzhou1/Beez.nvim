---@class Beez.jj.Diff
---@field left_dir string
---@field right_dir string
---@field output_dir string
Diff = {}
Diff.__index = Diff

--- Instaintiates a new Diff
---@param left_dir string
---@param right_dir string
---@param output_dir string
---@return Beez.jj.Diff
function Diff:new(left_dir, right_dir, output_dir)
  local d = {}
  setmetatable(d, Diff)

  d.left_dir = left_dir
  d.right_dir = right_dir
  d.output_dir = output_dir
  d.rel_path = nil
  return d
end

function Diff:focus()
  local lifecycle = require("vscode-diff.render.lifecycle")
  local _, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
  if right_winid ~= nil then
    vim.api.nvim_set_current_win(right_winid)
  end
end

function Diff:resize(offset_width)
  local lifecycle = require("vscode-diff.render.lifecycle")
  local left_winid, right_winid = lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
  local width = math.floor((vim.o.columns - offset_width) / 2)
  if left_winid ~= nil then
    vim.api.nvim_win_set_width(left_winid, width)
  end
  if right_winid ~= nil then
    vim.api.nvim_win_set_width(right_winid, width)
  end
end

function Diff:render(rel_path, cb)
  local lifecycle = require("vscode-diff.render.lifecycle")
  local view = require("vscode-diff.render.view")
  local left_filepath = vim.fs.joinpath(self.left_dir, rel_path)
  local right_filepath = vim.fs.joinpath(self.right_dir, rel_path)

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

  self.rel_path = rel_path
  vim.schedule(function()
    cb()
  end)
end

function Diff:put()
  local lifecycle = require("vscode-diff.render.lifecycle")
  local actions = require("vscode-diff.render.keymaps").actions
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
  local output_filepath = vim.fs.joinpath(self.output_dir, self.rel_path)
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
end

return Diff
