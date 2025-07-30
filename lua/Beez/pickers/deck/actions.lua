local u = require("Beez.u")
local M = {}

--- Toggle cwd
M.toggle_cwd = {
  name = "toggle_cwd",
  resolve = function(ctx)
    return true
  end,
  execute = function(ctx)
    local config = ctx.get_config()
    if config.toggles.cwd == nil then
      config.toggles.cwd = true
    else
      config.toggles.cwd = not config.toggles.cwd
    end
    ctx.execute()
  end,
}

--- Remove dir from recent dirs
M.remove_recent = {
  name = "remove_recent",
  resolve = function(ctx)
    local symbols = require("deck.symbols")
    for _, item in ipairs(ctx.get_action_items()) do
      if item[symbols.source].name == "recent_files" then
        return true
      end
    end
    return false
  end,
  execute = function(ctx)
    local symbols = require("deck.symbols")
    for _, item in ipairs(ctx.get_action_items()) do
      if item[symbols.source].name == "recent_files" then
        require("deck.builtin.source.recent_files"):remove(vim.fs.normalize(item.data.filename))
      end
    end
    ctx.execute()
  end,
}

-- Open dir in oil float
M.open_oil = function(opts)
  opts = opts or {}
  if opts.keep_open == nil then
    opts.keep_open = false
  end
  if opts.parent == true then
    return {
      name = "open_oil_parent",
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        ctx:hide()
        vim.schedule(function()
          require("oil").open_float(u.paths.dirname(item.data.filename))
        end)
      end,
    }
  end
  return {
    name = opts.keep_open and "open_oil_keep" or "open_oil",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      if not opts.keep_open then
        ctx:hide()
      end
      vim.schedule(function()
        require("oil").open_float(item.data.filename)
      end)
    end,
  }
end

-- Open dir in external program
M.open_external = function(opts)
  opts = opts or {}
  return {
    name = opts.parent and "open_parent_external" or "open_external",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local path = item.data.filename
      if opts.parent then
        path = u.paths.dirname(item.data.filename)
      end
      vim.fn.system('open "' .. path .. '"')
      ctx:hide()
      if opts.quit then
        vim.schedule(function()
          vim.cmd("q")
        end)
      end
    end,
  }
end

-- Find files under a directory
M.find_files = function(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("find_files", opts.name),
    {
      name = opts.name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local path = item.data.filename
        if not opts.dir then
          path = u.paths.dirname(item.data.filename)
        end
        ctx:hide()
        require("Beez.pickers").pick("find_files", { cwd = path, type = "deck" })
      end,
    },
  }
end

-- Grep files under a directory
M.grep_files = function(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("grep_files", opts.name),
    {
      name = opts.name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local path = item.data.filename
        if not opts.dir then
          path = u.paths.dirname(item.data.filename)
        end
        ctx:hide()
        require("Beez.pickers").pick("grep", { cwd = path, type = "deck" })
      end,
    },
  }
end

-- Open item in zed
M.open_zed = function(opts)
  opts = opts or {}
  return {
    name = "open_zed",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local path = item.data.filename
      vim.fn.system('zed "' .. path .. '"')
      ctx:hide()
      if opts.quit then
        vim.schedule(function()
          vim.cmd("q")
        end)
      end
    end,
  }
end

return M
