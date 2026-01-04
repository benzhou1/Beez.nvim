---@class Beez.jj.ui.VscodeDiff.Diff
---@field temppath string

---@class Beez.jj.ui.VscodeDiff
---@field diffs table<string, Beez.jj.ui.VscodeDiff.Diff>
VscodeDiff = {}
VscodeDiff.__index = VscodeDiff

--- Instaintiates a new VscodeDiff
---@return Beez.jj.Diff
function VscodeDiff.new()
  local d = {}
  setmetatable(d, VscodeDiff)

  d.diffs = {}
  return d
end

--- Renders a vscode diff for specified file path
---@param filepath string
---@param cb? fun()
function VscodeDiff:render(filepath, cb)
  local commands = require("Beez.jj.commands")
  local view = require("vscode-diff.render.view")
  local left_winid, right_winid = self:get_windows()

  local function render_diff(original_path)
    -- If no diff is currently opened then create a new window for the diff
    if left_winid == nil or right_winid == nil then
      vim.cmd("vsplit")
      vim.cmd("e " .. filepath)
      ---@type SessionConfig
      local session_config = {
        mode = "standalone",
        git_root = nil,
        original_path = original_path,
        modified_path = filepath,
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
        original_path = original_path,
        modified_path = filepath,
        original_revision = nil,
        modified_revision = nil,
        new_tab = false,
      }
      view.update(vim.api.nvim_get_current_tabpage(), session_config, true)
    end

    vim.schedule(function()
      if cb ~= nil then
        cb()
      end
    end)
  end

  local diff = self.diffs[filepath]
  if diff == nil then
    -- Use jj file show to get original content
    commands.file_show(function(err, orig_content)
      if err ~= nil then
        return
      end

      -- Create a temporary file for original content
      vim.schedule(function()
        local tmpname = vim.fn.tempname()
        local fd = vim.loop.fs_open(tmpname, "w", 384) -- 384 = 0600 permissions
        if fd then
          vim.loop.fs_write(fd, orig_content)
          vim.loop.fs_close(fd)
        end

        diff = { temppath = tmpname }
        self.diffs[filepath] = diff
        render_diff(tmpname)
      end)
    end, {
      path = filepath,
      r = "@-",
      ignore_err = {
        "No such path",
      },
    })
    return
  end

  render_diff(diff.temppath)
end

-----------------------------------------------------------------------------------------------
--- STATE
-----------------------------------------------------------------------------------------------
--- Checks whether the diff windows are focused or not
---@return boolean
function VscodeDiff:is_focused()
  local left_winid, right_winid = self:get_windows()
  local curr_winid = vim.api.nvim_get_current_win()
  return curr_winid == right_winid or curr_winid == left_winid
end

--- Get the diff buffers
---@return integer?, integer?
function VscodeDiff:get_buffers()
  local lifecycle = require("vscode-diff.render.lifecycle")
  return lifecycle.get_buffers(vim.api.nvim_get_current_tabpage())
end

--- Get the diff windows
---@return integer?, integer?
function VscodeDiff:get_windows()
  local lifecycle = require("vscode-diff.render.lifecycle")
  return lifecycle.get_windows(vim.api.nvim_get_current_tabpage())
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Focus on the right diff
function VscodeDiff:focus()
  local _, right_winid = self:get_windows()
  if right_winid ~= nil then
    vim.api.nvim_set_current_win(right_winid)
  end
end

--- Scroll the right diff window
---@param offset integer
function VscodeDiff:scroll(offset)
  local _, right_winid = self:get_windows()
  if right_winid == nil then
    return
  end

  pcall(vim.api.nvim_win_set_cursor, right_winid, {
    vim.api.nvim_win_get_cursor(right_winid)[1] + offset,
    0,
  })
  vim.api.nvim_win_call(right_winid, function()
    vim.cmd("normal! zz")
  end)
end

--- Resize the diff windows so that they are evenly spaced
---@param offset_width integer
function VscodeDiff:resize(offset_width)
  local left_winid, right_winid = self:get_windows()
  local width = math.floor((vim.o.columns - offset_width) / 2)
  if left_winid ~= nil then
    vim.api.nvim_win_set_width(left_winid, width)
  end
  if right_winid ~= nil then
    vim.api.nvim_win_set_width(right_winid, width)
  end
end

--- Clean up temporary files by removing the buffers
function VscodeDiff:cleanup()
  for _, d in pairs(self.diffs) do
    local bufnr = vim.fn.bufnr(d.temppath)
    if bufnr ~= nil then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

--- Maps default key bindings to both buffers
---@param view Beez.jj.ui.JJView
function VscodeDiff:map(view)
  local u = require("Beez.u")
  local keymaps = {
    quit = {
      "q",
      function()
        view:quit()
      end,
      desc = "Close",
    },
  }

  local left_buf, right_buf = self:get_buffers()
  for _, km in pairs(keymaps) do
    u.keymaps.set({
      vim.tbl_deep_extend("keep", { buffer = left_buf }, km),
      vim.tbl_deep_extend("keep", { buffer = right_buf }, km),
    })
  end
end

return VscodeDiff
