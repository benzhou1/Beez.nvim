local Buf = require("Beez.bufswitcher.buf")
local c = require("Beez.bufswitcher.config")
local u = require("Beez.u")

---@class Beez.bufswitcher.buflist
---@field bufs Beez.bufswitcher.buf[]
---@field p? NuiPopup
---@field available_chars table<string, boolean>
---@field mapped_keys table<string, boolean>
---@field curr_buf integer?
Buflist = {}
Buflist.__index = Buflist
Buflist.autocmd_group = "Beez.bufswitcher.buflist"
Buflist.ns_group = "Beez.bufswitcher.buflist"

--- Instantiate a new Buflist
---@return Beez.bufswitcher.buflist
function Buflist:new()
  local b = {}
  setmetatable(b, Buflist)

  b.bufs = {}
  b.p = nil
  b.available_chars = {}
  b.mapped_keys = {}
  b.curr_buf = nil

  -- Create a mpa of available chars
  local pick_chars = c.config.keymaps.pick_chars
  assert(pick_chars, "pick_chars must be set in config.keymaps.pick_chars")
  for i = 1, #pick_chars do
    local char = pick_chars:sub(i, i)
    b.available_chars[char] = true
  end
  return b
end

--- Default sort function by id
---@param bufs Beez.bufswitcher.buf[]
---@return Beez.bufswitcher.buf[]
function Buflist.def_sort(bufs)
  table.sort(bufs, function(a, b)
    return a.id > b.id
  end)
  return bufs
end

--- Default file name to be displayed
---@param buf Beez.bufswitcher.buf
---@param names table<string, boolean>
---@return string
function Buflist.def_filename(buf, names)
  return buf.basename
end

--- Default dir name to be displayed
---@param buf Beez.bufswitcher.buf
---@param filename string
---@param display_names table<string, boolean>
---@return string
function Buflist.def_dirname(buf, filename, display_names)
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

--- Map default keym binds
function Buflist:map_keys()
  local keys = {}

  -- Map last buffer char to open the last buffer
  local last_buf_char = c.config.keymaps.last_buf_char
  if last_buf_char then
    table.insert(keys, {
      last_buf_char,
      function()
        self:open_buf("#")
      end,
      buffer = self.p.bufnr,
    })
  end

  -- Map chars to open buffer at index
  local index_chars = c.config.keymaps.index_chars
  if index_chars then
    for i, char in ipairs(index_chars) do
      if char ~= "" then
        table.insert(keys, {
          char,
          function()
            local buf = self.bufs[i]
            if buf then
              self:open_buf(buf.path)
            end
          end,
          buffer = self.p.bufnr,
        })
      end
    end
  end

  u.keymaps.set(keys)
end

--- Clear previious key mappings
function Buflist:clear_keys()
  for k, is_buf in pairs(self.mapped_keys) do
    if is_buf then
      u.keymaps.unset({ k, buffer = self.p.bufnr })
    else
      u.keymaps.unset({ k })
    end
  end
  self.mapped_keys = {}
end

--- Create autocmds for the buflist
function Buflist:create_autocmds()
  local group = vim.api.nvim_create_augroup(Buflist.autocmd_group, { clear = true })

  -- Create an autocmd to refresh the buffer list when a buffer is added or removed
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter" }, {
    group = group,
    callback = function(event)
      -- TODO: See if we can change highlight only on bufenter
      if self:is_open() and event.buf ~= self.p.bufnr and event.file ~= "" then
        local valid_buf_enter = c.config.autocmds.valid_buf_enter
        if valid_buf_enter then
          if not valid_buf_enter(event) then
            return
          end
        end
        self:update()
      end
    end,
  })

  -- Create an autocmd to cleanup buflist when window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(self.p.winid),
    callback = function(event)
      if event.winid == self.p.winid then
        self:close()
      end
    end,
  })

  if c.config.win.close_on_leave and not c.config.win.stay_opened then
    -- Unmount the popup when cursor leaves the buffer
    self.p:on("BufLeave", function()
      self:close()
    end)
  end
end

--- Clean up the autocmds for this buflist
function Buflist:clean_autocmds()
  -- Clear the autocmds for this buflist
  vim.api.nvim_del_augroup_by_name(Buflist.autocmd_group)

  if c.config.win.close_on_leave and not c.config.win.stay_opened then
    self.p:off("BufLeave")
  end
end

--- Refresh the buffer list
function Buflist:refresh()
  self.bufs = {}

  local bufnrs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufnrs) do
    local info = vim.fn.getbufinfo(buf)[1]
    local b = Buf:new(info)
    if b:is_valid_buf() then
      table.insert(self.bufs, b)
    end
  end

  -- Sort the buffer
  if c.config.hooks.sort then
    self.bufs = c.config.hooks.sort(self.bufs)
  else
    self.bufs = Buflist.def_sort(self.bufs)
  end
end

--- List buffers
---@param opts? {first_char?: string}
---@return Beez.bufswitcher.buf[]
function Buflist:list(opts)
  opts = opts or {}
  -- Return buffers with the specified first character
  if opts.first_char then
    local bufs = {}
    for _, b in ipairs(self.bufs) do
      if b.basename:startswith(opts.first_char) then
        table.insert(bufs, b)
      end
    end
    return bufs
  end
  return self.bufs
end

--- Is buflist showing
---@return boolean
function Buflist:is_open()
  if not self.p or not self.p.winid or not self.p.bufnr then
    return false
  end
  return true
end

--- Close the buflist
function Buflist:close()
  if not self.p then
    return
  end

  self.p:unmount()
  self.p = nil
  self:clean_autocmds()
  for k, is_buf in pairs(self.mapped_keys) do
    if is_buf then
      self.mapped_keys[k] = nil
    end
  end
end

--- Show buflist
function Buflist:show()
  -- Make sure buflist is cleaned up if its not showing
  if not self:is_open() then
    self:close()
  end

  self.curr_buf = vim.api.nvim_get_current_buf()
  if not self.p then
    local popup_opts = c.config.win.popup
    if c.config.win.get_popup_opts then
      popup_opts = c.config.win.get_popup_opts()
    end
    assert(popup_opts, "popup_opts must be set in config.win.popup or config.win.get_popup_opts")
    self.p = require("nui.popup")(popup_opts)
    self:refresh()
    self:map_keys()
    self:create_autocmds()
    self:render()
    self.p:mount()
  else
    vim.api.nvim_set_current_win(self.p.winid)
  end
end

--- Updates the buflist
---@param opts? {first_char?: string}
function Buflist:update(opts)
  opts = opts or {}
  if not self.p then
    return
  end

  if not opts.first_char then
    self.curr_buf = vim.api.nvim_get_current_buf()
  end
  self:refresh()
  self:render(opts)
end

--- Open chosen buffer in main window
---@param path string
function Buflist:open_buf(path)
  if not self.p then
    return
  end

  if not c.config.win.stay_opened then
    self:close()
  end

  vim.schedule(function()
    require("plugins.noneckpain").return_to_main_win()
    local ok, _ = pcall(vim.cmd, "e " .. path)
    if not ok then
      vim.cmd("e " .. self.bufs[1].path)
    end
  end)
end

--- Returns a list of texts to be displayed
---@param opts? {first_char?: string}
function Buflist:render(opts)
  opts = opts or {}
  local bufs = self:list({ first_char = opts.first_char })
  -- If only one buffer, open it directly
  if #bufs == 1 and opts.first_char then
    self:open_buf(bufs[1].path)
    return
  end
  -- If two buffers, but one of them is the current buffer, open the other one
  if #bufs == 2 and opts.first_char then
    for i, b in ipairs(bufs) do
      local current = self.curr_buf == b.id
      if current then
        local buf = i == 1 and bufs[2] or bufs[1]
        self:open_buf(buf.path)
        return
      end
    end
  end

  local texts = {}
  local filenames = {}
  local display_names = {}
  local picked_chars = {}
  local keys = {}
  local ns_id = vim.api.nvim_create_namespace(Buflist.ns_group)
  local current_buf_i = 1
  vim.api.nvim_buf_clear_namespace(self.p.bufnr, ns_id, 0, -1)
  self:clear_keys()

  for i, b in ipairs(bufs) do
    local line = {}
    local current = self.curr_buf == b.id
    local filename = b.basename
    if c.config.hooks.get_filename then
      filename = c.config.hooks.get_filename(b, filenames)
    else
      filename = Buflist.def_filename(b, filenames)
    end
    filenames[filename] = true

    local dirname = b.dirname
    if c.config.hooks.get_dirname then
      dirname = c.config.hooks.get_dirname(b, filename, display_names)
    else
      dirname = Buflist.def_dirname(b, filename, display_names)
    end
    local display_name = filename .. " " .. dirname
    display_names[display_name] = true

    -- First 2 columns are for the index maps and current buffer indicator
    if current then
      table.insert(line, "» ")
      current_buf_i = i
    -- index maps applies to all buffers view only
    elseif not opts.first_char then
      -- First column is for current buffer indicator
      table.insert(line, " ")

      -- Add index character if available
      local index_char = c.config.keymaps.index_chars[i]
      if index_char ~= "" and index_char then
        table.insert(line, { index_char, c.config.ui.highlights.index_char })
      -- Add last char if available
      elseif c.config.keymaps.last_buf_char then
        local last_buf_char = c.config.keymaps.last_buf_char
        local last_buf = vim.fn.bufnr("#")
        if last_buf == b.id then
          table.insert(line, { last_buf_char, c.config.ui.highlights.last_buf_char })
        else
          table.insert(line, " ")
        end
      else
        table.insert(line, " ")
      end
    else
      table.insert(line, "  ")
    end

    -- Highlight the first available character in filename or dirname
    if opts.first_char then
      local picked_char = nil
      for _i = 1, #filename do
        local char = filename:sub(_i, _i)
        if
          self.available_chars[char]
          and not picked_chars[char]
          and picked_char == nil
          and filename ~= "init.lua"
        then
          table.insert(line, { char, c.config.ui.highlights.char_label })
          picked_char = char
          picked_chars[char] = true
        else
          table.insert(line, { char, c.config.ui.highlights.filename })
        end
      end

      table.insert(line, " ")
      if picked_char ~= nil then
        table.insert(line, { dirname, c.config.ui.highlights.dirname })
      else
        for _i = 1, #dirname do
          local char = dirname:sub(_i, _i)
          if self.available_chars[char] and not picked_chars[char] and picked_char == nil then
            table.insert(line, { char, c.config.ui.highlights.char_label })
            picked_char = char
            picked_chars[char] = true
          else
            table.insert(line, { char, c.config.ui.highlights.dirname })
          end
        end
      end
      table.insert(texts, line)

      -- Add unique keymap for each buffer
      if picked_char ~= nil then
        table.insert(keys, {
          picked_char,
          function()
            self:open_buf(b.path)
          end,
          buffer = self.p.bufnr,
        })
        self.mapped_keys[picked_char] = true
      end

      -- Add keymap for go back to showing all buffers
      table.insert(keys, {
        "<Esc>",
        function()
          self:update()
        end,
        buffer = self.p.bufnr,
      })
    else
      table.insert(line, " ")
      table.insert(line, { filename, c.config.ui.highlights.filename })
      table.insert(line, " ")
      table.insert(line, { dirname, c.config.ui.highlights.dirname })
      table.insert(texts, line)

      -- Map quit char to close the buflist
      local quit_char = c.config.keymaps.quit_char
      if quit_char then
        table.insert(keys, {
          quit_char,
          function()
            if c.config.win.stay_opened then
              require("plugins.noneckpain").return_to_main_win()
            else
              self:close()
            end
          end,
          buffer = self.p.bufnr,
        })
      end

      -- Add keymap for the first character of the basename
      local first_char = b.basename:sub(1, 1)
      table.insert(keys, {
        first_char,
        function()
          self:update({ first_char = first_char })
        end,
        buffer = self.p.bufnr,
      })
      self.mapped_keys[first_char] = true
    end
  end

  -- Clean up the buffer contents
  vim.api.nvim_buf_set_lines(self.p.bufnr, 0, -1, false, {})
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
    line:render(self.p.bufnr, -1, i, i)
  end

  -- Highlight the current buffer line
  vim.api.nvim_buf_set_extmark(self.p.bufnr, ns_id, current_buf_i - 1, 0, {
    end_col = #vim.api.nvim_buf_get_lines(self.p.bufnr, current_buf_i - 1, current_buf_i, false)[1],
    hl_group = c.config.ui.highlights.curr_buf,
  })

  u.keymaps.set(keys)
end

return Buflist
