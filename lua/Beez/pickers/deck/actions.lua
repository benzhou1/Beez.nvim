local u = require("Beez.u")
local M = {}

--- Toggle cwd
M.toggle_cwd = {
  name = "toggle_cwd",
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
        require("oil").open_float(u.paths.dirname(item.data.filename))
        ctx:hide()
      end,
    }
  end
  return {
    name = opts.keep_open and "open_oil_keep" or "open_oil",
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      require("oil").open_float(item.data.filename)
      if not opts.keep_open then
        ctx:hide()
      end
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

--- Open note in flotes window
M.open_note = {
  name = "open_note",
  execute = function(ctx)
    local f = require("Beez.flotes")
    local item = ctx.get_action_items()[1]
    ctx:hide()
    vim.schedule(function()
      f.show({ note_path = item.data.filename })
      if item.data.lnum then
        vim.fn.cursor(item.data.lnum, item.data.col)
      end
    end)
  end,
}

--- Create a new note with title
M.new_note = {
  name = "new_note",
  execute = function(ctx)
    local f = require("Beez.flotes")
    local title = ctx.get_query()
    ctx:hide()
    f.new_note(title, {})
  end,
}

--- Delete note
M.delete_note = {
  name = "delete_note",
  execute = function(ctx)
    local Path = require("plenary.path")
    for _, item in ipairs(ctx.get_action_items()) do
      local path = Path:new(item.data.filename)
      local choice = vim.fn.confirm("Are you sure you want to delete this note?", "&Yes\n&No")
      if choice == 1 then
        path:rm()
        vim.notify("Deleted note: " .. path.filename, "info")
        ctx:execute()
      end
    end
  end,
}

--- Create note from template
M.new_note_from_template = {
  name = "new_note_from_template",
  execute = function(ctx)
    local item = ctx.get_action_items()[1]
    ctx:hide()
    vim.schedule(function()
      require("flotes.notes").create_template({ template = item.data.name })
    end)
  end,
}

return M
