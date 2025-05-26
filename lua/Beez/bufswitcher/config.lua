local M = {}

local modes = {
  preview = {
    timeout = {
      enabled = true,
    },
    preview = {
      enabled = true,
    },
    autocmds = {
      enabled = true,
    },
    popup = {
      enter = false,
      focusable = false,
      map_keys = false,
    },
  },
  popup = {
    timeout = {
      enabled = false,
    },
    preview = {
      enabled = false,
    },
    autocmds = {
      enabled = false,
    },
    popup = {
      enter = true,
      focusable = true,
      map_keys = true,
    },
  },
  timeout = {
    timeout = {
      enabled = true,
      value = 300,
    },
    preview = {
      enabled = false,
    },
    autocmds = {
      enabled = false,
    },
    popup = {
      enter = true,
      focusable = true,
      map_keys = false,
    },
  },
}

---@class Beez.bufswitcher.config.timeout
---@field enabled boolean? Enable timeout to close popup
---@field value integer? Milliseconds to keep popup open before selecting the current buffer to open

---@class Beez.bufswitcher.config.preview
---@field enabled boolean? Enable preview buffer

---@class Beez.bufswitcher.config.autocmds
---@field enabled boolean? Enable autocmds for cursor movements

---@class Beez.bufswitcher.config.highlights
---@field current_buf string? Highlight group for currently selected line in popup
---@field filename string? Highlight group for filename
---@field dirname string? Highlight group for dirname
---@field lnum string? Highlight group for line number

---@class Beez.bufswitcher.config.keymaps
---@field enabled boolean? Enable auto mapping of keys
---@field prev string? Keybind to use for switching to previous buffer. Set to false to disable.
---@field next string? Keybind to use for switching to next buffer. Set to false to disable.

---@class Beez.bufswitcher.config.hooks.options
---@field preview_bufnr integer? Preview buffer number, if preview is enabled
---@field prev_win_id integer Previous window id
---@field prev_buf table Previous buffer info
---@field target_buf table Target buffer info
---@field popup NuiPopup? Popup object

---@class Beez.bufswitcher.config.hooks
---@field before_show_preview fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run before showing preview buffer
---@field after_show_preview fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run before showing preview buffer
---@field before_show_target fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run after showing target buffer
---@field after_show_target fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run after showing target buffer
---@field before_show_popup fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run before showing popup menu
---@field after_show_popup fun(opts: Beez.bufswitcher.config.hooks.options)? Hook to run after showing popup menu

---@class Beez.bufswitcher.config
---@field log_warnings boolean? Log warnings
---@field timeout Beez.bufswitcher.config.timeout? Describes the timeout configuration
---@field preview Beez.bufswitcher.config.preview? Describes the preview configuration
---@field autocmds Beez.bufswitcher.config.autocmds? Describes the autocmds configuration
---@field highlights Beez.bufswitcher.config.highlights? Describes the highlights configuration
---@field keymaps Beez.bufswitcher.config.keymaps? Configure keymaps
---@field hooks Beez.bufswitcher.config.hooks? Configure hooks
---@field popup table? Options for nui popup buffer
---@field mode "preview" | "popup" | "timeout"? Pre configured modes, defaults to preview
---| "preview" - Preview of the target buffer is shown as buffers are cycled to create a seamless switching experience.
---   Any cursor movements or text changes will open the target buffer.
---   After elapsed timeout the target buffer will be opened.
---| "popup" - Preview is disabled and popup buffer list will be focused allowing you to select the buffer to open with <CR>.
---   Buffer list can be navigated with movement keys. You must manually choose which buffer to open with no timeout.
---| "timeout" - Same as popup, but with timeout only and no key mas. This mode resembles a switcher the most, but relies on timeout.
---| nil - Set to nil to ignore preconfigured modes and use custom configuration.
---@type Beez.bufswitcher.config
M.def_config = {
  mode = "preview",
  log_warnings = false,
  timeout = {
    enabled = true,
    value = 1000,
  },
  preview = {
    enabled = true,
  },
  autocmds = {
    enabled = true,
  },
  highlights = {
    current_buf = "Visual",
    filename = "Normal",
    dirname = "Comment",
    lnum = "DiagnosticInfo",
  },
  hooks = {
    before_show_preview = M.before_show_preview,
    after_show_preview = M.after_show_preview,
    before_show_target = M.before_show_target,
    after_show_target = M.after_show_target,
    after_show_popup = M.after_show_popup,
    before_show_popup = M.before_show_popup,
  },
  keymaps = {
    enabled = true,
    prev = "<C-S-Tab>",
    next = "<C-Tab>",
  },
  popup = {
    enter = false,
    focusable = false,
    map_keys = false,
    border = {
      style = "rounded",
      text = {
        top = "Buf Switcher",
        top_align = "left",
      },
    },
    relative = "editor",
    position = {
      row = "50%",
      col = "70%",
    },
    size = {
      width = 50,
      height = 10,
    },
  },
}

--- Initialize config
---@param opts Beez.bufswitcher.config?
function M.init(opts)
  opts = opts or {}
  -- Configure opts based on the mode
  if opts.mode ~= nil then
    local mode_config = modes[opts.mode]
    if mode_config == nil then
      mode_config = modes.preview
      opts.mode = "preview"
    end
    M.config = vim.tbl_deep_extend("keep", mode_config, M.config)
  end

  M.config = vim.tbl_deep_extend("force", M.def_config, opts or {})

  -- Make sure there are conflicting options
  if M.config.preview.enabled then
    M.config.popup.enter = false
    M.config.popup.focusable = false
  end
  if not M.config.popup.focusable then
    M.config.popup.enter = false
  end
end

return M
