---@class Beez.jj.ui.Change
---@field status "A"|"D"
---@field orig integer the line number that change should be applied to
---@field mod integer  the line number
---@field hunk integer
---@field text string
---@field id integer

---@class Beez.jj.ui.UnifiedDiff.Diff
---@field left Beez.jj.ui.DiffBuf
---@field right Beez.jj.ui.DiffBuf
---@field orig_lines string[]

---@class Beez.jj.ui.UnifiedDiff
---@field path string?
---@field diffs table<string, Beez.jj.ui.UnifiedDiff.Diff>
---@field left_buf number
---@field left_win number?
---@field right_buf number
---@field right_win number?
UnifiedDiff = {}
UnifiedDiff.__index = UnifiedDiff

--- Instantiates a new UnifiedDiff
---@return Beez.jj.ui.UnifiedDiff
function UnifiedDiff.new()
  local d = {}
  setmetatable(d, UnifiedDiff)

  local left_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[left_buf].modifiable = true
  vim.bo[left_buf].readonly = false
  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[right_buf].modifiable = true
  vim.bo[right_buf].readonly = false

  d.diffs = {}
  d.left_buf = left_buf
  d.left_win = nil
  d.right_buf = right_buf
  d.right_win = nil
  return d
end

--- Helper function to get the diff object, focused diff and other diff
---@return Beez.jj.ui.UnifiedDiff.Diff, Beez.jj.ui.DiffBuf, Beez.jj.ui.DiffBuf
function UnifiedDiff:_get_diffs()
  local diff = self.diffs[self.path]
  local curr_diff, other_diff
  if diff.right:is_focused() then
    curr_diff = diff.right
    other_diff = diff.left
  else
    curr_diff = diff.left
    other_diff = diff.right
  end
  return diff, curr_diff, other_diff
end

function UnifiedDiff:_toggle_changes(curr_diff, other_diff, line_changes)
  -- Discard changes from current diff and apply to other diff
  -- We want to discard changes in descending order to not mess up line numbers
  table.sort(line_changes, function(a, b)
    return a.lineno > b.lineno
  end)
  for _, lc in ipairs(line_changes) do
    curr_diff:discard_change(lc.lineno)
  end

  -- We want to apply changes in ascending order to keep line numbers correct
  table.sort(line_changes, function(a, b)
    return a.lineno < b.lineno
  end)
  for _, lc in ipairs(line_changes) do
    other_diff:apply_change(lc)
  end

  -- Move to the next hunk in the current diff
  curr_diff:move_to_hunk(nil, { next = true })
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Focus the left diff
function UnifiedDiff:focus()
  vim.api.nvim_set_current_win(self.left_win)
end

--- Scroll the current diff view by specified number of lines
---@param lines integer
function UnifiedDiff:scroll(lines)
  local diff, _, _ = self:_get_diffs()
  diff.left:scroll(lines)
end

--- Renders unifiied diff for specified filepath
---@param filepath string
---@param cb? fun()
function UnifiedDiff:render(filepath, cb)
  local u = require("Beez.u")
  local DiffBuf = require("Beez.jj.ui.diffbuf")
  local commands = require("Beez.jj.commands")

  -- Create layout if not already created
  if self.left_win == nil or self.right_win == nil then
    vim.cmd("vsplit")
    self.left_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.left_win, self.left_buf)
    vim.cmd("set scrollbind")
    vim.cmd("set cursorbind")
    vim.cmd("set scrollopt=ver,jump")
    vim.cmd("vsplit")
    self.right_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.right_win, self.right_buf)
    vim.cmd("set scrollbind")
    vim.cmd("set cursorbind")
    vim.cmd("set scrollopt=ver,jump")
  end

  self.path = filepath
  local diff = self.diffs[filepath]
  -- Render cached diff if it exists
  if diff ~= nil then
    diff.left:render(filepath, self.left_win, self.left_buf, diff.orig_lines, function()
      diff.right:render(filepath, self.right_win, self.right_buf, diff.orig_lines, function()
        self:move_to_hunk(1, { next = true })
        if cb then
          cb()
        end
      end)
    end)
    return
  end

  -- Rendering diff for the first time
  -- Use jj to get the base version of this file
  commands.file_show(function(err, orig_content)
    if err then
      return
    end

    local orig_lines = vim.split(orig_content, "\n")
    diff = {
      left = DiffBuf.new(),
      right = DiffBuf.new(),
      orig_lines = orig_lines,
      changes = {},
    }

    vim.schedule(function()
      -- Read modified content from file
      local mod_content = u.os.read_file(filepath) or ""
      local mod_lines = vim.split(mod_content, "\n")
      -- Calculate the diff hunks
      local hunks = vim.text.diff(orig_content, mod_content, {
        result_type = "indices",
      })

      local changes = {}
      -- Turn hunk into changes and apply them to the left buffer
      for hi, h in ipairs(hunks) do
        local orig_start, orig_lines_count, mod_start, mod_lines_count = unpack(h)

        -- Original lines will be a delete change
        for i = 0, orig_lines_count - 1 do
          ---@type Beez.jj.ui.Change
          local change = {
            id = #changes + 1,
            status = "D",
            orig = orig_start + i,
            -- Since these are deletes, the lines just get highlighted in place so orgi and mod is the same
            mod = orig_start + i,
            text = orig_lines[orig_start + i],
            hunk = hi,
          }
          table.insert(changes, change)
        end

        -- Modified lines will be an add change
        for i = 0, mod_lines_count - 1 do
          -- Here we want the adds to be after the deletes so mod is how ever many lines the orig took up
          local mod = orig_start + orig_lines_count + i
          -- Minus one if original lines count is not zero? Not sure why
          if orig_lines_count > 0 then
            mod = mod - 1
          end
          ---@type Beez.jj.ui.Change
          local change = {
            id = #changes + 1,
            status = "A",
            orig = orig_start + i,
            mod = mod,
            text = mod_lines[mod_start + i],
            hunk = hi,
          }
          table.insert(changes, change)
        end
      end

      -- Render the 2 diff buffers for the first time
      diff.left:render(filepath, self.left_win, self.left_buf, orig_lines, function()
        -- Cache the diff
        self.diffs[filepath] = diff

        -- Apply all changes to the left
        for _, c in ipairs(changes) do
          diff.left:apply_change(c)
        end

        -- The right gets no changes
        diff.right:render(filepath, self.right_win, self.right_buf, orig_lines, function()
          -- Move cursor to the first hunk
          self:move_to_hunk(1, { next = true })

          if cb then
            cb()
          end
        end)
      end)
    end)
  end, {
    path = filepath,
    r = "@-",
    ignore_err = {
      "No such path",
    },
  })
end

--- Maps default keymaps to the buffer
function UnifiedDiff:map(view)
  local u = require("Beez.u")
  local keymaps = {
    quit = {
      "q",
      function()
        vim.cmd("qa")
      end,
      desc = "Close",
    },
    toggle_changes = {
      mode = { "n", "v" },
      "<space>",
      function()
        self:toggle_changes()
      end,
      desc = "Toggles current hunk or selected lines",
    },
    move_to_next_change_k = {
      "k",
      function()
        self:move_to_hunk(nil, { next = true })
      end,
      desc = "Move to next hunk",
    },
    move_to_prev_change_j = {
      "j",
      function()
        self:move_to_hunk(nil, { prev = true })
      end,
      desc = "Move to previous hunk",
    },
    move_to_next_change_l = {
      "l",
      function()
        self:move_to_hunk(nil, { next = true })
      end,
      desc = "Move to next hunk",
    },
    move_to_prev_change_h = {
      "h",
      function()
        self:move_to_hunk(nil, { prev = true })
      end,
      desc = "Move to previous hunk",
    },
    focus_tree = {
      "<esc>",
      function()
        view:focus_tree()
      end,
      desc = "Focus the status tree",
    },
    focus_other_diff = {
      "<tab>",
      function()
        local _, _, other_diff = self:_get_diffs()
        other_diff:focus()
        other_diff:move_to_hunk(nil, { next = true })
      end,
      desc = "Focus the other diff buffer",
    },
  }
  for _, k in pairs(keymaps) do
    local left_keymap = vim.tbl_deep_extend("keep", { buffer = self.left_buf }, k)
    local right_keymap = vim.tbl_deep_extend("keep", { buffer = self.right_buf }, k)
    u.keymaps.set({ left_keymap, right_keymap })
  end
end

--- Toggles hunk on the current line or selected lines
function UnifiedDiff:toggle_changes()
  local diff, curr_diff, other_diff = self:_get_diffs()
  if diff == nil then
    return
  end

  local lineno = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]
  local line_change = curr_diff:get(lineno)
  if line_change == nil then
    return
  end

  local line_changes = {}
  local mode = vim.fn.mode()

  -- Get changes for selected lines
  if mode == "v" or mode == "V" or mode == "\22" then
    local u = require("Beez.u")
    local s, e = u.nvim.get_visual_selection_row_range()
    for i = s, e do
      local lc = curr_diff:get(i)
      if lc ~= nil then
        table.insert(line_changes, lc)
      end
    end

  -- If nothing is selected get changes for the entire hunk
  else
    line_changes = curr_diff:list({ hunk = line_change.hunk })
  end

  -- Discard changes from current diff and apply to other diff
  -- We want to discard changes in descending order to not mess up line numbers
  table.sort(line_changes, function(a, b)
    return a.lineno > b.lineno
  end)
  for _, lc in ipairs(line_changes) do
    curr_diff:discard_change(lc.lineno)
  end

  -- We want to apply changes in ascending order to keep line numbers correct
  table.sort(line_changes, function(a, b)
    return a.lineno < b.lineno
  end)
  for _, lc in ipairs(line_changes) do
    other_diff:apply_change(lc)
  end

  -- Move to the next hunk in the current diff
  curr_diff:move_to_hunk(nil, { next = true })
end

--- Toggle all the changes on the left diff for specific file
---@param filepath string
function UnifiedDiff:toggle_file_changes(filepath)
  local diff = self.diffs[filepath]
  if diff == nil then
    return
  end

  -- Toggle all changes on the left if there are any
  local line_changes = diff.left:list()
  local curr_diff, other_diff = diff.left, diff.right
  -- Toggle all changes on the right instead
  if #line_changes == 0 then
    line_changes = diff.right:list()
    curr_diff, other_diff = diff.right, diff.left
  end
  self:_toggle_changes(curr_diff, other_diff, line_changes)
  self:move_to_hunk(1, { next = true })
end

--- Move to a hunk in current diff buffer
---@param lineno? integer
---@param opts {next?: boolean, prev?: boolean}
function UnifiedDiff:move_to_hunk(lineno, opts)
  local _, curr_diff, other_diff = self:_get_diffs()
  if curr_diff == nil then
    return
  end

  local line_changes = curr_diff:list()
  -- Try to manually sync the windows after move to hunk
  if #line_changes > 0 then
    local ln = curr_diff:move_to_hunk(lineno, opts)
    pcall(vim.api.nvim_win_set_cursor, other_diff.win, { ln, 0 })
  else
    local ln = other_diff:move_to_hunk(lineno, opts)
    pcall(vim.api.nvim_win_set_cursor, curr_diff.win, { ln, 0 })
  end
end

return UnifiedDiff
