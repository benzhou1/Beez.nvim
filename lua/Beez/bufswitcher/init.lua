local Buflist = require("Beez.bufswitcher.buflist")
local c = require("Beez.bufswitcher.config")
local hl = require("Beez.bufswitcher.highlights")
local tabline = require("Beez.bufswitcher.tabline")
local u = require("Beez.u")

local H = { init_tabline = false }
local debug = false

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

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup(M.autocmd_group, { clear = true })
  local events = require("nui.utils.autocmd").event

  -- Create an autocmd to refresh the buffer list when a buffer is added
  vim.api.nvim_create_autocmd({ events.BufAdd, events.BufEnter }, {
    group = group,
    callback = function(event)
      local ok, err = pcall(function()
        local hook_is_valid_buf = c.config.hook_buf_is_valid or M.default_hook_buf_is_valid
        if not hook_is_valid_buf(event.buf) then
          return
        end
        M.bl:add(event.buf)
        M.refresh_ui()
      end)

      if not ok then
        vim.notify("Error adding buffer to buflist: " .. err, vim.log.levels.ERROR)
      end
    end,
  })

  -- Create an autocmd to refresh the buffer list when a buffer is deleted
  vim.api.nvim_create_autocmd(events.BufDelete, {
    group = group,
    callback = function(event)
      M.bl:remove(event.buf)
      M.refresh_ui()
    end,
  })
end

--- Setup plugin
---@param opts Beez.bufswitcher.config
function M.setup(opts)
  opts = vim.tbl_deep_extend("keep", {}, opts or {})
  c.init(opts)

  local hook_session_name = c.config.hook_session_name or M.default_hook_session_name

  M.config = c.config
  M.session = hook_session_name()
  M.session_file = u.paths.Path:new(vim.fs.joinpath(c.config.data_dir, M.session .. ".json"))

  M.bl = Buflist:new()
  M.load()

  setup_autocmds()
  hl.init()

  _G.Bufswitcher = M
end

--- Default hook for hook_session_name. Uses the basename of the cwd, if session name already exists use parent dir as well.
---@return string
function M.default_hook_session_name()
  local sessions = vim.fn.readdir(c.config.data_dir)
  local unique_sessions = {}
  for _, s in ipairs(sessions) do
    unique_sessions[s] = true
  end
  local session_name = u.paths.basename(vim.fn.getcwd())
  if unique_sessions[session_name] then
    session_name = u.paths.basename(u.paths.dirname(vim.fn.getcwd())) .. "_" .. session_name
  end
  return session_name
end

--- Default hook for hook_buf_is_valid. Check if buffer is valid and listed.
---@param bufnr integer
---@return boolean
function M.default_hook_buf_is_valid(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1
end

--- Default hook for hook_buf_sort. By default no sorting.
---@param bufs Beez.bufswitcher.buf[]
---@return Beez.bufswitcher.buf[]
function M.default_hook_buf_sort(bufs)
  return bufs
end

--- Default hook for hook_buf_label. First few n buffers will
---@param b Beez.bufswitcher.buf
---@param i integer
---@param pinned_i integer
---@param bufs Beez.bufswitcher.buf[]
---@return string, string
function M.default_hook_buf_label(b, i, pinned_i, bufs)
  local label, label_hl
  if b.pinned then
    label, label_hl = c.config.pinned_labels[pinned_i], c.config.ui_pin_label_hl
  else
    label, label_hl = c.config.recent_labels[i - 1], c.config.ui_recent_label_hl
  end
  return label, label_hl
end

--- Default hook for hook_buf_name. Use the buffers basename, otherwise add the parent directories to the name.
---@param b Beez.bufswitcher.buf
---@param i integer
---@param bufs Beez.bufswitcher.buf[]
---@param unique_names table<string, boolean>
---@return string, string[][]
function M.default_hook_buf_name(b, i, bufs, unique_names)
  local name = b.basename
  local dir_hl = c.config.ui_dir_hl or hl.hl.dir
  local name_hl = c.config.ui_name_hl or hl.hl.name
  if b.current then
    name_hl = c.config.ui_curr_buf_hl or hl.hl.current_buf
  end

  -- If basename is unique then we are good
  if not unique_names[name] then
    return name, { { name, name_hl } }
  end

  -- Otherwise add the parent directory to the name
  local parts = vim.fn.split(b.dirname, u.paths.sep)
  local _i = 0
  local dirname = parts[#parts]
  local display_name = dirname .. u.paths.sep .. name
  -- Keep adding parent directories until we find a unique name
  while unique_names[display_name] do
    _i = _i + 1
    dirname = parts[#parts - _i]
    display_name = dirname .. u.paths.sep .. display_name
  end

  local hls = {}
  parts = vim.fn.split(display_name, u.paths.sep)
  for _i, p in ipairs(parts) do
    if _i == #parts then
      table.insert(hls, { p, name_hl })
    else
      table.insert(hls, { p .. "/", dir_hl })
    end
  end
  return display_name, hls
end

--- Default hook for hook_buf_list. Gets the first n recent buffers followed by all pinned buffers.
---@param bufs Beez.bufswitcher.buf[]
---@return Beez.bufswitcher.buf[]
function M.default_hook_buf_list(bufs)
  local display_bufs = {}
  local unique_names = {}
  local get_name = c.config.hook_buf_name or M.default_hook_buf_name
  local get_label = c.config.hook_buf_label or M.default_hook_buf_label

  -- Buf list is sorted already get the first n + 1 recent buffers
  for i, b in ipairs(bufs) do
    if i <= #c.config.recent_labels + 1 then
      local copy = b:copy()
      -- Dont set label on the first, since its always the current buffer
      if i == 1 then
        copy:unpin()
      else
        local label, label_hl = get_label(copy, i, i, bufs)
        copy:set_label(label, label_hl)
      end

      local name, hls = get_name(copy, i, bufs, unique_names)
      unique_names[name] = true
      copy:set_name(hls)
      table.insert(display_bufs, copy)
    end
  end
  -- Then look for all pinned buffers in reverse order
  local i = 1
  for _i = #bufs, 1, -1 do
    local b = bufs[_i]
    if b.pinned then
      local copy = b:copy()
      -- If pinned buffer is also the current, remove the first item, since we want the pinned buffer to be current
      if copy.current then
        table.remove(display_bufs, 1)
      end

      local label, label_hl = get_label(copy, i, i, bufs)
      copy:set_label(label, label_hl)
      local name, hls = get_name(copy, i, bufs, unique_names)
      unique_names[name] = true
      copy:set_name(hls)
      table.insert(display_bufs, copy)
      i = i + 1
    end
  end
  return display_bufs
end

--- Default hook for hook_ui_refresh.
---@param bufs Beez.bufswitcher.buf[]
function M.default_hook_ui_refresh(bufs)
  if debug then
    M.get_tabline()
  end
  if H.init_tabline then
    vim.cmd("redrawtabline")
    return
  end
  if not debug then
    vim.opt.showtabline = 2
    vim.opt.tabline = "%!v:lua.Bufswitcher.get_tabline()"
  end
  H.init_tabline = true
end

--- Returns a list of buffer objects
---@return Beez.bufswitcher.buf[]
function M.list()
  local bufs = M.bl:list()
  local hook_buf_sort = c.config.hook_buf_sort or M.default_hook_buf_sort
  bufs = hook_buf_sort(bufs)
  return bufs
end

--- Returns a list of buffer objects to be displayed
---@return Beez.bufswitcher.buf[]
function M.list_ui()
  local bufs = M.list()
  local hook_buf_list = c.config.hook_buf_list or M.default_hook_buf_list
  bufs = hook_buf_list(bufs)
  return bufs
end

--- Refresh the ui with new buffer list
function M.refresh_ui()
  local hook_ui_refresh = c.config.hook_ui_refresh
  if hook_ui_refresh ~= nil then
    local bufs = M.list_ui()
    return hook_ui_refresh(bufs)
  end
  M.default_hook_ui_refresh({})
end

--- Generate a tabline to be displayed
---@return string
function M.get_tabline()
  local bufs = M.list_ui()
  return tabline.get(bufs)
end

--- Toggles pin status of a buffer
---@param buf? Beez.bufswitcher.buf
function M.toggle_pin(buf)
  if buf == nil then
    buf = M.bl:current()
    if buf == nil then
      return
    end
  end
  if buf.pinned then
    M.unpin(buf)
  else
    M.pin(buf)
  end
end

--- Pin a buffer
---@param buf? Beez.bufswitcher.buf
function M.pin(buf)
  if buf == nil then
    buf = M.bl:current()
    if buf == nil then
      return
    end
  end
  if buf.pinned then
    return
  end

  buf:pin()
  M.refresh_ui()
  M.persist()
end

--- Unpin a buffer
---@param buf? Beez.bufswitcher.buf
function M.unpin(buf)
  if buf == nil then
    buf = M.bl:current()
    if buf == nil then
      return
    end
  end
  if not buf.pinned then
    return
  end

  buf:unpin()
  M.refresh_ui()
  M.persist()
end

--- Persist pinned buffers
function M.persist()
  M.bl:save(M.session_file)
end

--- Load pinned buffers
function M.load()
  M.bl:load(M.session_file)
end

--- Show the popup
---@param opts? {focus?: boolean}
-- function M.show(opts)
--   opts = opts or {}
--   -- Make sure buflist is cleaned up if its not showing
--   if not M.is_open() then
--     M.close()
--   end
--   -- Save the current buffer before activating the buflist
--   M.curr_buf = vim.api.nvim_get_current_buf()
--
--   --- Focus the buflist
--   local function focus_buflist()
--     vim.api.nvim_set_current_win(M.win)
--     for i, bidx in ipairs(M.displayed_bufs) do
--       local buf = M.bl:get({ idx = bidx })
--       -- Move cursor to the current buffer
--       if buf and buf.id == M.curr_buf then
--         vim.api.nvim_win_set_cursor(M.win, { i, 0 })
--         return
--       end
--     end
--   end
--
--   -- If no-neck-pain is enabled, use its left buffer instead of float
--   if noneckpain_enabled() then
--     if M.buf == nil then
--       M.stay_opened = true
--       local state = require("no-neck-pain.state")
--       M.win = state:get_side_id("left")
--       M.buf = vim.api.nvim_win_get_buf(M.win)
--
--       M.update()
--       map_keys()
--       create_autocmds()
--     end
--     if opts.focus ~= false then
--       focus_buflist()
--     end
--     return
--   end
--
--   -- Use float popup
--   if not M.p then
--     local popup_opts = c.config.win.popup
--     if c.config.win.get_popup_opts then
--       popup_opts = c.config.win.get_popup_opts()
--     end
--     assert(popup_opts, "popup_opts must be set in config.win.popup or config.win.get_popup_opts")
--
--     M.p = require("nui.popup")(popup_opts)
--     M.p:mount()
--     M.buf = M.p.bufnr
--     M.win = M.p.winid
--     -- Allows you to dynamically change stay opened
--     ---@diagnostic disable-next-line: undefined-field
--     M.stay_opened = popup_opts.stay_opened or false
--
--     M.update()
--     map_keys()
--     create_autocmds()
--
--     -- Temporarily disable timeoutlen to allow for quick key presses
--     vim.opt.timeoutlen = 1
--   else
--     if opts.focus ~= false then
--       focus_buflist()
--     end
--   end
-- end

--- Update the buffer list
---@param opts? {first_char?: string, set_cursor?: integer}
-- function M.update(opts)
--   opts = opts or {}
--   if not M.is_open() then
--     return
--   end
--   -- Create a map of pinned paths
--   local pins = {}
--   for i, p in ipairs(M.pinned_paths) do
--     pins[p] = i
--   end
--
--   M.bl:refresh({ pins = pins, curr_buf = M.curr_buf })
--   local bufs = M.bl:list({ first_char = opts.first_char })
--
--   if opts.first_char then
--     -- If only one buffer, open it directly
--     if #bufs == 1 then
--       M.open_buf(bufs[1])
--       return
--     end
--     -- If two buffers, but one of them is the current buffer, open the other one
--     if #bufs == 2 then
--       for i, b in ipairs(bufs) do
--         local current = M.curr_buf == b.id
--         if current then
--           local buf = i == 1 and bufs[2] or bufs[1]
--           M.open_buf(buf)
--           return
--         end
--       end
--     end
--   end
--
--   M.displayed_bufs = {}
--   local texts = {}
--   local filenames = {}
--   local display_names = {}
--   local picked_chars = {}
--   local ns_id = vim.api.nvim_create_namespace(M.ns_group)
--   local current_buf_i = 1
--   local line_idx = 1
--
--   vim.api.nvim_buf_clear_namespace(M.buf, ns_id, 0, -1)
--   M.clear_keys()
--
--   --- Returns filename to be displayed
--   ---@param b Beez.bufswitcher.buf
--   ---@return string
--   local function calculate_filename(b)
--     local filename = b.basename
--     if c.config.hooks.get_filename then
--       filename = c.config.hooks.get_filename(b, filenames)
--     else
--       filename = def_filename(b, filenames)
--     end
--     filenames[filename] = true
--     return filename
--   end
--
--   --- Calculate directory name to be displayed
--   ---@param b Beez.bufswitcher.buf
--   ---@param filename string
--   ---@return string
--   local function calculate_dirname(b, filename)
--     local dirname = b.dirname
--     if c.config.hooks.get_dirname then
--       dirname = c.config.hooks.get_dirname(b, filename, display_names)
--     else
--       dirname = def_dirname(b, filename, display_names)
--     end
--     local display_name = filename .. " " .. dirname
--     display_names[display_name] = true
--     return dirname
--   end
--
--   --- Renders col with pinned char and icon
--   ---@param line table
--   ---@param b Beez.bufswitcher.buf
--   local function render_pinned(line, b, i)
--     if b.pinned then
--       local pin_char = c.config.keymaps.pinned_chars[i] or i
--       table.insert(line, "📌")
--       table.insert(line, { pin_char, c.config.ui.highlights.pin_char })
--
--       -- Add keymap to open pinned buffers
--       M.map({
--         pin_char,
--         function()
--           M.open_buf(b)
--         end,
--         buffer = M.buf,
--       })
--     else
--       table.insert(line, "   ")
--     end
--   end
--
--   --- Render char for the current buffer
--   ---@param line table
--   ---@param b Beez.bufswitcher.buf
--   local function render_current(line, b)
--     if b.current then
--       table.insert(line, "»")
--     end
--   end
--
--   --- Render index char for the buffer
--   ---@param line table
--   ---@param b Beez.bufswitcher.buf
--   local function render_index_char(line, b)
--     if not opts.first_char then
--       local index_char = c.config.keymaps.index_chars[b.idx]
--       if index_char ~= "" and index_char then
--         table.insert(line, { index_char, c.config.ui.highlights.index_char })
--         -- Map chars to open buffer at index
--         M.map({
--           index_char,
--           function()
--             M.open_buf(b)
--           end,
--           buffer = M.buf,
--         })
--       elseif not b.current then
--         table.insert(line, " ")
--       end
--     elseif not b.current then
--       table.insert(line, " ")
--     end
--   end
--
--   --- Renders the filename and dirname for the first char view
--   ---@param line table
--   ---@param b Beez.bufswitcher.buf
--   ---@param filename string
--   ---@param dirname string
--   local function render_first_char_buf(line, b, filename, dirname)
--     if not opts.first_char then
--       return
--     end
--
--     local picked_char = nil
--     for _i = 1, #filename do
--       local char = filename:sub(_i, _i)
--       if
--         M.available_chars[char]
--         and not picked_chars[char]
--         and picked_char == nil
--         and filename ~= "init.lua"
--         and not b.current
--       then
--         table.insert(line, { char, c.config.ui.highlights.char_label })
--         picked_char = char
--         picked_chars[char] = true
--       else
--         table.insert(line, { char, c.config.ui.highlights.filename })
--       end
--     end
--
--     table.insert(line, " ")
--
--     -- Highlight the first available character in dirname
--     if picked_char ~= nil then
--       table.insert(line, { dirname, c.config.ui.highlights.dirname })
--     else
--       for _i = 1, #dirname do
--         local char = dirname:sub(_i, _i)
--         if
--           M.available_chars[char]
--           and not picked_chars[char]
--           and picked_char == nil
--           and not b.current
--         then
--           table.insert(line, { char, c.config.ui.highlights.char_label })
--           picked_char = char
--           picked_chars[char] = true
--         else
--           table.insert(line, { char, c.config.ui.highlights.dirname })
--         end
--       end
--     end
--
--     -- Add unique keymap for each buffer
--     if picked_char ~= nil then
--       M.map({
--         picked_char,
--         function()
--           M.open_buf(b)
--         end,
--         buffer = M.buf,
--       }, { clean = true })
--     end
--
--     -- Add keymap for go back to showing all buffers
--     M.map({
--       "<Esc>",
--       function()
--         M.update()
--       end,
--       buffer = M.buf,
--     })
--   end
--
--   --- Renders the filename and dirname for the normal view
--   ---@param line table
--   ---@param filename string
--   ---@param dirname string
--   local function render_normal_view(line, b, filename, dirname)
--     if opts.first_char then
--       return
--     end
--
--     table.insert(line, { filename, c.config.ui.highlights.filename })
--     table.insert(line, " ")
--     table.insert(line, { dirname, c.config.ui.highlights.dirname })
--
--     -- Map quit char to close the buflist
--     local quit_key = c.config.keymaps.quit
--     if quit_key then
--       M.map({
--         quit_key,
--         function()
--           if M.stay_opened then
--             require("plugins.noneckpain").return_to_main_win()
--           else
--             M.close()
--           end
--         end,
--         buffer = M.buf,
--       })
--     end
--
--     -- Add keymap for the first character of the basename
--     local first_char = b.basename:sub(1, 1)
--     if not M.mapped_keys[first_char] then
--       M.map({
--         first_char,
--         function()
--           M.update({ first_char = first_char })
--         end,
--         buffer = M.buf,
--       })
--     end
--   end
--
--   --- Renders a buffer on a line
--   ---@param b Beez.bufswitcher.buf
--   local function render_buf(b)
--     local line = {}
--
--     local filename = calculate_filename(b)
--     local dirname = calculate_dirname(b, filename)
--     if b.current then
--       current_buf_i = line_idx
--     end
--
--     render_pinned(line, b, line_idx)
--     table.insert(line, " ")
--
--     render_current(line, b)
--     render_index_char(line, b)
--
--     table.insert(line, " ")
--     render_first_char_buf(line, b, filename, dirname)
--     render_normal_view(line, b, filename, dirname)
--     table.insert(texts, line)
--   end
--
--   -- Render pinned buffers first and sort them by pin index
--   local pinned_bufs = {}
--   for _, b in ipairs(bufs) do
--     if b.pinned then
--       table.insert(pinned_bufs, b)
--     end
--   end
--   table.sort(pinned_bufs, function(a, b)
--     return a.pin_idx < b.pin_idx
--   end)
--
--   for _, buf in ipairs(pinned_bufs) do
--     render_buf(buf)
--     table.insert(M.displayed_bufs, buf.idx)
--     line_idx = line_idx + 1
--   end
--
--   -- Then render the rest of the buffers
--   for i, b in ipairs(bufs) do
--     if not b.pinned then
--       render_buf(b)
--       table.insert(M.displayed_bufs, i)
--       line_idx = line_idx + 1
--     end
--   end
--
--   -- Clean up the buffer contents
--   vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
--   -- Render the new buffer list
--   for i, l in ipairs(texts) do
--     local line = require("nui.line")()
--     for _, t in ipairs(l) do
--       if type(t) == "table" then
--         line:append(t[1], t[2])
--       else
--         line:append(t)
--       end
--     end
--     line:render(M.buf, -1, i, i)
--   end
--
--   -- Highlight the current buffer line
--   vim.api.nvim_buf_set_extmark(M.buf, ns_id, current_buf_i - 1, 0, {
--     end_col = #vim.api.nvim_buf_get_lines(M.buf, current_buf_i - 1, current_buf_i, false)[1],
--     hl_group = c.config.ui.highlights.curr_buf,
--   })
--   -- Set the cursor to the current buffer line
--   if opts.set_cursor ~= nil then
--     current_buf_i = opts.set_cursor
--   end
--   pcall(vim.api.nvim_win_set_cursor, M.win, { current_buf_i, 0 })
-- end

return M
