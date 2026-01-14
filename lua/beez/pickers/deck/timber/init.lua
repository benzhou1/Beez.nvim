local sources = require("beez.pickers.deck.timber.sources")
local M = {}

--- Deck picker for debug log statements
---@param opts? table
function M.log_statements(opts)
  opts = opts or {}
  local source, specifier = sources.log_statements(opts)
  require("deck").start(source, specifier)
end

return M
