local Buflist = require("Beez.bufswitcher.buflist")
local c = require("Beez.bufswitcher.config")
local u = require("Beez.u")

---@class Beez.bufswitcher
---@field config Beez.bufswitcher.config
---@field bl Beez.bufswitcher.buflist
---@field displayed_bufs integer[]
---@field pinned_paths string[]
---@field curr_buf integer?
---@field buf integer?
---@field win integer?
---@field p? NuiPopup
---@field autocmd_group string
---@field ns_group string
---@field mapped_keys table<string, {buffer?: integer, clean?: boolean}>
---@field pins_file_path Path
local M = {
  config = {},
  pinned_paths = {},
  curr_buf = nil,
  buf = nil,
  win = nil,
  p = nil,
  autocmd_group = "autocmd.Beez.bufswitcher.buflist",
  ns_group = "nsid.Beez.bufswitcher.buflist",
  stay_opened = false,
  mapped_keys = {},
  displayed_bufs = {},
  available_chars = {},
}

--- Setup keymaps and user nvim_create_user_command
---@param opts Beez.bufswitcher.config
function M.setup(opts)
  opts = vim.tbl_deep_extend("keep", {}, opts or {})
  c.init(opts)
  M.config = c.config
  M.bl = Buflist:new()
  M.timeoutlen = vim.o.timeoutlen
  M.pins_file_path = u.paths.Path:new(M.config.pins_path)
  M.pinned_paths = {}

  local pinned_paths = M.pins_file_path:readlines()
  -- Filter out empty lines
  for _, l in ipairs(pinned_paths) do
    if l ~= "" then
      table.insert(M.pinned_paths, l)
    end
  end

  -- Create a map of available chars
  local pick_chars = c.config.keymaps.pick_chars
  assert(pick_chars, "pick_chars must be set in config.keymaps.pick_chars")
  for i = 1, #pick_chars do
    local char = pick_chars:sub(i, i)
    M.available_chars[char] = true
  end
end

--- Default file name to be displayed
---@param buf Beez.bufswitcher.buf
---@param names table<string, boolean>
---@return string
local function def_filename(buf, names)
  return buf.basename
end

--- Default dir name to be displayed
---@param buf Beez.bufswitcher.buf
---@param filename string
---@param display_names table<string, boolean>
---@return string
local function def_dirname(buf, filename, display_names)
  local parts = vim.fn.split(buf.dirname, u.paths.sep)

  local i = 0
  local dirname = parts[#parts]
  local display_name = filename .. " " .. dirname
  while display_names[display_name] do
    i = i + 1
    dirname = parts[#parts - i]
    display_name = filename .. " " .. dirname
  end
  return dirname
end

--- Check if no-neck-pain is enabled
---@return boolean
local function noneckpain_enabled()
  if c.config.win.use_noneckpain then
    local ok, state = pcall(require, "no-neck-pain.state")
    if ok then
      local nnp_enabled = state.has_tabs(state) and state.is_active_tab_registered(state)
      return nnp_enabled
    end
  end
  return false
end

--- Clean up autocmds
local function clean_autocmds()
  -- Clear the autocmds for this buflist
  pcall(vim.api.nvim_del_augroup_by_name, M.autocmd_group)

  if not M.stay_opened and M.p then
    M.p:off("BufLeave")
  end
end

local function create_autocmds()
  local group = vim.api.nvim_create_augroup(M.autocmd_group, { clear = true })
  local events = require("nui.utils.autocmd").event
  local nnp_enabled = noneckpain_enabled()

  if nnp_enabled or M.stay_opened then
    -- Create an autocmd to refresh the buffer list when a buffer is added or removed
    vim.api.nvim_create_autocmd({ events.BufAdd, events.BufDelete, events.BufEnter }, {
      group = group,
      callback = function(event)
        if M.is_open() and event.buf ~= M.buf and event.file ~= "" then
          local valid_buf_enter = c.config.autocmds.valid_buf_enter
          if valid_buf_enter then
            if not valid_buf_enter(event) then
              return
            end
          end
          if event.event == events.BufEnter then
            -- If the buffer is entered, update the current buffer
            M.curr_buf = event.buf
          end
          M.update()
        end
      end,
    })
  end

  -- Create an autocmd to cleanup buflist when window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(M.win),
    callback = function(event)
      ---@diagnostic disable-next-line: undefined-field
      if event.winid == M.win then
        M.close()
      end
    end,
  })

  -- Unmount the popup when cursor leaves the buffer
  if not M.stay_opened and not nnp_enabled then
    M.p:on("BufLeave", function()
      M.close()
    end)
  end

  -- Create automcmd to set and restore timeoutlen on entering and leaving the buflist
  if M.stay_opened or nnp_enabled then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      buffer = M.buf,
      callback = function()
        M.timeoutlen = vim.o.timeoutlen
        vim.opt.timeoutlen = 1
      end,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
      group = group,
      buffer = M.buf,
      callback = function()
        vim.opt.timeoutlen = M.timeoutlen
      end,
    })
  end
end

--- Map keys to the buffer list
local function map_keys()
  -- Map to enter to select
  M.map({
    "<CR>",
    function()
      local lineno = vim.api.nvim_win_get_cursor(0)[1]
      local bidx = M.displayed_bufs[lineno]
      local buf = M.bl:get({ idx = bidx })
      M.open_buf(buf)
    end,
    buffer = M.buf,
  })

  -- Map to delete buffer
  local del_key = c.config.keymaps.del_buf
  if del_key then
    M.map({
      del_key,
      function()
        local lineno = vim.api.nvim_win_get_cursor(0)[1]
        local bidx = M.displayed_bufs[lineno]
        local buf = M.bl:get({ idx = bidx })

        -- Clear the line
        vim.api.nvim_buf_set_lines(M.buf, lineno - 1, lineno, false, {})
        if buf and vim.api.nvim_buf_is_valid(buf.id) then
          -- Dont trigger autocommand since we already updated the list
          vim.cmd("noautocmd bdelete " .. buf.id)
          M.bl:remove({ idx = bidx })
        end
      end,
      buffer = M.buf,
    })
  end

  -- Map to pin buffer
  local pin_key = c.config.keymaps.pin_buf
  if pin_key then
    M.map({
      pin_key,
      function()
        local lineno = vim.api.nvim_win_get_cursor(0)[1]
        local bidx = M.displayed_bufs[lineno]
        local buf = M.bl:get({ idx = bidx })
        if buf then
          M.toggle_pin(buf)
          M.update({ set_cursor = lineno })
        end
      end,
      buffer = M.buf,
    })
  end
end

--- Clear keys for the buffer list
function M.clear_keys()
  for k, kd in pairs(M.mapped_keys) do
    if kd.clean then
      u.keymaps.unset({ k, buffer = kd.buffer })
    end
  end
  M.mapped_keys = {}
end

--- Toggles pin status of a buffer
---@param buf Beez.bufswitcher.buf
function M.toggle_pin(buf)
  if buf.pinned then
    M.unpin(buf)
  else
    M.pin(buf)
  end
end

--- Pin a buffer
---@param buf Beez.bufswitcher.buf
function M.pin(buf)
  if buf.pinned then
    return
  end

  buf:set_pinned(#M.pinned_paths + 1)
  table.insert(M.pinned_paths, buf.path)
  -- Save the pins to file
  M.pins_file_path:write(buf.path .. "\n", "a")
end

--- Unpin a buffer
---@param buf Beez.bufswitcher.buf
function M.unpin(buf)
  if not buf.pinned then
    return
  end

  u.tables.remove(M.pinned_paths, buf.path)
  buf:unset_pinned()

  -- Save the pins to file
  local lines = table.concat(M.pinned_paths, "\n")
  M.pins_file_path:write(lines, "w")
end

--- Map keys for the buffer list
---@param key_def table
---@param opts? {clean?: boolean}
function M.map(key_def, opts)
  opts = opts or {}
  if type(key_def[1]) == "string" then
    key_def = { key_def }
  end

  for _, k in ipairs(key_def) do
    M.mapped_keys[k[1]] = {
      buffer = k.buffer,
      clean = opts.clean,
    }
  end
  u.keymaps.set(key_def)
end

--- Opens a buffer by path
---@param buf Beez.bufswitcher.buf
function M.open_buf(buf)
  if not M.buf then
    return
  end

  if not M.stay_opened then
    M.close()
  end

  vim.schedule(function()
    require("plugins.noneckpain").return_to_main_win()
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, _ = pcall(vim.cmd, "e " .. buf.path)
    if not ok then
      local b = M.bl:get({ idx = 1 })
      if b then
        vim.cmd("e " .. b.path)
      end
    end
  end)
end

--- Check to see if popup is open
---@return boolean
function M.is_open()
  if noneckpain_enabled() then
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) or not vim.api.nvim_win_is_valid(M.win) then
      return false
    end
    return true
  end

  if not M.p or not M.p.winid or not M.p.bufnr then
    return false
  end
  return true
end

--- Close the popup
function M.close()
  clean_autocmds()
  M.clear_keys()

  -- If no-neck-pain is enabled
  -- Just clean up the buffer and return to main window since we dont want to close nnp
  if noneckpain_enabled() and M.buf then
    require("plugins.noneckpain").return_to_main_win()
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {})

  -- Clean up the poopup
  elseif M.p then
    M.p:unmount()
    M.p = nil
    vim.opt.timeoutlen = M.timeoutlen
  end

  M.buf = nil
  M.win = nil
end

--- Show the popup
---@param opts? {focus?: boolean}
function M.show(opts)
  opts = opts or {}
  -- Make sure buflist is cleaned up if its not showing
  if not M.is_open() then
    M.close()
  end
  -- Save the current buffer before activating the buflist
  M.curr_buf = vim.api.nvim_get_current_buf()

  --- Focus the buflist
  local function focus_buflist()
    vim.api.nvim_set_current_win(M.win)
    for i, bidx in ipairs(M.displayed_bufs) do
      local buf = M.bl:get({ idx = bidx })
      -- Move cursor to the current buffer
      if buf and buf.id == M.curr_buf then
        vim.api.nvim_win_set_cursor(M.win, { i, 0 })
        return
      end
    end
  end

  -- If no-neck-pain is enabled, use its left buffer instead of float
  if noneckpain_enabled() then
    if M.buf == nil then
      M.stay_opened = true
      local state = require("no-neck-pain.state")
      M.win = state:get_side_id("left")
      M.buf = vim.api.nvim_win_get_buf(M.win)

      M.update()
      map_keys()
      create_autocmds()
    end
    if opts.focus ~= false then
      focus_buflist()
    end
    return
  end

  -- Use float popup
  if not M.p then
    local popup_opts = c.config.win.popup
    if c.config.win.get_popup_opts then
      popup_opts = c.config.win.get_popup_opts()
    end
    assert(popup_opts, "popup_opts must be set in config.win.popup or config.win.get_popup_opts")

    M.p = require("nui.popup")(popup_opts)
    M.p:mount()
    M.buf = M.p.bufnr
    M.win = M.p.winid
    -- Allows you to dynically change stay opened
    ---@diagnostic disable-next-line: undefined-field
    M.stay_opened = popup_opts.stay_opened or false

    M.update()
    map_keys()
    create_autocmds()

    -- Temporarily disable timeoutlen to allow for quick key presses
    vim.opt.timeoutlen = 1
  else
    if opts.focus ~= false then
      focus_buflist()
    end
  end
end

--- Update the buffer list
---@param opts? {first_char?: string, set_cursor?: integer}
function M.update(opts)
  opts = opts or {}
  if not M.is_open() then
    return
  end
  -- Create a map of pinned paths
  local pins = {}
  for i, p in ipairs(M.pinned_paths) do
    pins[p] = i
  end

  M.bl:refresh({ pins = pins, curr_buf = M.curr_buf })
  local bufs = M.bl:list({ first_char = opts.first_char })

  if opts.first_char then
    -- If only one buffer, open it directly
    if #bufs == 1 then
      M.open_buf(bufs[1])
      return
    end
    -- If two buffers, but one of them is the current buffer, open the other one
    if #bufs == 2 then
      for i, b in ipairs(bufs) do
        local current = M.curr_buf == b.id
        if current then
          local buf = i == 1 and bufs[2] or bufs[1]
          M.open_buf(buf)
          return
        end
      end
    end
  end

  M.displayed_bufs = {}
  local texts = {}
  local filenames = {}
  local display_names = {}
  local picked_chars = {}
  local ns_id = vim.api.nvim_create_namespace(M.ns_group)
  local current_buf_i = 1
  local line_idx = 1

  vim.api.nvim_buf_clear_namespace(M.buf, ns_id, 0, -1)
  M.clear_keys()

  --- Returns filename to be displayed
  ---@param b Beez.bufswitcher.buf
  ---@return string
  local function calculate_filename(b)
    local filename = b.basename
    if c.config.hooks.get_filename then
      filename = c.config.hooks.get_filename(b, filenames)
    else
      filename = def_filename(b, filenames)
    end
    filenames[filename] = true
    return filename
  end

  --- Calculate directory name to be displayed
  ---@param b Beez.bufswitcher.buf
  ---@param filename string
  ---@return string
  local function calculate_dirname(b, filename)
    local dirname = b.dirname
    if c.config.hooks.get_dirname then
      dirname = c.config.hooks.get_dirname(b, filename, display_names)
    else
      dirname = def_dirname(b, filename, display_names)
    end
    local display_name = filename .. " " .. dirname
    display_names[display_name] = true
    return dirname
  end

  --- Renders col with pinned char and icon
  ---@param line table
  ---@param b Beez.bufswitcher.buf
  local function render_pinned(line, b, i)
    if b.pinned then
      local pin_char = c.config.keymaps.pinned_chars[i] or i
      table.insert(line, "📌")
      table.insert(line, { pin_char, c.config.ui.highlights.pin_char })

      -- Add keymap to open pinned buffers
      M.map({
        pin_char,
        function()
          M.open_buf(b)
        end,
        buffer = M.buf,
      })
    else
      table.insert(line, "   ")
    end
  end

  --- Render char for the current buffer
  ---@param line table
  ---@param b Beez.bufswitcher.buf
  local function render_current(line, b)
    if b.current then
      table.insert(line, "»")
    end
  end

  --- Render index char for the buffer
  ---@param line table
  ---@param b Beez.bufswitcher.buf
  local function render_index_char(line, b)
    if not opts.first_char then
      local index_char = c.config.keymaps.index_chars[b.idx]
      if index_char ~= "" and index_char then
        table.insert(line, { index_char, c.config.ui.highlights.index_char })
        -- Map chars to open buffer at index
        M.map({
          index_char,
          function()
            M.open_buf(b)
          end,
          buffer = M.buf,
        })
      elseif not b.current then
        table.insert(line, " ")
      end
    elseif not b.current then
      table.insert(line, " ")
    end
  end

  --- Renders the filename and dirname for the first char view
  ---@param line table
  ---@param b Beez.bufswitcher.buf
  ---@param filename string
  ---@param dirname string
  local function render_first_char_buf(line, b, filename, dirname)
    if not opts.first_char then
      return
    end

    local picked_char = nil
    for _i = 1, #filename do
      local char = filename:sub(_i, _i)
      if
        M.available_chars[char]
        and not picked_chars[char]
        and picked_char == nil
        and filename ~= "init.lua"
        and not b.current
      then
        table.insert(line, { char, c.config.ui.highlights.char_label })
        picked_char = char
        picked_chars[char] = true
      else
        table.insert(line, { char, c.config.ui.highlights.filename })
      end
    end

    table.insert(line, " ")

    -- Highlight the first available character in dirname
    if picked_char ~= nil then
      table.insert(line, { dirname, c.config.ui.highlights.dirname })
    else
      for _i = 1, #dirname do
        local char = dirname:sub(_i, _i)
        if
          M.available_chars[char]
          and not picked_chars[char]
          and picked_char == nil
          and not b.current
        then
          table.insert(line, { char, c.config.ui.highlights.char_label })
          picked_char = char
          picked_chars[char] = true
        else
          table.insert(line, { char, c.config.ui.highlights.dirname })
        end
      end
    end

    -- Add unique keymap for each buffer
    if picked_char ~= nil then
      M.map({
        picked_char,
        function()
          M.open_buf(b)
        end,
        buffer = M.buf,
      }, { clean = true })
    end

    -- Add keymap for go back to showing all buffers
    M.map({
      "<Esc>",
      function()
        M.update()
      end,
      buffer = M.buf,
    })
  end

  --- Renders the filename and dirname for the normal view
  ---@param line table
  ---@param filename string
  ---@param dirname string
  local function render_normal_view(line, b, filename, dirname)
    if opts.first_char then
      return
    end

    table.insert(line, { filename, c.config.ui.highlights.filename })
    table.insert(line, " ")
    table.insert(line, { dirname, c.config.ui.highlights.dirname })

    -- Map quit char to close the buflist
    local quit_key = c.config.keymaps.quit
    if quit_key then
      M.map({
        quit_key,
        function()
          if M.stay_opened then
            require("plugins.noneckpain").return_to_main_win()
          else
            M.close()
          end
        end,
        buffer = M.buf,
      })
    end

    -- Add keymap for the first character of the basename
    local first_char = b.basename:sub(1, 1)
    if not M.mapped_keys[first_char] then
      M.map({
        first_char,
        function()
          M.update({ first_char = first_char })
        end,
        buffer = M.buf,
      })
    end
  end

  --- Renders a buffer on a line
  ---@param b Beez.bufswitcher.buf
  local function render_buf(b)
    local line = {}

    local filename = calculate_filename(b)
    local dirname = calculate_dirname(b, filename)
    if b.current then
      current_buf_i = line_idx
    end

    render_pinned(line, b, line_idx)
    table.insert(line, " ")

    render_current(line, b)
    render_index_char(line, b)

    table.insert(line, " ")
    render_first_char_buf(line, b, filename, dirname)
    render_normal_view(line, b, filename, dirname)
    table.insert(texts, line)
  end

  -- Render pinned buffers first and sort them by pin index
  local pinned_bufs = {}
  for _, b in ipairs(bufs) do
    if b.pinned then
      table.insert(pinned_bufs, b)
    end
  end
  table.sort(pinned_bufs, function(a, b)
    return a.pin_idx < b.pin_idx
  end)

  for _, buf in ipairs(pinned_bufs) do
    render_buf(buf)
    table.insert(M.displayed_bufs, buf.idx)
    line_idx = line_idx + 1
  end

  -- Then render the rest of the buffers
  for i, b in ipairs(bufs) do
    if not b.pinned then
      render_buf(b)
      table.insert(M.displayed_bufs, i)
      line_idx = line_idx + 1
    end
  end

  -- Clean up the buffer contents
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
  -- Render the new buffer list
  for i, l in ipairs(texts) do
    local line = require("nui.line")()
    for _, t in ipairs(l) do
      if type(t) == "table" then
        line:append(t[1], t[2])
      else
        line:append(t)
      end
    end
    line:render(M.buf, -1, i, i)
  end

  -- Highlight the current buffer line
  vim.api.nvim_buf_set_extmark(M.buf, ns_id, current_buf_i - 1, 0, {
    end_col = #vim.api.nvim_buf_get_lines(M.buf, current_buf_i - 1, current_buf_i, false)[1],
    hl_group = c.config.ui.highlights.curr_buf,
  })
  -- Set the cursor to the current buffer line
  if opts.set_cursor ~= nil then
    current_buf_i = opts.set_cursor
  end
  pcall(vim.api.nvim_win_set_cursor, M.win, { current_buf_i, 0 })
end

--- Return a list of opened buffers
---@param opts? {pinned?: boolean}
---@return Beez.bufswitcher.buf[]
function M.list(opts)
  return M.bl:list(opts)
end

return M
