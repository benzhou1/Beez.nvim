local sources = require("Beez.pickers.deck.flotes.sources")
local M = {}

--- Deck picker for finding flotes files
---@param opts? table
function M.find(opts)
  opts = opts or {}
  local source, specifier = sources.files(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for greping flotes files
---@param opts? table
function M.grep(opts)
  opts = opts or {}
  local cancelreturn = "<cancelreturn>"
  opts.pattern = vim.fn.input({
    prompt = "grep: ",
    cancelreturn = cancelreturn,
  })
  if opts.pattern == cancelreturn then
    return
  end

  local source, specifier = sources.grep(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for creating new flotes based off of templates
---@param opts? table
function M.find_templates(opts)
  opts = opts or {}
  local source, specifier = sources.templates(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for findling backlinks to the current flote
---@param opts? table
function M.backlinks(opts)
  opts = opts or {}
  local source, specifier = sources.backlinks(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for findling tasks
---@param opts? table
function M.tasks(opts)
  opts = opts or {}
  local source, specifier = sources.tasks(opts)
  specifier.start_prompt = false
  require("deck").start(source, specifier)
end

--- Deck picker for findling tasks
---@param opts? table
function M.find_tasks(opts)
  opts = opts or {}
  local source, specifier = sources.tasks(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for inserting a tag reference to task
---@param opts? table
function M.insert_task_tag(opts)
  opts = opts or {}
  opts.def_action_open = false
  opts.actions = {
    require("deck").alias_action("toggle_select", "flotes.task.insert_task_tag"),
  }
  local source, specifier = sources.tasks(opts)
  require("deck").start(source, specifier)
end

return M
