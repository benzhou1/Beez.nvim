local M = {}

--- Get visual selection info
---@return {pos: integer[], end_pos: integer[], text: string}?
function M.get_visual()
  local modes = { "v", "V", vim.api.nvim_replace_termcodes("<c-v>", true, true, true) }
  local mode = vim.fn.mode():sub(1, 1) ---@type string
  if not vim.tbl_contains(modes, mode) then return end

  local pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")

  -- for some reason, sometimes the column is off by one
  -- see: https://github.com/folke/snacks.nvim/issues/190
  local col_to =
    math.min(end_pos[2] + 1, #vim.api.nvim_buf_get_lines(0, end_pos[1] - 1, end_pos[1], false)[1])

  local lines = vim.api.nvim_buf_get_text(0, pos[1] - 1, pos[2], end_pos[1] - 1, col_to, {})
  local text = table.concat(lines, "\n")
  local ret = {
    pos = pos,
    end_pos = end_pos,
    text = text,
  }
  return ret
end

--- Get the text that is selected
---@return string
function M.get_visual_selection()
  local modes = { "v", "V", vim.api.nvim_replace_termcodes("<c-v>", true, true, true) }
  local mode = vim.fn.mode():sub(1, 1) ---@type string
  if not vim.tbl_contains(modes, mode) then return "" end

  return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos(".")), "\n")
end

--- Get the row range of the visual selection
---@return integer, integer
function M.get_visual_selection_row_range()
  local start_row = vim.fn.getpos("v")[2]
  local end_row = vim.fn.getpos(".")[2]
  return math.min(start_row, end_row), math.max(end_row, start_row)
end

--- Get the col range of the visual selection
---@return integer, integer
function M.get_visual_selection_col_range()
  local start_col = vim.fn.getpos("v")[3]
  local end_col = vim.fn.getpos(".")[3]
  return math.min(start_col, end_col), math.max(start_col, end_col)
end

-- switching buffers and opening 'buffers' in quick succession
-- can lead to incorrect sort as 'lastused' isn't updated fast
-- enough (neovim bug?), this makes sure the current buffer is
-- always on top (#646)
-- Hopefully this gets solved before the year 2100
-- DON'T FORCE ME TO UPDATE THIS HACK NEOVIM LOL
-- NOTE: reduced to 2038 due to 32bit sys limit (#1636)
local _FUTURE = os.time({ year = 2038, month = 1, day = 1, hour = 0, minute = 00 })
function M.get_unixtime(buf)
  if tonumber(buf) then
    -- When called from `buffer_lines`
    buf = vim.api.nvim_buf_get_info(buf)
  end
  if buf.flag == "%" then
    return _FUTURE
  elseif buf.flag == "#" then
    return _FUTURE - 1
  else
    return buf.lastused or buf.info.lastused
  end
end

--- Sort buffers by lastused with fzf lua hack
---@param bufnrs table[int]
---@return table[int]
function M.sort_bufs_by_lastused(bufnrs)
  -- Sort buffers by lastused with fzf lua hack
  table.sort(bufnrs, function(a, b) return M.get_unixtime(a) > M.get_unixtime(b) end)
  return bufnrs
end

--- Check whether buffer is valid based on specific criterias
---@param buf integer
---@param opts? { hidden: boolean, unloaded: boolean, current: boolean, nofile: boolean, modified: boolean }
---@return boolean
function M.valid_buf(buf, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    hidden = false,
    unloaded = true,
    current = true,
    nofile = false,
  })
  local current_buf = vim.api.nvim_get_current_buf()
  local acceptable = true
  acceptable = acceptable
    and (opts.nofile or vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "nofile")
  acceptable = acceptable and (opts.hidden or vim.bo[buf].buflisted)
  acceptable = acceptable and (opts.unloaded or vim.api.nvim_buf_is_loaded(buf))
  acceptable = acceptable and (not opts.current or buf ~= current_buf)
  acceptable = acceptable and (not opts.modified or vim.bo[buf].modified)
  return acceptable
end

return M
