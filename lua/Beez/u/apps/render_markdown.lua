local M = {}

function M.opts(opts)
  opts = opts or {}
  return function()
    return vim.tbl_deep_extend("keep", opts, {
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        sign = false,
        icons = {},
      },
      checkbox = {
        enabled = false,
      },
      bullet = {
        enabled = false,
      },
      ft = { "markdown", "norg", "rmd", "org", "codecompanion" },
    })
  end
end

function M.spec(opts)
  opts = opts or {}
  local spec = vim.tbl_deep_extend("keep", opts, {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = M.opts(opts.override_opts),
  })

  spec.override_opts = nil
  return spec
end

return M
