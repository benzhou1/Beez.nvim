local decorators = require("Beez.pickers.deck.decorators")
local formatters = require("Beez.pickers.deck.formatters")
local previewers = require("Beez.pickers.deck.previewers")
local M = {}

--- Resolves opts and source opts
---@param opts table?
---@vararg table
---@return table
function M.resolve_opts(opts, ...)
  opts = vim.tbl_deep_extend("force", {
    filename_first = true,
    buf_flags = false,
    cwd = vim.fn.getcwd(),
    source_opts = {
      ignore_globs = {
        "**/node_modules/**",
        "**/.git/**",
      },
      previewers = {
        previewers.neo_img,
      },
    },
    open_external = {
      quit = false,
    },
    open_zed = {
      quit = false,
    },
  }, ... or {}, opts or {})

  if opts.filename_first then
    opts.source_opts.transform = formatters.filename_first.transform(opts)
  end
  if opts.cwd then
    opts.source_opts.root_dir = opts.cwd
  end
  if opts.is_grep then
    opts.source_opts.transform = formatters.grep.transform
  end
  return opts
end

--- Resolve deck start specifier
---@param opts table
---@vararg table
---@return deck.StartConfigSpecifier
function M.resolve_specifier(opts, ...)
  local specifier = { root_dir = opts.source_opts.root_dir }
  if opts.filename_first ~= nil then
    specifier.disable_decorators = { "filename" }
  end
  if opts.pattern ~= nil and opts.pattern ~= "" then
    specifier.query = opts.pattern .. "  "
  end
  if opts.prompt ~= nil then
    specifier.start_prompt = opts.prompt
  end
  -- Disable snacks image previewer in favor of neo-img
  specifier.disable_previewers = { "snacks_image" }
  specifier = vim.tbl_deep_extend("force", specifier, ... or {})
  return specifier
end

--- Resolve source config
---@param opts table
---@vararg table
---@return deck.Source
function M.resolve_source(opts, ...)
  local source = { decorators = {} }
  if opts.buf_flags then
    table.insert(source.decorators, decorators.buf_flags)
  end
  source = vim.tbl_deep_extend("force", opts.source_opts, source, ...)
  return source
end

return M
