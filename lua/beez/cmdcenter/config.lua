local M = {
  def_config = {
    target_dir = vim.fn.stdpath("data") .. "/cmdcenter",
    filename = "cmds",
    comments_pattern = "^%s*#",
    hooks = { tags = {} },
  },
}

---@class Beez.cmdcenter.hooks.taghooks
---@field on_output_open? fun(cmd: Beez.cmdcenter.cmd, winid: number, bufnr: number)

---@class Beez.cmdcenter.config.hooks
---@field tags table<string, Beez.cmdcenter.hooks.taghooks>

---@class Beez.cmdcenter.config
---@field target_dir? string
---@field filename? string
---@field comments_pattern? string
---@field hooks? Beez.cmdcenter.config.hooks

---@param opts Beez.cmdcenter.config?
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", {}, M.def_config or {}, opts or {})

  -- Expand target_dir
  M.config.target_dir = vim.fn.expand(M.config.target_dir)
  -- Make sure dir exists
  if vim.fn.isdirectory(M.config.target_dir) == 0 then
    vim.fn.mkdir(M.config.target_dir, "p")
  end
end

return M
