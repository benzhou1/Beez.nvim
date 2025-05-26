local M = {}

function M.opts(opts)
  opts = opts or {}
  return function()
    return vim.tbl_deep_extend("keep", opts, {
      ensure_installed = {},
      auto_install = false,
      highlight = {
        enable = true,
      },
    })
  end
end

function M.config(_, opts)
  ---@diagnostic disable-next-line: missing-fields
  require("nvim-treesitter.configs").setup(opts)
end

function M.spec(opts)
  opts = opts or {}
  local spec = vim.tbl_deep_extend("keep", opts, {
    "nvim-treesitter/nvim-treesitter",
    opts = M.opts(opts.override_opts),
    config = M.config,
  })

  spec.override_opts = nil
  return spec
end

return M
