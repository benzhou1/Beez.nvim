local c = require("Beez.dbfp.config")
local u = require("Beez.u")

---@class Beez.dbfp
---@field config Beez.dbfp.config
---@field queryfiles Beez.dbfp.queryfiles
---@field cons Beez.dbfp.connections
---@field qf Beez.dbfp.queryfile?
---@field float Beez.ui.float?
---@field path string?
---@field query string?
local M = {
  float = nil,
  qf = nil,
  path = nil,
  query = nil,
  last_dbout = nil,
}

--- Setup dbfp plugin
---@param opts Beez.dbfp.config
function M.setup(opts)
  c.init(opts)

  -- Ensure the dbfp_path exists
  local dbfp_path = u.paths.Path:new(c.config.dbfp_path)
  if not dbfp_path:exists() then
    dbfp_path:mkdir()
  end

  M.config = c.config
  M.cons = require("Beez.dbfp.connections"):new()
  M.queryfiles = require("Beez.dbfp.queryfiles"):new()

  -- Set filetype for dbout buffers
  local events = require("nui.utils.autocmd").event
  vim.api.nvim_create_autocmd({ events.BufRead, events.BufNewFile }, {
    pattern = { "*.dbout" },
    callback = function(event)
      vim.bo.filetype = "dbout"
      local filename = vim.api.nvim_buf_get_name(event.buf)
      M.last_dbout = filename
    end,
  })
end

--- Attach dadbod completion to the current buffer based on buf
---@param buf integer
function M.attach_db_completion(buf)
  local filepath = vim.api.nvim_buf_get_name(buf)
  local qf = M.queryfiles:get(filepath)
  if qf == nil then
    return
  end

  -- Attach dadbod completion
  if qf.connection then
    vim.b.db = M.cons:get(qf.connection)
  end
  if qf.table then
    vim.b.db_table = qf.table
  end
end

--- Initialize dadbod with current connection string
---@param opts? {buf: integer?, connection: string?}
function M.init_dadbod(opts)
  opts = opts or {}
  local connection = opts.connection
  if opts.buf then
    local filepath = vim.api.nvim_buf_get_name(opts.buf)
    local qf = M.queryfiles:get(filepath)
    if qf == nil then
      return
    end
    connection = qf.connection
  end

  if connection then
    local con_str = M.cons:get(connection)
    vim.cmd("DB g:" .. connection .. " = " .. con_str)
  end
end

--- Returns a float instance
---@return Beez.ui.float
local function get_float()
  ---@type Beez.ui.float.opts
  local opts = {
    win = {
      x = u.nvim.percent_to_col(0.25),
      y = u.nvim.percent_to_row(0.2),
      h = u.nvim.percent_to_row(0.5),
      w = u.nvim.percent_to_col(0.5),
      relative = "editor",
      border = "rounded",
      set_win_opts_cb = function(win)
        vim.api.nvim_set_option_value("wrap", true, { scope = "local", win = win })
      end,
    },
    keymaps = {
      quit = "q",
      buf_keymap_cb = c.config.float.buf_keymap_cb,
    },
    buffer = {
      del_bufs_on_close = true,
      show_buf_cb = function(buf)
        if c.config.float.buf_show_cb then
          c.config.float.buf_show_cb(buf)
        end

        M.attach_db_completion(buf)
        M.init_dadbod({ buf = buf })
      end,
    },
    set_title_filename = true,
    open_win_cb = function(win)
      if c.config.float.open_win_cb then
        c.config.float.open_win_cb(win)
      end

      M.queryfiles:init_autocmds()
    end,
    close_win_cb = function(win)
      if c.config.float.close_win_cb then
        c.config.float.close_win_cb(win)
      end

      M.queryfiles:del_autocmds()
    end,
  }

  if M.float == nil then
    M.float = require("Beez.ui.float").Float:new(opts)
  end
  return M.float
end

--- Open the last dbout file
function M.open_last_dbout()
  if M.last_dbout == nil then
    return
  end

  vim.cmd("pedit " .. M.last_dbout)
  vim.schedule(function()
    M.focus_dbout()
  end)
end

--- Opens a query file in a floating window
---@param path string?
---@param opts {search?: string}?
function M.open_query_file(path, opts)
  opts = opts or {}
  path = path or M.path
  if path == nil and M.qf then
    path = M.qf.path.filename
  end
  if path == nil then
    return
  end

  local float = get_float()
  float:show(path)
  M.path = path

  vim.schedule(function()
    if opts.search then
      -- vim.fn.search(opts.search, "c")
      vim.fn.search("\\V" .. opts.search, "c")
    end
  end)
end

--- Execute query from selection
---@param opts table?
function M.execute_query(opts)
  opts = opts or {}
  local connection = nil
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  M.path = vim.api.nvim_buf_get_name(buf)
  M.qf = M.queryfiles:get(M.path)

  if M.qf == nil then
    connection = M.cons:get_active()
  else
    connection = M.qf.connection
  end

  -- Need to prompt user to select a connection if not set
  if connection == nil then
    return require("Beez.pickers").pick(
      "dbfp.connections",
      { type = "deck", default_action = "dbfp.set_active_connection" }
    )
  end

  local text = u.nvim.get_visual_selection()
  -- Remove the trailing semicolon
  if text:endswith(";") then
    text = text:sub(1, -2)
  end

  local lines = vim.split(text, "\n", { plain = true })
  -- Remove the comment line
  if lines[1]:startswith("--") then
    table.remove(lines, 1)
  end

  M.query = lines[1]
  local query = table.concat(lines, " ")
  vim.cmd("DB g:" .. connection .. " " .. query)
end

--- Executes a query string
---@param connection string
---@param query string
---@param opts? {qf: Beez.dbfp.queryfile}?
function M.execute_raw_query(connection, query, opts)
  opts = opts or {}
  if opts.qf then
    M.qf = opts.qf
  end
  M.init_dadbod({ connection = connection })
  M.query = query
  vim.cmd("DB g:" .. connection .. " " .. query)
end

--- Edit the last query in a float window
---@param opts table?
function M.edit_last_query(opts)
  opts = opts or {}
  local last_query = vim.b.db_input
  local float = M.float
  if float == nil then
    float = get_float()
  end

  float:show(last_query)
  vim.schedule(function()
    local buf = vim.api.nvim_win_get_buf(M.float.win_id)
    u.keymaps.set({
      {
        "<CR>",
        function()
          if M.qf == nil or M.qf.connection == nil then
            return
          end

          vim.cmd("w")
          vim.cmd("DB g:" .. M.qf.connection .. " < " .. last_query)
          M.close()
          M.focus_dbout()
        end,
        desc = "Execute query",
        buffer = buf,
      },
    })
  end)
end

--- Check if float is open
---@return boolean
function M.is_open()
  return M.float ~= nil and M.float:is_open()
end

--- Close float
function M.close()
  if M.float ~= nil then
    M.float:close()
  end
end

--- Attempts to find the dbout window and focus it
---@param opts table?
function M.focus_dbout(opts)
  opts = opts or {}
  vim.cmd("wincmd k")
  vim.schedule(function()
    local ft = vim.bo.filetype
    if ft ~= "dbout" then
      local max_attempts = 10
      while ft ~= "dbout" and max_attempts > 0 do
        vim.cmd("wincmd w")
        ft = vim.bo.filetype
        max_attempts = max_attempts - 1
      end
    end
  end)
end

--- Deletes a connection by name
---@param name string
function M.delete_connection(name)
  M.cons:delete(name)
  M.queryfiles:remove_connection(name)
end

--- Renames a connection name
---@param name string
---@param new_name string
function M.rename_connection(name, new_name)
  M.cons:rename(name, new_name)
  M.queryfiles:rename_connection(name, new_name)
end

return M
