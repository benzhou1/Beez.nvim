local M = {}

function M.spec(opts)
  opts = opts or {}
  local spec = vim.tbl_deep_extend("keep", opts, {
    dir = "~/Projects/nvim_forks/codemarks.nvim",
    opts = {
      marks_file = vim.fn.expand("~/SynologyDrive/codemarks.txt"),
    },
    config = function(_, opts)
      require("Beez.codemarks").setup(opts)
    end,
  })
  return spec
end

return M
