local M = {}
local u = require("Beez.u")

---@class Beez.codemarks.config
---@field marks_dir string? The path to the marks file
---@field auto_update_out_of_sync_marks boolean? Whether to automatically update marks that are out of sync in the current buffer
---@field get_root? fun(): string Function to get the root directory of the project, used to determine the path for marks

---@type Beez.codemarks.config
M.def_config = {
  marks_dir = vim.fn.stdpath("data") .. "/codemarks",
  auto_update_out_of_sync_marks = false,
  get_root = nil,
}

--- Initlaize config
---@param opts Beez.codemarks.config?
function M.init(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.def_config, opts)

  if M.config.get_root == nil then
    M.config.get_root = function()
      return u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
    end
  end
end

return M
