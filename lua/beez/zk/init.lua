---@class Beez.zk.Config
---@field open_in_neovide boolean

local M = {
  ---@type Beez.zk.Config
  config = {
    open_in_neovide = true,
  },
}

--- Sets up user commands for the the plugin
local function setup_user_cmds()
  vim.api.nvim_create_user_command("ZK", function(opts)
    local parts = vim.split(opts.args, "%s+")
    local subcommand = parts[1]
    local u = require("beez.u")

    if subcommand == "new" then
      local cmd = { "zk", "new", "--no-input", "-p" }
      if #parts > 1 then
        u.tables.extend(cmd, u.tables.slice(parts, 2))
      end
      M.new(cmd)
    elseif subcommand == "journal" then
      local cmd = { "zk", "journal", "-p" }
      if #parts > 1 then
        u.tables.extend(cmd, u.tables.slice(parts, 2))
      end
      M.new(cmd)
    elseif subcommand == "jira" then
      local cmd = { "zk", "jira" }
      local jira = table.concat(u.tables.slice(parts, 2), " ")
      local ticket, content = jira:match("(%S+)%s*-%s(.*)")
      table.insert(cmd, ticket)
      table.insert(cmd, "--extra")
      table.insert(cmd, "body=" .. content)
      table.insert(cmd, "-p")
      M.new(cmd)
    elseif subcommand == "list" then
      if #parts == 1 then
        require("beez.pickers.deck.zk").notes()
      end
    end
  end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
      return { "new", "journal", "jira" }
    end,
  })
end

--- Waits until file exists on the filesystem before calling callback
---@param path string
---@param cb fun()
local function until_file_exists(path, cb)
  local u = require("beez.u")
  u.async.periodic({
    delay = 100,
    timeout = 5000,
    interval = 100,
    cb = function(timer)
      if vim.fn.filereadable(path) == 1 then
        timer:stop()
        cb()
      end
    end,
  })
end

--- Setups beez zk plugin
---@param opts? Beez.zk.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  setup_user_cmds()
end

--- Edits a note by path
---@param path string
function M.edit(path)
  local u = require("beez.u")
  local cmds = require("beez.cmds")

  if M.config.open_in_neovide == false then
    vim.cmd.edit(path)
    return
  end

  cmds.neovide.open_zk(path)
  cmds.aerospace.until_focused({
    app = "neovide",
    title = "zk",
    cb = function()
      local cmd = { "nvim", "--server", "/tmp/nvimsocket-zk", "--remote-send", ":e " .. path .. "<cr>" }
      u.cmds.run(cmd)
    end,
  })
end

--- Runs a zk new command and opens the path to the note in neovide window
---@param cmd string[]
function M.new(cmd)
  local u = require("beez.u")
  u.cmds.run(cmd, function(err, path)
    if err ~= nil then
      return
    end

    if path == nil then
      return
    end
    -- Get rid of ending newline
    path = path:gsub("\n", "")

    until_file_exists(path, function()
      M.edit(path)
    end)
  end)
end

return M
