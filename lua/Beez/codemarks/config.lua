local M = {}

---@class Beez.codemarks.config
---@field marks_file string? The path to the marks file
---@field auto_update_out_of_sync_marks boolean? Whether to automatically update marks that are out of sync in the current buffer

---@type Beez.codemarks.config
M.def_config = {
  marks_file = vim.fn.stdpath("data") .. "/codemarks/codemarks.txt",
  auto_update_out_of_sync_marks = false,
}

--- Initlaize config
---@param opts Beez.codemarks.config?
function M.init(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.def_config, opts)
end

return M
