local M = {}

--- Runs jj st
---@param cb fun(err?: string, stdout?: string)
---@param opts? table
function M.st(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "st" }
  u.cmds.run(cmd, cb, opts)
end

--- Runs jj diff
---@param cb? function(err?: string, stdout?: string)
---@param opts? table
---@return vim.SystemObj?
function M.diff(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "diff" }
  if opts.r ~= nil then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.r)
  end
  if opts.name_only == true then
    table.insert(cmd, "--name-only")
  end
  if opts.summary == true then
    table.insert(cmd, "--summary")
  end
  return u.cmds.run(cmd, cb, opts)
end

--- Runs jj describe
---@param commit_id? string
---@param cb function(err?: string, stdout?: string)
---@param opts? table
function M.describe(commit_id, cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "describe", "-r", commit_id or "@" }
  if opts.m ~= nil then
    table.insert(cmd, "-m")
    table.insert(cmd, opts.m)
  end
  u.cmds.run(cmd, cb, opts)
end

--- Runs jj edit
---@param commit_id string
---@param cb fun(err?: string, stdout?: string)
---@param opts? table
function M.edit(commit_id, cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "edit", commit_id }
  u.cmds.run(cmd, cb, opts)
end

--- Run jj squash
---@param cb function(err?: string, stdout?: string)
---@param opts? table
function M.squash(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "squash" }
  if opts.to then
    table.insert(cmd, "--to")
    table.insert(cmd, opts.to)
  end
  if opts.u == true then
    table.insert(cmd, "-u")
  end
  if opts.m ~= nil then
    table.insert(cmd, "-m")
    table.insert(cmd, opts.m)
  end
  u.cmds.run(cmd, cb, opts)
end

--- Run jj undo
---@param cb fun(err?: string, stdout?: string)
---@param opts? table
function M.undo(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "undo" }
  u.cmds.run(cmd, cb, opts)
end

--- Runs jj new
---@param cb fun(err?: string, stdout?: string)
---@param opts? table
function M.new(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "new" }
  if opts.before then
    table.insert(cmd, "-B")
    table.insert(cmd, opts.before)
  end
  if opts.after then
    table.insert(cmd, "-A")
    table.insert(cmd, opts.after)
  end
  u.cmds.run(cmd, cb, opts)
end

--- Runs jj log
---@param cb? fun(err?: string, stdout?: string)
---@param opts? table
---@return vim.SystemObj?
function M.log(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local config = opts.config
    or "template-aliases.\"format_short_commit_id(id)\"=\"id.shortest(8) ++ '[' ++ id.shortest() ++ ']'\""

  local template = opts.T or "builtin_log_compact_full_description"
  local cmd = {
    "jj",
    "log",
    "--color=never",
    "--no-pager",
  }
  if config ~= nil and config ~= false then
    table.insert(cmd, "--config")
    table.insert(cmd, config)
  end
  if opts.no_graph ~= nil then
    table.insert(cmd, "--no-graph")
  end
  if template ~= nil and template ~= false then
    table.insert(cmd, "-T")
    table.insert(cmd, template)
  end
  if opts.r ~= nil then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.r)
  end
  return u.cmds.run(cmd, cb, opts)
end

--- Runs jj file show
---@param cb fun(err?: string, stdout?: string)
---@param opts? {r?: string, path?: string, ignore_err?: string[]}
function M.file_show(cb, opts)
  local u = require("Beez.u")
  opts = opts or {}

  local cmd = { "jj", "file", "show" }
  if opts.path ~= nil then
    table.insert(cmd, '"' .. opts.path .. '"')
  end
  if opts.r ~= nil then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.r)
  end
  u.cmds.run(cmd, cb, opts)
end

return M
