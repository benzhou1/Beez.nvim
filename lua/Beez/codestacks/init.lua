local Bufferlist = require("Beez.codestacks.buffers")
local be = require("Beez.codestacks.backend")
local c = require("Beez.codestacks.config")
local hl = require("Beez.codestacks.highlights")
local tabline = require("Beez.codestacks.tabline")
local u = require("Beez.u")
local debug_tabline = false
local H = { init_tabline = false }
local M = {
  autocmd_group = "autocmd.Beez.codestacks.buflist",
  def_hooks = {},
  stacks = {},
  pinned = {},
  bufferlist = {},
  recentfiles = {},
  marks = {},
  ui = {},
}

---@class Beez.codestacks.PinnedBuffer
---@field path string
---@field label string

---@class Beez.codestacks.Stack
---@field name string
---@field pinned_buffers Beez.codestacks.PinnedBuffer[]
---@field global_marks Beez.codestacks.GlobalMark[]
---@field local_marks Beez.codestacks.LocalMark[]

--- Calls rust backend and prints out error if there is any
local function call_backend(...)
  local ok, error = pcall(...)
  if not ok then
    print("error = ", vim.inspect(tostring(error)))
  end
  return ok, error
end

--- Setup autocmds for handling buffers
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup(M.autocmd_group, { clear = true })
  local events = require("nui.utils.autocmd").event

  -- Create an autocmd to refresh the buffer list when a buffer is added
  vim.api.nvim_create_autocmd({ events.BufAdd, events.BufEnter }, {
    group = group,
    callback = function(event)
      local ok, err = pcall(function()
        local hook_is_valid_buf = c.config.hook_buf_is_valid or M.def_hooks.default_hook_buf_is_valid
        if not hook_is_valid_buf(event.buf) then
          return
        end

        local filename = vim.api.nvim_buf_get_name(event.buf)
        M.bl:add(event.buf)
        M.ui.refresh()

        local path = vim.fs.normalize(filename)
        local exists = vim.fn.filereadable(path) == 1
        if not exists then
          return
        end
        call_backend(be.add_recent_file, path)
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
      M.ui.refresh()
    end,
  })

  -- Autocmd to check for outdated marks when a file is written
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*",
    callback = function(event)
      M.marks.check_for_outdated(event.match)
    end,
  })
end

--- Default hook for hook_session_name. Uses the basename of the cwd, if session name already exists use parent dir as well.
---@return string
function M.def_hooks.default_hook_session_name()
  local session_name = u.paths.basename(vim.fn.getcwd())
  session_name = u.paths.basename(u.paths.dirname(vim.fn.getcwd())) .. "_" .. session_name
  return session_name
end

--- Default hook for hook_buf_is_valid. Check if buffer is valid and listed.
---@param bufnr integer
---@return boolean
function M.def_hooks.default_hook_buf_is_valid(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1
end

--- Default hook for hook_label_id_valid. Allow only lowercase letters and numbers 1-9 as labels.
---@param label string
---@return boolean
function M.def_hooks.is_valid_label(label)
  if label:match("^[a-zA-Z1-9" .. table.concat(c.config.recent_labels, "") .. "]$") == nil then
    return false
  end
  return true
end

--- Default hook for hook_buf_name. Use the buffers basename, otherwise add the parent directories to the name.
---@param b Beez.codestacks.buf
---@param i integer
---@param bufs Beez.codestacks.buf[]
---@param unique_names table<string, boolean>
---@return string, string[][]
function M.def_hooks.buf_name(b, i, bufs, unique_names)
  local name = b.basename
  local dir_hl = c.config.ui_dir_hl or hl.hl.dir
  local name_hl = c.config.ui_name_hl or hl.hl.name
  if b.current then
    name_hl = c.config.ui_curr_buf_hl
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
  for __i, p in ipairs(parts) do
    if __i == #parts then
      table.insert(hls, { p, name_hl })
    else
      table.insert(hls, { p .. "/", dir_hl })
    end
  end
  return display_name, hls
end

--- Default hook for hook_pinned_buf_name. Uses first 3 characters of the basename.
---@param b Beez.codestacks.PinnedBuffer
---@param i integer
---@param bufs Beez.codestacks.PinnedBuffer[]
---@param unique_names table<string, boolean>
---@return string, string[][]
function M.def_hooks.pinned_buf_name(b, i, bufs, unique_names)
  local basename = u.paths.basename(b.path)
  if b.path:startswith("oil://") then
    basename = u.paths.sep .. basename
  end
  return M.def_hooks.buf_name({
    id = 0,
    path = b.path,
    basename = basename,
    dirname = u.paths.dirname(b.path),
    current = false,
  }, i, bufs, unique_names)
end

--- Default hook for hook_buf_list. Gets the first n recent buffers followed by all pinned buffers.
---@param bufs Beez.codestacks.buf[]
---@return Beez.codestacks.buf[]
function M.def_hooks.buf_list(bufs)
  ---@type Beez.codestacks.tabline.display_buf[]
  local display_bufs = {}
  local get_name = c.config.hook_buf_name or M.def_hooks.buf_name
  local get_pinned_name = c.config.hook_pinned_buf_name or M.def_hooks.pinned_buf_name

  -- Buf list is sorted already get the first n + 1 recent buffers
  local unique_names = {}
  for i, b in ipairs(bufs) do
    if i > #c.config.recent_labels + 1 then
      break
    end

    local name, hls = get_name(b, i, bufs, unique_names)
    unique_names[name] = true
    local display_buf = {
      name = hls,
      pinned = false,
      label = { "", "" },
    }

    -- Dont set label on the first, since its always the current buffer
    if i > 1 then
      local label, label_hl = c.config.recent_labels[i - 1], c.config.ui_recent_label_hl
      display_buf.label = { label, label_hl }
    end
    table.insert(display_bufs, display_buf)
  end

  local labels = {}
  -- Only display the labels
  local pinned_bufs = M.pinned.list()
  for _, p in ipairs(pinned_bufs) do
    labels[p.label] = true
  end
  for _, char in ipairs({
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
  }) do
    if labels[char] then
      table.insert(display_bufs, {
        label = { char, c.config.ui_pin_label_hl },
        name = { { "", "" } },
        pinned = true,
        space = false,
      })
    else
      table.insert(display_bufs, {
        label = { char, "Comment" },
        name = { { "", "" } },
        pinned = true,
        space = false,
      })
    end
  end

  -- -- Reset unique names for pinned buffers
  -- local unique_names = {}
  -- -- Now display all pinned buffers
  -- local pinned_bufs = M.pinned.list({ not_temp = true })
  -- -- Sort alphabetically by label
  -- table.sort(pinned_bufs, function(a, b)
  --   return a.label < b.label
  -- end)
  --
  -- for _, b in ipairs(pinned_bufs) do
  --   -- Pinned buffers already has label assigned, no need to calculate it
  --   local name, hls = get_pinned_name(b, i, pinned_bufs, unique_names)
  --   unique_names[name] = true
  --   table.insert(display_bufs, {
  --     label = { b.label, c.config.ui_pin_label_hl },
  --     name = hls,
  --     pinned = true,
  --   })
  -- end

  return display_bufs
end

--- Default hook for hook_ui_refresh.
---@param bufs Beez.codestacks.buf[]
function M.def_hooks.ui_refresh(bufs)
  if debug_tabline then
    M.ui.get_tabline()
  end
  if H.init_tabline then
    vim.cmd("redrawtabline")
    return
  end
  if not debug_tabline then
    vim.opt.showtabline = 2
    vim.opt.tabline = "%!v:lua.Codestacks.ui.get_tabline()"
  end
  H.init_tabline = true
end

--- Setup the plugin
---@param config Beez.codestacks.config
function M.setup(config)
  c.setup(config)

  local hook_session_name = c.config.hook_session_name or M.def_hooks.default_hook_session_name
  M.config = c.config
  M.session = hook_session_name()

  M.bl = Bufferlist:new()

  local base_path = debug.getinfo(1).source:match("@?(.*/)")
  call_backend(be.init_tracing, vim.fs.joinpath(base_path, "logs", "codestacks.log"), "info")
  call_backend(be.setup, M.session, c.config.data_dir, c.config.recent_files_limit)
  setup_autocmds()
  hl.init()

  -- Need global for tabline
  _G.Codestacks = M
end

--- Creates a new stack
function M.stacks.add()
  vim.ui.input({ prompt = "Give your new stack a name: " }, function(res)
    if res == nil then
      return
    end
    local ok, _ = call_backend(be.add_stack, res)
    if ok then
      vim.schedule(function()
        M.ui.refresh()
      end)
    end
  end)
end

--- Removes a stack by name
---@param name string
---@return Beez.codestacks.Stack?
function M.stacks.remove(name)
  local choice = vim.fn.confirm("Are you sure you want to remove stack: " .. name, "&Yes\n&No")
  if choice == 1 then
    local ok, stack = call_backend(be.remove_stack, name)
    if ok then
      vim.schedule(function()
        M.ui.refresh()
      end)
    end
    return stack
  end
end

--- Renames an existing stack
---@param name string
function M.stacks.rename(name)
  vim.ui.input({ prompt = "Edit stack name: ", default = name }, function(res)
    if res == nil or res == name then
      return
    end
    local ok, _ = call_backend(be.rename_stack, name, res)
    if ok then
      vim.schedule(function()
        M.ui.refresh()
      end)
    end
  end)
end

--- Checks if stack is active
---@param name string
---@return boolean
function M.stacks.is_active(name)
  local ok, active = call_backend(be.is_active_stack, name)
  if not ok then
    return false
  end
  return active
end

--- Sets the active stack
---@param name string
function M.stacks.set_active(name)
  local ok, _ = pcall(be.set_active_stack, name)
  if ok then
    vim.schedule(function()
      M.ui.refresh()
    end)

    -- -- Load all pinned buffers in the stack
    -- local pinned = M.pinned.list()
    -- for _, p in ipairs(pinned) do
    --   local bufnr = vim.fn.bufadd(p.path)
    --   vim.fn.bufload(bufnr)
    --   vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    -- end
  end
end

--- List all stacks
---@return table
function M.stacks.list()
  local ok, stacks = call_backend(be.list_stacks)
  if not ok then
    return {}
  end
  return stacks
end

--- Gets a stack by name
---@param name? string
---@return Beez.codestacks.Stack?
function M.stacks.get(name)
  local ok, stack = call_backend(be.get_stack, name)
  if not ok then
    return nil
  end
  return stack
end

--- Gets the current active stack name
---@return string
function M.stacks.get_active()
  local _, active = call_backend(be.get_active_stack)
  return active or ""
end

--- Pins the current buffer with label
---@param opts? {label?: string, temp?: boolean}
function M.pinned.pin(opts)
  opts = opts or {}
  local ok, active_stack = call_backend(be.get_active_stack)
  if not ok then
    return
  end
  -- Make sure at least one stack exists
  if active_stack == nil then
    vim.ui.input({ prompt = "Give your first stack a name: " }, function(res)
      if res == nil then
        return
      end
      M.pin_buffer(opts)
    end)
  end

  local label = opts.label
  -- Use the next temp label if temp is true
  if opts.temp == true then
    local pinned = M.pinned.list()
    local pinned_label_map = {}
    for _, p in ipairs(pinned) do
      pinned_label_map[p.label] = true
    end

    -- Find first available temp label
    for _, l in ipairs(c.config.temp_labels) do
      if not pinned_label_map[l] then
        label = l
        break
      end
    end
  else
    if label == nil then
      label = opts.label or vim.fn.nr2char(vim.fn.getchar())
      local hook_is_valid_label = c.config.hook_label_is_valid or M.def_hooks.is_valid_label
      if not hook_is_valid_label(label) then
        return
      end
    end
  end

  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    return
  end
  local ok, _ = call_backend(be.pin_buffer, filename, label)
  if ok then
    vim.notify("Pinned buffer with label: " .. label, vim.log.levels.INFO)
    M.ui.refresh()
  end
end

--- Unpins the current buffer
---@param path? string
function M.pinned.unpin(path)
  path = path or vim.api.nvim_buf_get_name(0)
  local pinned_buf = M.pinned.get(path)
  local ok, _ = call_backend(be.unpin_buffer, path)
  if ok then
    if pinned_buf ~= nil then
      vim.notify("Unpinned buffer with label: " .. pinned_buf.label, vim.log.levels.INFO)
    else
      vim.notify("Unpinned current buffer...", vim.log.levels.INFO)
    end
    M.ui.refresh()
  end
end

--- Returns a list of pinned buffers for current stack
---@param opts? {temp?: boolean, not_temp?: boolean}
---@return Beez.codestacks.PinnedBuffer[]
function M.pinned.list(opts)
  opts = opts or {}
  local ok, pinned_buffers = call_backend(be.list_pinned_buffers)
  if not ok then
    return {}
  end

  local buffers = {}
  local temp_labels_map = {}
  for _, l in ipairs(c.config.temp_labels) do
    temp_labels_map[l] = true
  end

  -- Return pinned buffers with temp labels only
  if opts.temp == true then
    for _, p in ipairs(pinned_buffers) do
      if temp_labels_map[p.label] then
        table.insert(buffers, p)
      end
    end
    return buffers
  -- Return pinned buffers without temp labels
  elseif opts.not_temp == true then
    for _, p in ipairs(pinned_buffers) do
      if not temp_labels_map[p.label] then
        table.insert(buffers, p)
      end
    end
    return buffers
  else
    return pinned_buffers
  end
end

--- Show a floating window that list all pinned bufs in vertical list
---@param opts? table
function M.pinned.show(opts)
  opts = opts or {}
  local NuiLine = require("nui.line")
  local NuiPopup = require("nui.popup")
  local popup = NuiPopup({
    enter = false,
    focusable = true,
    zindex = 50,
    border = {
      style = "rounded",
      -- style = { "│", " ", "│", "│", "╯", "─", "╰", "│" },
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  local i = 1
  local longest_line = 1
  local function render_line(line)
    local len = #line:content()
    if len > longest_line then
      longest_line = len
    end
    line:render(popup.bufnr, -1, i)
  end

  -- Render non temp pinned buffers first
  local pinned = M.pinned.list({ not_temp = true })
  table.sort(pinned, function(a, b)
    return a.label < b.label
  end)
  for _, p in ipairs(pinned) do
    local line = NuiLine()
    line:append("  ")
    local basename = u.paths.basename(p.path)
    local label_idx, _, _ = basename:find(p.label, 1, true)
    local dirname = u.paths.dirname(p.path):gsub(vim.env.HOME, "~")
    if label_idx ~= nil then
      line:append(basename:sub(1, label_idx - 1), c.config.ui_name_hl)
      line:append(p.label, c.config.ui_pin_label_hl)
      line:append(basename:sub(label_idx + 1), c.config.ui_name_hl)
    else
      line:append(p.label, c.config.ui_pin_label_hl)
      line:append(basename, c.config.ui_name_hl)
    end
    line:append(" ")
    line:append(dirname, c.config.ui_dir_hl)
    render_line(line)
    i = i + 1
  end

  -- Render temp pinned buffers next
  pinned = M.pinned.list({ temp = true })
  table.sort(pinned, function(a, b)
    return a.label < b.label
  end)
  if #pinned > 0 then
    -- Blank line
    local line = NuiLine()
    line:append("")
    render_line(line)
    i = i + 1
  end
  for _, p in ipairs(pinned) do
    local line = NuiLine()
    line:append("  ")
    local basename = u.paths.basename(p.path)
    local dirname = u.paths.dirname(p.path):gsub(vim.env.HOME, "~")
    line:append("[" .. p.label .. "]", "Comment")
    line:append(basename, "Comment")
    line:append(" ")
    line:append(dirname, c.config.ui_dir_hl)
    render_line(line)
    i = i + 1
  end

  -- Render any extra lines passed in opts
  if opts.lines then
    -- Blank line
    local line = NuiLine()
    line:append("")
    render_line(line)
    i = i + 1
  end
  for _, l in ipairs(opts.lines or {}) do
    local line = NuiLine()
    line:append("  ")
    line:append("[" .. l.label .. "]", "Comment")
    line:append(l.text, l.hl)
    render_line(line)
    i = i + 1
  end

  popup:update_layout({
    position = {
      row = 1,
      col = "100%",
    },
    relative = "editor",
    size = {
      width = longest_line,
      height = i,
    },
  })
  popup:mount()
  return popup
end

--- Finds a pinned buffer by path
---@param path string
---@return Beez.codestacks.PinnedBuffer?
function M.pinned.get(path)
  local _, pinned_buf = call_backend(be.get_pinned_buffer, path)
  return pinned_buf
end

--- Returns a list of active buffers sorted by recency
---@return Beez.codestacks.buf[]
function M.bufferlist.list()
  local _, recent_files = call_backend(be.list_recent_files)
  local buffers = M.bl:list(recent_files)
  return buffers
end

--- Checks if a buffer is valid
---@param buf Beez.codestacks.buf
---@return boolean
function M.bufferlist.is_valid(buf)
  local hook_is_valid_buf = c.config.hook_buf_is_valid or M.def_hooks.default_hook_buf_is_valid
  local is_valid = hook_is_valid_buf(buf.id)
  if not is_valid then
    return false
  end
  return M.bl.is_buf_valid(buf)
end

--- Pick a specific buffer to jump to by label
---@param label? string
---@return boolean
function M.pinned.pick(label)
  label = label or vim.fn.nr2char(vim.fn.getchar())
  local hook_is_valid_label = c.config.hook_label_is_valid or M.def_hooks.is_valid_label
  if not hook_is_valid_label(label) then
    return false
  end

  -- Pick a recent buffer
  local recent_i, found_recent = u.tables.find(c.config.recent_labels, function(l)
    return l == label
  end)
  local bufs = M.bufferlist.list()
  if found_recent ~= nil then
    local buf = bufs[recent_i + 1]
    if buf ~= nil then
      vim.cmd.edit(buf.path)
      return true
    end
  end

  -- Pick a pinned buffer
  local ok, pinned_buffers = call_backend(be.list_pinned_buffers)
  if ok then
    local pinned_buf
    for _, p in ipairs(pinned_buffers) do
      if p.label == label then
        pinned_buf = p
        break
      end
    end
    if pinned_buf ~= nil then
      vim.cmd.edit(pinned_buf.path)
      return true
    end
  end
  return false
end

--- Enables recent files tracking
function M.recentfiles.enable()
  call_backend(be.enable_recent_files, true)
end

--- Disables recent files tracking
function M.recentfiles.disable()
  call_backend(be.enable_recent_files, false)
end

--- Returns the list of recent files
---@return string[]
function M.recentfiles.list()
  local _, list = call_backend(be.list_recent_files)
  return list
end

--- Refresh the ui with new buffer list
function M.ui.refresh()
  local hook_ui_refresh = c.config.hook_ui_refresh
  if hook_ui_refresh ~= nil then
    local bufs = M.ui.list()
    return hook_ui_refresh(bufs)
  end
  M.def_hooks.ui_refresh({})
end

--- Returns a list of buffer objects to be displayed
---@return Beez.codestacks.buf[]
function M.ui.list()
  local bufs = M.bufferlist.list()
  local hook_buf_list = c.config.hook_buf_list or M.def_hooks.buf_list
  bufs = hook_buf_list(bufs)
  return bufs
end

--- Generate a tabline to be displayed
---@return string
function M.ui.get_tabline()
  local bufs = M.ui.list()
  return tabline.get(M.stacks.get_active() or "", bufs)
end

--- Add a new global mark
function M.marks.add()
  vim.ui.input({ prompt = "Describe the mark: " }, function(res)
    if res == nil then
      return
    end

    local path = vim.api.nvim_buf_get_name(0)
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    call_backend(be.add_global_mark, path, res, line, pos[1])
  end)
end

--- Returns a list of global marks
---@param opts? {all?: boolean, path?: string}
---@return Beez.codestacks.GlobalMark[]
function M.marks.list(opts)
  opts = opts or {}
  if opts.all == true then
    local _, gmarks = call_backend(be.list_all_global_marks)
    return gmarks
  end
  local _, gmarks = call_backend(be.list_global_marks, opts.path)
  return gmarks
end

--- Update a global mark
---@param path string
---@param lineno integer
---@param updates {desc?: string, lineno?: integer}
function M.marks.update(path, lineno, updates)
  call_backend(be.update_global_mark, path, lineno, updates.lineno, updates.desc)
end

--- Delete a global mark
---@param path string
---@param lineno integer
function M.marks.remove(path, lineno)
  call_backend(be.remove_global_mark, path, lineno)
end

--- Checks whether a mark needs
---@param path string
---@param lineno integer
---@param old_line string
---@param save fun(integer)
local function check_for_outdated_marks(path, lineno, old_line, save)
  local line = u.os.read_line_at(path, lineno)
  -- If the line has changed, update the mark
  if line ~= old_line then
    -- Look for the new line number
    local new_lineno = vim.fn.search(old_line, "n")
    new_lineno = new_lineno or vim.fn.search(old_line, "nb")
    if new_lineno > 0 and new_lineno ~= lineno then
      save(new_lineno)
    end
  end
end

--- Checks current file for any outdated marks
---@param path string
function M.marks.check_for_outdated(path)
  -- Get all global marks for path
  local _, gmarks = call_backend(be.list_global_marks, path)
  for _, m in ipairs(gmarks) do
    check_for_outdated_marks(m.file, m.lineno, m.line, function(new_lineno)
      call_backend(be.update_global_mark, m.path, m.lineno, new_lineno, nil)
      vim.notify("Updated mark [" .. m.desc .. "] to lineno: " .. new_lineno, vim.log.levels.INFO)
    end)
  end

  -- local marks = M._marks:list({ file = filename })
  -- for _, m in ipairs(marks) do
  --   check_for_outdated_marks(m.file, m.lineno, m.line, function(new_lineno)
  --     m:update({ lineno = new_lineno })
  --     save = true
  --     vim.notify(
  --       "Updated mark at " .. m.file .. ":" .. m.lineno .. " to lineno: " .. new_lineno,
  --       vim.log.levels.INFO
  --     )
  --   end)
  -- end
end

return M
