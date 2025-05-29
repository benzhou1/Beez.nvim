local u = require("Beez.u")
local M = {}

---@class Beez.scratches.config
---@field scratch_dir string Directory to store scratch files
---@field keymaps Beez.scratches.config.keymaps? Keymaps for scratch files
---@field split_opts nui_split_options? Options for split window

---@class Beez.scratches.config.keymaps
---@field buf_keymaps fun(buf: integer)? Keymap to close scratch file

---@type Beez.scratches.config
M.def_config = {
  ---@diagnostic disable-next-line: assign-type-mismatch
  scratch_dir = nil,
  keymaps = {},
  split_opts = {
    relative = "editor",
    position = "bottom",
    size = "50%",
  },
}

--- Inistalize configuration
---@param opts Beez.scratches.config?
function M.init(opts)
  M.config = vim.tbl_deep_extend("force", M.def_config, opts or {})

  -- Scratches dir is required
  if M.config.scratch_dir == nil then
    return vim.notify("scratches: scratch_dir is not set", vim.log.levels.ERROR)
  end
  local scratch_dir = vim.fn.expand(M.config.scratch_dir)
  if not u.paths.Path:new(scratch_dir):exists() then
    return vim.notify(
      "scratches: scratch_dir=" .. scratch_dir .. " does not exist",
      vim.log.levels.ERROR
    )
  end
  M.config.scratch_dir = scratch_dir
end

return M
