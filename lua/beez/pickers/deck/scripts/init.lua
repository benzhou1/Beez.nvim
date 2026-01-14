local M = {}
local sources = require("beez.pickers.deck.scripts.sources")

--- Deck picker for custom scripts
---@param opts? table
---@return deck.Context
function M.scripts(opts)
  opts = opts or {}
  local source, specifier = sources.scripts(opts)
  local ctx = require("deck").start(source, specifier)
  if opts.quit_on_hide then
    ctx.on_hide(function()
      vim.schedule(function()
        vim.cmd("q")
      end)
    end)
  end
  return ctx
end

return M
