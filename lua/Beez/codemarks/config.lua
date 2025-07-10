local M = {}

---@class Beez.codemarks.config
---@field marks_dir string? The path to the marks file
---@field auto_update_out_of_sync_marks boolean? Whether to automatically update marks that are out of sync in the current buffer
---@field hooks Beez.codemarks.config.hooks? Hooks for codemarks events

---@class Beez.codemarks.config.hooks
---@field on_set_active_stack? fun(ols_stack: string, stack: string)? Hook called when a stack is set as active

---@type Beez.codemarks.config
M.def_config = {
  marks_dir = vim.fn.stdpath("data") .. "/codemarks",
  auto_update_out_of_sync_marks = false,
  hooks = {
    on_set_active_stack = nil,
  },
}

--- Initlaize config
---@param opts Beez.codemarks.config?
function M.init(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.def_config, opts)
end

return M
