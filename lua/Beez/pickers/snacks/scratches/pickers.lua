local M = { scratches = { actions = {} } }

--- Snacks picker for finding scratch files
---@param opts table?
function M.find(opts)
  local scratches = require("scratches")
  local cwd = scratches.config.scratch_dir

  opts = vim.tbl_deep_extend("keep", {
    cwd = cwd,
    confirm = M.scratches.actions.confirm,
    actions = {
      delete = M.scratches.actions.delete,
    },
    win = {
      input = {
        keys = {
          ["<c-x>"] = {
            "delete",
            mode = { "n", "i" },
          },
        },
      },
    },
  }, opts or {})
  require("snacks.picker").files(opts)
end

return M
