local sources = require("Beez.pickers.deck.sources")
local u = require("Beez.u")
local M = {}

--- Grep deck with input
---@param opts table
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

--- Grep selected word or word under cursor
---@param opts table
function M.grep_word(opts)
  opts = M.resolve_opts(opts, { is_grep = true })
  local visual_text = u.nvim.get_visual_selection()
  if visual_text ~= "" then
    opts.pattern = visual_text
  else
    opts.pattern = vim.fn.expand("<cword>")
  end

  local source, specifier = sources.grep(opts)
  require("deck").start(source, specifier)
end

--- Search for workspace tags deck
---@param opts table
function M.tags_workspace(opts)
  opts = opts or {}
  local cancelreturn = "<cancelreturn>"
  opts.pattern = vim.fn.input({
    prompt = "symbol: ",
    cancelreturn = cancelreturn,
  })
  if opts.pattern == cancelreturn then
    return
  end

  local source, specifier = sources.tags_workspace(opts)
  require("deck").start(source, specifier)
end

--- Deck for grepping notes
---@param opts? table
function M.notes_grep(opts)
  opts = opts or {}
  local cancelreturn = "<cancelreturn>"
  opts.pattern = vim.fn.input({
    prompt = "grep: ",
    cancelreturn = cancelreturn,
  })
  if opts.pattern == cancelreturn then
    return
  end
  local source, specifier = sources.notes_grep(opts)
  require("deck").start(source, specifier)
end

--- Deck source for comparing path with branch
---@param path string
---@param opts table
function M.git_compare_path_with_branch(path, opts)
  local source = require("deck.builtin.source.git.branch")(opts)
  source.actions[1] = require("deck").alias_action("default", "compare_with_branch")
  table.insert(source.actions, {
    name = "compare_with_branch",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local branch = item.data.name
      ctx:hide()
      require("diffview").open({ branch, "--", path })
    end,
  })

  require("deck").start(source)
end

--- Deck source for comparing project with branch
---@param opts table
function M.git_compare_project_with_branch(opts)
  local source = require("deck.builtin.source.git.branch")(opts)
  source.actions[1] = require("deck").alias_action("default", "compare_with_branch")
  table.insert(source.actions, {
    name = "compare_with_branch",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local branch = item.data.name
      ctx:hide()
      require("diffview").open({ branch })
    end,
  })

  require("deck").start(source)
end

return M
