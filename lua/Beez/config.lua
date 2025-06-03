local M = {}

---@class Beez.config
---@field flotes Beez.flotes.config?
---@field bufswitcher Beez.bufswitcher.config?
---@field scratches Beez.scratches.config?
---@field codemarks Beez.codemarks.config?
---@field dbfp Beez.dbfp.config?

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
  require("Beez.u").setup(opts)

  if M.config.flotes then
    require("Beez.flotes").setup(M.config.flotes)
  end
  if M.config.bufswitcher then
    require("Beez.bufswitcher").setup(M.config.bufswitcher)
  end
  if M.config.scratches then
    require("Beez.scratches").setup(M.config.scratches)
  end
  if M.config.codemarks then
    require("Beez.codemarks").setup(M.config.codemarks)
  end
  if M.config.dbfp then
    require("Beez.dbfp").setup(M.config.dbfp)
  end
end

return M
