local M = {}

function M.spec(opts)
  opts = opts or {}
  return vim.tbl_deep_extend("keep", opts, {
    "nvim-lua/plenary.nvim",
  })
end

return M
