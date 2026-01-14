local M = {}

---@class Beez.config
---@field flotes Beez.flotes.config?
---@field bufswitcher Beez.bufswitcher.config?
---@field scratches Beez.scratches.config?
---@field codemarks Beez.codemarks.config?
---@field dbfp Beez.dbfp.config?
---@field codestacks Beez.codestacks.config?
---@field cmdcenter Beez.cmdcenter.config?
---@field jj? table
---@field zk? table

---@type Beez.config
local def_config = {
  pickers = {
    type_priority = {
      "deck",
      "snacks",
      "fzf",
    },
  },
}

--- Initializes configuration with default
---@param opts Beez.config?
function M.init(opts)
  ---@type Beez.config
  M.config = vim.tbl_deep_extend("force", {}, def_config, opts or {})
  require("beez.u").setup(opts)

  if M.config.flotes then
    require("beez.flotes").setup(M.config.flotes)
  end
  if M.config.bufswitcher then
    require("beez.bufswitcher").setup(M.config.bufswitcher)
  end
  if M.config.scratches then
    require("beez.scratches").setup(M.config.scratches)
  end
  if M.config.codemarks then
    require("beez.codemarks").setup(M.config.codemarks)
  end
  if M.config.dbfp then
    require("beez.dbfp").setup(M.config.dbfp)
  end
  if M.config.codestacks then
    require("beez.codestacks").setup(M.config.codestacks)
  end
  if M.config.cmdcenter then
    require("beez.cmdcenter").setup(M.config.cmdcenter)
  end
  if M.config.jj then
    require("beez.jj").setup(M.config.jj)
  end
  if M.config.zk then
    require("beez.zk").setup(M.config.zk)
  end
end

return M
