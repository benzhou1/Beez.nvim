local sources = require("beez.pickers.deck.sources")
local u = require("beez.u")
local utils = require("beez.pickers.deck.utils")
local M = { git = {} }

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
  opts = utils.resolve_opts(opts, { is_grep = true })
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

--- Deck picker for git log
---@param opts table?
function M.git.log(opts)
  opts = opts or {}
  local source = require("deck.builtin.source.git.log")(opts)

  source.actions[1] = require("deck").alias_action("default", "git.diffview.commit")
  table.insert(source.actions, {
    name = "git.diffview.commit",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local hash = item.data.hash
      vim.cmd("DiffviewOpen " .. hash .. "~1.." .. hash)
    end,
  })

  require("deck").start(source)
end

--- Deck picker for jump list
---@param opts table
function M.jump_list(opts)
  opts = opts or {}
  local source, specifier = sources.jump_list(opts)
  local ctx = require("deck").start(source, specifier)
  local i = 1
  for j in ctx.iter_items() do
    if j.data.current then
      ctx.set_cursor(i)
    end
    i = i + 1
  end
end

--- Deck picker for files
---@param opts? table
function M.files(opts)
  opts = opts or {}
  require("deck").start(sources.files(opts))
end

--- Deck picker for smart lookup (files, recent files, buffers, dirs, recent dirs, global pinned files, global pinned dirs)
---@param opts? table
function M.smart(opts)
  opts = opts or {}
  require("deck").start(sources.smart(opts))
end

--- Deck picker for finding directories
---@param opts? table
function M.dirs(opts)
  opts = opts or {}
  require("deck").start(sources.dirs(opts))
end

return M
