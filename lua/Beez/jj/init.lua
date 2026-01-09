local M = {
  view = nil,
}

local function setup_user_cmds()
  -- User command to run jj in a terminal at the git root
  vim.api.nvim_create_user_command(
    "JJ", -- Command name (:MyCommand)
    function(opts)
      local parts = vim.split(opts.args, "%s+")
      local subcommand = parts[1]
      if subcommand == "log" or subcommand == "" then
        M.log()
        return
      elseif subcommand == "split" then
        M.split()
        return
      elseif subcommand == "describe" then
        M.describe()
        return
      elseif subcommand == "tug" then
        M.tug()
        return
      elseif subcommand == "undo" then
        M.undo()
        return
      elseif subcommand == "new" then
        M.new()
        return
      end

      local sterm = require("snacks.terminal")
      local git_root = vim.fs.find(".git", { upward = true })[1]
      local root = vim.fs.dirname(git_root)
      local terminal, created = sterm.get(nil, { cwd = root, auto_insert = false, keep_mode = true })
      if not created and terminal ~= nil then
        terminal:show()
        terminal:focus()
      end
      if terminal ~= nil then
        local chan = vim.bo[terminal.buf].channel
        vim.fn.chansend(chan, "jj " .. opts.args .. "\n")
      end
    end,
    {
      nargs = "*",
      complete = function(arg_lead, cmd_line, cursor_pos)
        return { "log", "split", "describe", "tug", "undo", "new" }
      end,
    }
  )
end

--- Setup jj
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  M.view = require("Beez.jj.ui.view").new()

  setup_user_cmds()
end

--- Starts/focus jj log view
function M.log(opts)
  if M.view == nil then
    return
  end

  opts = opts or {}
  M.view:render({ cb = opts.cb })
end

--- JJ split with log view
function M.split()
  if M.view == nil then
    return
  end

  M.log()
  M.view.logtree:split()
end

--- JJ describe with log view
function M.describe()
  if M.view == nil then
    return
  end

  M.log({
    cb = function()
      M.view.logtree:describe()
    end,
  })
end

-- JJ tug with log view
function M.tug()
  if M.view == nil then
    return
  end

  M.log()
  M.view.logtree:tug()
end

--- JJ undo with log view
function M.undo()
  if M.view == nil then
    return
  end

  M.log()
  M.view.logtree:undo()
end

function M.new()
  if M.view == nil then
    return
  end

  M.log()
  M.view.logtree:new_commit()
end

--- JJ diff with CodeDiff directly and show log view
function M.diff()
  if M.view == nil then
    return
  end

  M.log()
  vim.cmd("CodeDiff")
end

return M
