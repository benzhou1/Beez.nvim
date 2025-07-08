local u = require("Beez.u")
local M = { config = {} }

---@class Beez.bufswitcher.config
---@field hooks? Beez.bufswitcher.config.hooks
---@field win? Beez.bufswitcher.config.win
---@field keymaps? Beez.bufswitcher.config.keymaps
---@field ui? Beez.bufswitcher.config.ui
---@field autocmds? Beez.bufswitcher.config.autocmds
---@field pins_path? string

---@class Beez.bufswitcher.config.hooks
---@field sort? fun(bufs: Beez.bufswitcher.buf[]): Beez.bufswitcher.buf[]
---@field get_char? fun(name: string, chars: table<string, boolean>): string?
---@field get_dirname? fun(buf: Beez.bufswitcher.buf, filename: string, dirnames: table<string, boolean>): string
---@field get_filename? fun(buf: Beez.bufswitcher.buf, filenames: table<string, boolean>): string

---@class Beez.bufswitcher.config.win
---@field popup? nui_popup_options
---@field get_popup_opts? fun(): nui_popup_options
---@field use_noneckpain? boolean

---@class Beez.bufswitcher.config.keymaps
---@field pick_chars? string
---@field index_chars? string[]
---@field del_buf? string
---@field pin_buf? string
---@field quit? string
---@field pinned_chars? string[]

---@class Beez.bufswitcher.config.ui
---@field show_char_col? boolean
---@field show_char_labels? boolean
---@field highlights? Beez.bufswitcher.config.ui.highlights

---@class Beez.bufswitcher.config.ui.highlights
---@field curr_buf? string
---@field filename? string
---@field dirname? string
---@field char_label? string
---@field pin_char? string
---@field index_char? string

---@class Beez.bufswitcher.config.autocmds
---@field valid_buf_enter? fun(event: table): boolean

---@type Beez.bufswitcher.config
M.def_config = {
  pins_path = vim.fn.stdpath("data") .. "/Beez/bufswitcher/pins.txt",
  autocmds = {
    valid_buf_enter = nil,
  },
  ui = {
    show_char_col = false,
    show_char_labels = true,
    highlights = {
      curr_buf = "CursorLine",
      filename = "Normal",
      dirname = "Comment",
      char_label = "CurSearch",
      pin_char = "Search",
      index_char = "Comment",
    },
  },
  hooks = {
    sort = nil,
    get_char = nil,
    get_dirname = nil,
    get_filename = nil,
  },
  keymaps = {
    pick_chars = "abcdefghijklmnopqrstuvwxyz",
    pinned_chars = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    index_chars = {},
    del_buf = "<C-d>",
    pin_buf = "<C-p>",
    quit = "<Esc>",
  },
  win = {
    use_noneckpain = true,
    staty_opened = false,
    get_popup_opts = nil,
    popup = {
      enter = true,
      focusable = true,
      position = "100%",
      relative = "editor",
      size = {
        width = "33%",
        height = "25%",
      },
      border = {
        style = "rounded",
      },
    },
  },
}

--- Initialize config
---@param opts Beez.bufswitcher.config?
function M.init(opts)
  opts = opts or {}
  M.config = M.def_config
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.pins_path = vim.fn.expand(M.config.pins_path)

  local pins_path = u.paths.Path:new(M.config.pins_path)
  local pins_dir = pins_path:parent()
  if not pins_path:exists() then
    if not pins_dir:exists() then
      pins_dir:mkdir({ parents = true })
    end
    pins_path:write("", "w")
  end
end

return M
