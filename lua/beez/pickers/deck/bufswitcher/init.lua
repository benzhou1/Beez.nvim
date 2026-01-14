local actions = require("beez.pickers.deck.bufswitcher.actions")
local sources = require("beez.pickers.deck.bufswitcher.sources")
local M = {}

--- Deck picker for bufswitcher stacks
---@param opts table
function M.stacks(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { prompt = true })
  local source, specifier = sources.stacks(opts)
  require("deck").start(source, specifier)
end

M.actions = actions
M.sources = sources
return M
