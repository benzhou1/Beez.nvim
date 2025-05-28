local M = {}

--- Deck for finding scratch files
---@param opts table
function M.find(opts)
  opts.cwd = require("Beez.scratches").config.scratch_dir
  local source, specifier = require("Beez.pickers").deck.sources.files(opts)
  require("deck").start(source, specifier)
end

return M
