local op = require("Beez.cmdcenter.outputs")
local u = require("Beez.u")
local M = {
  bufcache = {},
}

--- Gets the header row in db output
---@param name? string
---@return string
function M.get_header(name)
  local header = op.header(name)
  if header ~= nil then
    return header
  end

  local bufnr = op.bufnr(name)
  header = vim.fn.getbufline(bufnr, 1, 1)[1]
  op.header(name, header)
  return header
end

--- Get the header values for the current row where cursor is at
---@return string[]
function M.get_header_values()
  local winid = op.winid()
  local pos = vim.api.nvim_win_get_cursor(winid)
  local row = vim.fn.getbufline(op.bufnr(), pos[1], pos[1])[1]
  local values = {}
  for _, word in ipairs(vim.fn.split(row, "|")) do
    table.insert(values, word:trim():trimr())
  end
  return values
end

--- Gets the list of headers in db output buffer
---@return string[]
function M.get_headers(name)
  local headers = op.headers(name)
  if headers ~= nil then
    return headers
  end

  local header = M.get_header(name)
  headers = {}
  for _, word in ipairs(vim.fn.split(header, "|")) do
    table.insert(headers, word:trim():trimr())
  end
  op.headers(name, headers)
  return headers
end

--- Gets the list of header positions
---@return string[]
function M.get_header_pos(name)
  local header_pos = op.header_pos(name)
  if header_pos ~= nil then
    return header_pos
  end

  local header = M.get_header(name)
  header_pos = {}
  local i = 1
  while true do
    local s, _ = string.find(header, "| ", i)
    if s == nil then
      break
    end
    table.insert(header_pos, s)
    i = s + 1
  end
  return header_pos
end

--- Move cursor to the specific header column
---@param matching_header string
function M.move_to_header(matching_header)
  local winid = op.winid()
  local pos = vim.api.nvim_win_get_cursor(winid)
  local header = M.get_header()
  local res = vim.fn.matchstrpos(header, " " .. matching_header .. " ", 1, 1)
  vim.api.nvim_win_set_cursor(winid, { pos[1], res[2] + 1 })
  vim.cmd("normal! zszH")
end

--- Move cursor to the next header column
function M.move_to_next_header()
  local winid = op.winid()
  local header_pos = M.get_header_pos()
  local pos = vim.api.nvim_win_get_cursor(winid)
  for _, s in ipairs(header_pos) do
    if s > pos[2] then
      vim.api.nvim_win_set_cursor(winid, { pos[1], s + 1 })
      vim.cmd("normal! zszH")
      return
    end
  end
end

--- Move cursor to the previous header column
function M.move_to_prev_header()
  local winid = op.winid()
  local header_pos = M.get_header_pos()
  local pos = vim.api.nvim_win_get_cursor(winid)
  for i = 1, #header_pos do
    local s = header_pos[#header_pos - i + 1]
    if s + 1 < pos[2] then
      vim.api.nvim_win_set_cursor(winid, { pos[1], s + 1 })
      vim.cmd("normal! zszH")
      return
    end
  end
end

--- Setup statuscolumn for the window to display the row id for db results
---@param winid integer
function M.set_row_id_status_column(winid)
  local statuscolumn = "%!v:lua.Cmdcenter.statuscolumn()"
  vim.api.nvim_set_option_value("statuscolumn", statuscolumn, { win = winid, scope = "local" })
end

--- Sets a virtual line header for column headers in the buffer
---@param bufnr integer
function M.set_header_virtual_line(bufnr)
  local header = vim.fn.getline(1)
  local vt_namespace = vim.api.nvim_create_namespace("CmdcenterVt")
  local autocmd_group = vim.api.nvim_create_augroup("CmdcenterOutput", { clear = true })
  local events = require("nui.utils.autocmd").event
  local top_line = 1
  vim.api.nvim_create_autocmd({ events.CursorMoved, events.CursorMovedI }, {
    group = autocmd_group,
    buffer = bufnr,
    callback = function(event)
      local new_top_line = vim.fn.line("w0")
      if new_top_line == top_line then
        return
      end

      top_line = new_top_line
      vim.api.nvim_buf_clear_namespace(bufnr, vt_namespace, 0, -1)
      vim.schedule(function()
        if top_line > 1 then
          vim.api.nvim_buf_set_extmark(bufnr, vt_namespace, top_line - 1, 0, {
            virt_lines = { { { header, "Search" } } },
            virt_lines_overflow = "scroll",
          })
        end
      end)
    end,
  })
end

--- Sets keymaps on db output buffer
---@param bufnr integer
function M.set_keymaps(bufnr)
  u.keymaps.set({
    {
      "q",
      function()
        op.close()
      end,
      desc = "Close",
      buffer = bufnr,
    },
    {
      "\\",
      function()
        require("Beez.pickers").pick("cmdcenter.db_headers", { type = "deck" })
      end,
      desc = "Go to header",
      buffer = bufnr,
    },
    {
      "<right>",
      function()
        M.move_to_next_header()
      end,
      desc = "Go to next header",
      buffer = bufnr,
    },
    {
      "<left>",
      function()
        M.move_to_prev_header()
      end,
      desc = "Go to previous header",
      buffer = bufnr,
    },
    {
      "o",
      function()
        local cc = require("Beez.cmdcenter")
        cc.edit_cmd()
      end,
      desc = "Edit current command",
      buffer = bufnr,
    },
  })
end

--- Default hook for on_output_open for commands with db tag
---@param cmd Beez.cmdcenter.cmd
---@param winid integer
---@param bufnr integer
function M.def_on_output_open_hook(cmd, winid, bufnr)
  M.set_row_id_status_column(winid)
  M.set_header_virtual_line(bufnr)
  M.set_keymaps(bufnr)
end

return M
