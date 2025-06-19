local M = {}

---@class Beez.codemarks.config
---@field marks_dir string? The path to the marks file
---@field auto_update_out_of_sync_marks boolean? Whether to automatically update marks that are out of sync in the current buffer

---@type Beez.codemarks.config
M.def_config = {
  marks_dir = vim.fn.stdpath("data") .. "/codemarks",
  auto_update_out_of_sync_marks = false,
}

--- Initlaize config
---@param opts Beez.codemarks.config?
function M.init(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.def_config, opts)
end

return M
