local M = {}
local actions = require("beez.pickers.deck.projects.actions")
local sources = require("beez.pickers.deck.projects.sources")

--- Deck picker for lazygit projects
---@param opts? table
---@return deck.Context
function M.lazygit(opts)
  opts = vim.tbl_deep_extend("keep", { default_action = actions.open_lazygit.name }, opts or {})
  local source, specifier = sources.projects(opts)
  return require("deck").start(source, specifier)
end

--- Deck picker for neohub projects
---@param opts? table
---@return deck.Context
function M.neohub(opts)
  opts = opts or {}
  local source, specifier = sources.projects(opts)
  return require("deck").start(source, specifier)
end

return M
