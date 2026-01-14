local M = {}

--- Deck for finding scratch files
---@param opts table
function M.find(opts)
  opts.cwd = require("beez.scratches").config.scratch_dir
  opts.source_opts = opts.source_opts or {}
  opts.source_opts.ignore_globs = opts.source_opts.ignore_globs or {}
  table.insert(opts.source_opts.ignore_globs, "*.pyc")
  table.insert(opts.source_opts.ignore_globs, "*__pycache__*")
  table.insert(opts.source_opts.ignore_globs, "*__init__.py")
  table.insert(opts.source_opts.ignore_globs, "*venv*")
  table.insert(opts.source_opts.ignore_globs, "*.DS_Store*")

  local source, specifier = require("beez.pickers").deck.sources.files(opts)
  require("deck").start(source, specifier)
end

return M
