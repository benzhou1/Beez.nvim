local hl = require("beez.bufswitcher.highlights")
local u = require("beez.u")

local M = {}

---@class Beez.bufswitcher.config
---@field data_dir? string Path to the directory where data is persisted
---@field hook_session_name? fun(): string Function to determine the session name
---@field hook_buf_is_valid? fun(bufnr: integer): boolean Function to determine if a buffer is valid and shuuld be added to the list
---@field hook_buf_sort? fun(bufs: Beez.bufswitcher.buf[]): Beez.bufswitcher.buf[] Function to sort buffers after every addition/removal
---@field hook_buf_recent_label? fun(buf:Beez.bufswitcher.buf, i: integer, bufs: Beez.bufswitcher.buf[]): string Returns a label to assign to current buffer
---@field hook_buf_name? fun(buf:Beez.bufswitcher.buf, i: integer, bufs: Beez.bufswitcher.buf[], unique_names: table<string, boolean>): string, string[][] Returns a name to be displayed with highlight groups
---@field hook_buf_list? fun(bufs: Beez.bufswitcher.buf[]): Beez.bufswitcher.tabline.display_buf Returns a list of buffers to be displayed
---@field hook_ui_refresh? fun(bufs: Beez.bufswitcher.buf[]) Function to refresh the UI, will override default view render
---@field ui_curr_buf_hl? string Highlight group for the current buffer
---@field ui_name_hl? string Highlight group for the buffer name
---@field ui_dir_hl? string Highlight group for the buffer dir
---@field ui_recent_label_hl? string Highlight group for recent buffer labels
---@field ui_pin_label_hl? string Highlight group for pinned buffer characters
---@field ui_stack_hl? string Highlight group for stack name
---@field ui_stack_sep_hl? string Highlight group for stack name separator
---@field ui_buf_sep_hl? string Highlight group for buffer list separator
---@field ui_pin_sep_hl? string Highlight group for pinened buffer list separator
---@field recent_labels? string[] List of characters to use for recent buffers
---@field cycle_pinned_wrap? boolean Whether to wrap around when cycling through pinned buffers
---@field recent_list_limit? integer Maximum number of recent files to persist

---@type Beez.bufswitcher.config
M.def_config = {
  data_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "bufswitcher"),

  hook_buf_is_valid = nil,
  hook_buf_sort = nil,
  hook_buf_recent_label = nil,
  hook_buf_name = nil,
  hook_buf_list = nil,
  hook_ui_refresh = nil,

  ui_curr_buf_hl = hl.hl.current_buf,
  ui_separator_hl = hl.hl.separator,
  ui_name_hl = hl.hl.name,
  ui_dir_hl = hl.hl.dir,
  ui_recent_label_hl = hl.hl.recent_label,
  ui_pin_label_hl = hl.hl.pin_label,
  ui_stack_hl = hl.hl.stack,
  ui_stack_sep_hl = hl.hl.stack_sep,
  ui_buf_sep_hl = hl.hl.buf_sep,
  ui_pin_sep_hl = hl.hl.pin_sep,

  recent_labels = { ";", "/", "." },
  cycle_pinned_wrap = true,
  recent_list_limit = 1000,
}

--- Initialize config
---@param opts Beez.bufswitcher.config?
function M.init(opts)
  opts = opts or {}
  ---@type Beez.bufswitcher.config
  M.config = M.def_config
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.data_dir = vim.fn.expand(M.config.data_dir)

  local data_dir = u.paths.Path:new(M.config.data_dir)
  if not data_dir:exists() then
    if not data_dir:exists() then
      data_dir:mkdir({ parents = true })
    end
  end
end

return M
