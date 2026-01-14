local M = {
  view = nil,
}

local function setup_user_cmds()
  -- User command to run jj in a terminal at the git root
  vim.api.nvim_create_user_command("JJ", function(opts)
    local u = require("beez.u")
    local parts = vim.split(opts.args, "%s+")
    local subcommand = parts[1]

    local function run_raw_cmd(cmd, cb)
      u.cmds.run(cmd, function(err, stdout, stderr)
        if err ~= nil then
          return
        end

        vim.schedule(function()
          M.log()
          if cb ~= nil then
            cb()
          end
        end)
      end, { verbose = true })
    end

    if subcommand == "log" or subcommand == "" then
      if #parts == 1 then
        M.log()
        return
      end
    elseif subcommand == "split" then
      if #parts == 1 then
        M.split()
        return
      end
    elseif subcommand == "squash" then
      if #parts == 1 then
        M.squash()
      else
        local cmd = u.tables.extend({ "jj" }, u.tables.slice(parts, 1))
        run_raw_cmd(cmd)
      end
      return
    elseif subcommand == "describe" then
      if #parts == 1 then
        M.describe()
        return
      end
    elseif subcommand == "tug" then
      local cmd = { "jj", "tug" }
      run_raw_cmd(cmd)
      return
    elseif subcommand == "undo" then
      local cmd = { "jj", "undo" }
      run_raw_cmd(cmd)
      return
    elseif subcommand == "redo" then
      local cmd = { "jj", "redo" }
      run_raw_cmd(cmd)
      return
    elseif subcommand == "new" then
      if #parts == 1 then
        M.new()
        return
      end
    elseif subcommand == "diff" then
      if #parts == 1 then
        M.diff()
      else
        local cmd = u.tables.extend({ "jj" }, u.tables.slice(parts, 1))
        run_raw_cmd(cmd)
      end
      return
    elseif subcommand == "git" then
      local git_command = parts[2]
      if #parts == 2 then
        local cmd = { "jj", "git", git_command }
        run_raw_cmd(cmd)
        return
      end
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
  end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
      return { "log", "split", "describe", "tug", "undo", "new", "diff" }
    end,
  })
end

--- Setup jj
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  M.view = require("beez.jj.ui.view").new()

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

  M.log({
    cb = function()
      M.view.logtree:split()
    end,
  })
end

--- JJ describe with log view
function M.describe(opts)
  if M.view == nil then
    return
  end

  M.log({
    cb = function()
      M.view.logtree:describe(opts)
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

--- JJ new with log view
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

--- JJ squash through log viewer
function M.squash()
  if M.view == nil then
    return
  end

  M.view.logtree:squash()
end

return M
