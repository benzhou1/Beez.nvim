---@class Beez.jj.ui.DiffBuf.LineChange: Beez.jj.ui.Change
---@field lineno integer

---@class Beez.jj.ui.DiffBuf
---@field line_changes table<integer, Beez.jj.ui.DiffBuf.LineChange>
---@field win integer
---@field buf integer
---@field filepath string
---@field ns_id integer
DiffBuf = {}
DiffBuf.__index = DiffBuf

--- Instantiates a new DiffBuf
---@return Beez.jj.ui.DiffBuf
function DiffBuf.new()
  local d = {}
  setmetatable(d, DiffBuf)

  d.line_changes = {}
  d.buf = nil
  d.win = nil
  d.ns_id = nil
  return d
end

--- Convenient function to convert LineChangeIn to LineChange
---@param change Beez.jj.ui.Change
---@param lineno integer
---@return Beez.jj.ui.DiffBuf.LineChange
local function to_line_change(change, lineno)
  local line_change = vim.tbl_deep_extend("keep", { lineno = lineno }, change)
  return line_change
end

--- Apply change to the buffer
---@param change Beez.jj.ui.DiffBuf.LineChange
function DiffBuf:_apply_change(change)
  local lineno0 = change.lineno - 1
  if change.status == "D" then
    vim.api.nvim_buf_set_extmark(self.buf, self.ns_id, lineno0, 0, {
      line_hl_group = "DiffDelete",
    })

  -- If change is an add we need to insert the line and highlight it
  elseif change.status == "A" then
    vim.api.nvim_buf_set_lines(self.buf, lineno0, lineno0, false, { change.text })
    pcall(vim.api.nvim_buf_set_extmark, self.buf, self.ns_id, lineno0, 0, {
      line_hl_group = "DiffAdd",
    })
  end
end

-----------------------------------------------------------------------------------------------
--- STATE
-----------------------------------------------------------------------------------------------
--- Gets the change on a specific line
---@param lineno? integer
---@param opts? {next?: boolean, prev?: boolean, hunk?: boolean}
---@return Beez.jj.ui.DiffBuf.LineChange?
function DiffBuf:get(lineno, opts)
  opts = opts or {}
  lineno = lineno or vim.api.nvim_win_get_cursor(0)[1]
  local not_hunk = nil
  local lc = self.line_changes[lineno]
  if lc ~= nil then
    if opts.hunk ~= nil then
      not_hunk = lc.hunk
    end
  end

  if opts.next then
    -- Get all changes from next hunks
    local local_changes = self:list({ gt_lineno = lineno, not_hunk = not_hunk, sort = "ascending" })
    if #local_changes > 0 then
      -- Get the first change from the next closest hunk
      lc = local_changes[1]
    end
  elseif opts.prev then
    -- Get all changes from previous hunks
    local local_changes = self:list({ lt_lineno = lineno, not_hunk = not_hunk, sort = "descending" })
    if #local_changes > 0 then
      lc = local_changes[1]
      -- Get all changes from the previous closest hunk
      local_changes = self:list({ lt_lineno = lineno, hunk = lc.hunk, sort = "ascending" })
      -- Get the first change from that hunk
      lc = local_changes[1]
    end
  end
  return lc
end

--- Get list of changes based on filters
---@param opts? {hunk?: integer, not_hunk?: integer, gt_lineno?: integer, lt_lineno?: integer, sort?: "ascending"|"descending"}
---@return Beez.jj.ui.DiffBuf.LineChange[]
function DiffBuf:list(opts)
  opts = opts or {}
  local line_changes = {}
  for ln, lc in pairs(self.line_changes) do
    local ok = true
    if opts.hunk ~= nil then
      if opts.hunk ~= lc.hunk then
        ok = false
      end
    end
    if opts.not_hunk ~= nil then
      if opts.not_hunk == lc.hunk then
        ok = false
      end
    end

    if opts.gt_lineno ~= nil then
      if ln <= opts.gt_lineno then
        ok = false
      end
    end
    if opts.lt_lineno ~= nil then
      if ln >= opts.lt_lineno then
        ok = false
      end
    end
    if ok then
      table.insert(line_changes, lc)
    end
  end

  if opts.sort == "ascending" then
    table.sort(line_changes, function(a, b)
      return a.lineno < b.lineno
    end)
  elseif opts.sort == "descending" then
    table.sort(line_changes, function(a, b)
      return a.lineno > b.lineno
    end)
  end

  return line_changes
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Focus the current buf
function DiffBuf:focus()
  vim.api.nvim_set_current_win(self.win)
end

--- Checks if the current buf is focused
---@return boolean
function DiffBuf:is_focused()
  return self.win == vim.api.nvim_get_current_win()
end

--- Move cursor to next or previous hunk
---@param lineno? integer
---@param opts {next?: boolean, prev?: boolean}
---@return integer|nil
function DiffBuf:move_to_hunk(lineno, opts)
  local lc = self:get(lineno, { next = opts.next, prev = opts.prev, hunk = true })
  if lc == nil then
    return
  end

  vim.api.nvim_win_set_cursor(self.win, { lc.lineno, 0 })
  vim.api.nvim_win_call(self.win, function()
    vim.cmd("normal! zz")
  end)
  return lc.lineno
end

--- Scroll the current buffer by specified number of lines
---@param lines integer
function DiffBuf:scroll(lines)
  pcall(vim.api.nvim_win_set_cursor, self.win, {
    vim.api.nvim_win_get_cursor(self.win)[1] + lines,
    0,
  })
  vim.api.nvim_win_call(self.win, function()
    vim.cmd("normal! zz")
  end)
end

--- Renders the current file contents
---@param filepath string
---@param win integer
---@param buf integer
---@param lines string[]
---@param cb? fun()
function DiffBuf:render(filepath, win, buf, lines, cb)
  self.win = win
  self.buf = buf
  if self.ns_id == nil then
    self.ns_id = vim.api.nvim_create_namespace("Beez.jj.DiffBuf" .. buf)
  end

  vim.api.nvim_buf_clear_namespace(self.buf, self.ns_id, 0, -1)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].filetype = vim.filetype.match({ filename = filepath }) or "text"
  vim.api.nvim_win_set_buf(self.win, self.buf)
  -- Apply changes
  local line_changes = self:list({ sort = "ascending" })
  for _, lc in pairs(line_changes) do
    self:_apply_change(lc)
  end
  if cb then
    cb()
  end
end

--- Discards the change on the specified line
---@param lineno integer
function DiffBuf:discard_change(lineno)
  local line_change = self:get(lineno)
  if line_change == nil then
    return
  end

  -- Remove line change tracking
  self.line_changes[lineno] = nil

  local lineno0 = lineno - 1
  -- Get all extmarks on the line
  local extmarks = vim.api.nvim_buf_get_extmarks(
    self.buf,
    self.ns_id,
    { lineno0, 0 },
    { lineno0, -1 },
    {}
  )

  -- Remove each extmark
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(self.buf, self.ns_id, extmark[1])
  end

  -- If change is a delete no need to do anything just remove the highlight
  -- If change is an add we need to remove the line and the highlight
  if line_change.status == "A" then
    vim.api.nvim_buf_set_lines(self.buf, lineno0, lineno0 + 1, false, {})

    -- Since line has been removed we need to update the line numbers of subsequent changes
    local new_line_changes = {}
    for ln, lc in pairs(self.line_changes) do
      if ln > lineno then
        new_line_changes[ln - 1] = lc
        lc.lineno = ln - 1
      else
        new_line_changes[ln] = lc
      end
    end
    self.line_changes = new_line_changes
  end
end

--- Applies a change
---@param change Beez.jj.ui.Change
function DiffBuf:apply_change(change)
  -- 0 based line number
  local lineno = change.orig

  -- Calculate line offset based on previous hunks
  for _, lc in pairs(self.line_changes) do
    if lc.hunk < change.hunk and lc.status == "A" then
      lineno = lineno + 1
    end
    if lc.hunk == change.hunk and lc.orig < change.orig and lc.status ~= change.status then
      lineno = lineno + 1
    end
  end
  -- If change is a delete no need to do anything just highlight the line
  if change.status == "D" then
    local line_change = to_line_change(change, lineno)
    self:_apply_change(line_change)
    -- Track new line change
    self.line_changes[lineno] = line_change

  -- If change is an add we need to insert the line and highlight it
  elseif change.status == "A" then
    -- Since line is being inserted increase the lineno
    lineno = lineno + 1
    local line_change = to_line_change(change, lineno)
    self:_apply_change(line_change)
    -- Since line has been inserted we need to update the line numbers of subsequent changes
    local new_line_changes = {}
    for ln, lc in pairs(self.line_changes) do
      if ln >= lineno then
        new_line_changes[ln + 1] = lc
        lc.lineno = ln + 1
      else
        new_line_changes[ln] = lc
      end
    end
    self.line_changes = new_line_changes

    -- Track new line change
    self.line_changes[lineno] = line_change
  end
end

return DiffBuf
