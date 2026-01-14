local M = {}
local hl = require("beez.codestacks.highlights")

---@class Beez.codestacks.config
---@field data_dir string Directory to store codestacks data
---@field hook_session_name? fun(): string Function to determine the session name
---@field hook_buf_is_valid? fun(bufnr: integer): boolean Function to determine if a buffer is valid and shuuld be added to the list
---@field hook_label_is_valid? fun(label: string): boolean Function to determine if a label is valid
---@field hook_ui_refresh? fun(bufs: Beez.codestacks.buf[]) Function to refresh the UI, will override default view render
---@field hook_buf_list? fun(bufs: Beez.codestacks.buf[]): Beez.codestacks.tabline.display_buf Returns a list of buffers to be displayed
---@field hook_buf_name? fun(buf: Beez.codestacks.buf, i: integer, bufs: Beez.codestacks.buf[], unique_names: table<string, boolean>): string, string[][] Returns a name to be displayed with highlight groups
---@field hook_pinned_buf_name? fun(buf: Beez.codestacks.PinnedBuffer, i: integer, bufs: Beez.codestacks.PinnedBuffer[], unique_names: table<string, boolean>): string, string[][] Returns a name to be displayed with highlight groups
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
---@field temp_labels? string[] List of characters to use for temporary pinned buffers that can be cleared with keymap
---@field recent_files_limit? integer Maximum number of recent files to store

---@type Beez.codestacks.config
M.def_config = {
  data_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "codestacks"),

  hook_session_name = nil,
  hook_buf_is_valid = nil,
  hook_label_is_valid = nil,
  hook_ui_refresh = nil,
  hook_buf_list = nil,
  hook_buf_name = nil,
  hook_pinned_buf_name = nil,

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

  recent_labels = { ";", "/", ".", "," },
  temp_labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  recent_files_limit = 100,
}

function M.setup(opts)
  opts = opts or {}
  ---@type Beez.codestacks.config
  M.config = M.def_config
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.data_dir = vim.fn.expand(M.config.data_dir)
end

return M
