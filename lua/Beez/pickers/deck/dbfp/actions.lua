local M = { dbfp = {} }

--- Deck action to show a list of query files for connection
---@return deck.Action
function M.dbfp.choose_connection()
  return {
    name = "dbfp.choose_connection",
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      require("Beez.pickers.deck.dbfp").queryfiles({ connection = item.data.name })
    end,
  }
end

--- Deck action to add a new connection
---@param opts? {execute?: boolean}
---@return deck.Action
function M.dbfp.add_connection(opts)
  opts = opts or {}
  return {
    name = "dbfp.add_connection",
    ---@param ctx deck.Context
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      vim.ui.input({ prompt = "{name}={connection string}: " }, function(res)
        if res ~= nil then
          local name, con_str = res:match("^(.-)=(.*)$")
          if name == nil or con_str == nil then
            vim.notify("Invalid input format. Use {name}={connection string}.", vim.log.levels.WARN)
            return
          end
          dbfp.cons:add(name, con_str)
        end
        if opts.execute ~= false then
          ctx.execute()
        end
      end)
    end,
  }
end

--- Adds a new query file for a connection
---@param connection string
---@param opts? {execute?: boolean, table?: string}
---@return deck.Action
function M.dbfp.add_queryfile(connection, opts)
  opts = opts or {}
  return {
    name = "dbfp.add_queryfile",
    ---@param ctx deck.Context
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      vim.ui.input({ prompt = "Query file name: " }, function(name)
        if name ~= nil and name ~= "" then
          dbfp.queryfiles:add(name, connection, { table = opts.table })
          if opts.execute ~= false then
            ctx.execute()
          end
        end
      end)
    end,
  }
end

--- Deck action to open a query file in a float
---@param opts? table
---@return deck.Action
function M.dbfp.open_queryfile(opts)
  opts = opts or {}
  return {
    name = "dbfp.open_queryfile",
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")

      dbfp.open_query_file(item.data.qf.path.filename)
      ctx:hide()
    end,
  }
end

--- Deck action to set the active connection
---@param opts table
---@return deck.Action
function M.dbfp.set_active_connection(opts)
  opts = opts or {}
  return {
    name = "dbfp.set_active_connection",
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      dbfp.cons:set_active(item.data.name)
      ctx:hide()
    end,
  }
end

--- Deck action for executing a query string
---@param opts table?
---@return deck.Action
function M.dbfp.execute_query(opts)
  opts = opts or {}
  return {
    name = "dbfp.execute_query",
    ---@param ctx deck.Context
    execute = function(ctx)
      local u = require("Beez.u")
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      dbfp.execute_raw_query(item.data.qf.connection, item.data.q.query:gsub("\n", " "))
      u.async.delayed({
        delay = 500,
        cb = function()
          ctx:hide()
          dbfp.focus_dbout()
        end,
      })
    end,
  }
end

return M
