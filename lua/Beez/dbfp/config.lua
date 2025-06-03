local M = {}

---@class Beez.dbfp.config
---@field dbfp_path string?
---@field float Beez.dbfp.float.config?

---@class Beez.dbfp.float.config
---@field buf_keymap_cb? fun(buf: integer): boolean
---@field buf_show_cb? fun(buf: integer): boolean
---@field close_win_cb? fun(win: integer): boolean
---@field open_win_cb? fun(win: integer): boolean

---@type Beez.dbfp.config
M.def_config = {
  float = {},
}

--- Initlaize the dbfp configuration
---@param opts Beez.dbfp.config?
function M.init(opts)
  opts = opts or {}

  M.config = vim.tbl_deep_extend("force", M.def_config, opts)

  if M.config.dbfp_path then
    M.config.dbfp_path = vim.fn.expand(M.config.dbfp_path)
  else
    return vim.notify("DBFP location not set in config", vim.log.levels.ERROR)
  end
end

return M
