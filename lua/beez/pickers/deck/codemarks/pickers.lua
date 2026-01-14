local M = {}

--- Deck for showing codemarks global marks
---@param opts table
function M.global_marks(opts)
  local source, specifier = require("beez.pickers.deck.codemarks.sources").global_marks(opts)
  require("deck").start(source, specifier)
end

--- Deck for shwoing codemarks marks
---@param opts table
function M.marks(opts)
  local source, specifier = require("beez.pickers.deck.codemarks.sources").marks(opts)
  require("deck").start(source, specifier)
end

--- Deck for showing codemark stacks
---@param opts table
function M.stacks(opts)
  local source, specifier = require("beez.pickers.deck.codemarks.sources").stacks(opts)
  require("deck").start(source, specifier)
end

--- Deck source for updating the global marks line
---@param opts table
function M.update_global_marks_line(opts)
  local actions = require("beez.pickers.deck.codemarks.actions")
  local line = vim.api.nvim_get_current_line()
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    actions = {
      require("deck").alias_action("default", "update_gmark_line"),
      actions.update_gmark_line(line),
    },
  })
  local source, specifier = require("beez.pickers.deck.codemarks.sources").global_marks(opts)
  require("deck").start(source, specifier)
end

return M
