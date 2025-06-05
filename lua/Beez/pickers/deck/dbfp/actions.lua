local M = { dbfp = {} }

M.dbfp.connections_name = "dbfp.connections"
--- Deck action to show a list of connections
---@param opts? table
---@return deck.Action|string
function M.dbfp.connections(opts)
  opts = opts or {}
  return {
    name = M.dbfp.connections_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      require("Beez.pickers.deck.dbfp").connections(opts)
    end,
  }
end

M.dbfp.add_connection_name = "dbfp.add_connection"
--- Deck action to add a new connection
---@param opts? {execute?: boolean}
---@return deck.Action
function M.dbfp.add_connection(opts)
  opts = opts or {}
  return {
    name = M.dbfp.add_connection_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      vim.ui.input({ prompt = "New db string {name}={connection string}: " }, function(res)
        if res ~= nil then
          local name, con_str = res:match("^(.-)=(.*)$")
          if name == nil or con_str == nil then
            vim.notify("Invalid input format. Use {name}={connection string}.", vim.log.levels.WARN)
            return
          end
          dbfp.cons:add(name, con_str)
          if opts.execute ~= false then
            require("Beez.pickers.deck.dbfp").connections({ select_connection = name, prompt = false })
          end
        end
      end)
    end,
  }
end

M.dbfp.delete_connection_name = "dbfp.delete_connection"
--- Deck action for deleting a connection
---@param opts table?
---@return deck.Action
function M.dbfp.delete_connection(opts)
  opts = opts or {}
  return {
    name = M.dbfp.delete_connection_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")

      local choice =
        vim.fn.confirm("Are you sure you want to delete connection: " .. item.data.name, "&Yes\n&No")
      if choice == 1 then
        dbfp.delete_connection(item.data.name)
        ctx.execute()
      end
    end,
  }
end

M.dbfp.set_active_connection_name = "dbfp.set_active_connection"
--- Deck action to set the active connection
---@param opts table?
---@return deck.Action
function M.dbfp.set_active_connection(opts)
  opts = opts or {}
  return {
    name = M.dbfp.set_active_connection_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      dbfp.cons:set_active(item.data.name)
      ctx:hide()
    end,
  }
end

M.dbfp.rename_connection_string_name = "dbfp.rename_connection_string"
--- Renames a connection string
---@param opts table?
---@return deck.Action
function M.dbfp.rename_connection_string(opts)
  opts = opts or {}
  return {
    name = M.dbfp.rename_connection_string_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      local new_con_str = vim.fn.input("New connection string: ", item.data.con_str)
      if new_con_str ~= nil and new_con_str ~= "" and new_con_str ~= item.data.con_str then
        dbfp.cons:add(item.data.name, new_con_str, { replace = true })
        require("Beez.pickers.deck.dbfp").connections({
          select_connection = item.data.name,
          prompt = false,
        })
      end
    end,
  }
end

M.dbfp.rename_connection_name = "dbfp.rename_connection"
--- Deck action for renaming a connection name
---@param opts table?
---@return deck.Action
function M.dbfp.rename_connection(opts)
  opts = opts or {}
  return {
    name = M.dbfp.rename_connection_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      local new_name = vim.fn.input("New connection name: ", item.data.name)
      if new_name ~= nil and new_name ~= "" and new_name ~= item.data.name then
        dbfp.rename_connection(item.data.name, new_name)
        require("Beez.pickers.deck.dbfp").connections({
          select_connection = new_name,
          prompt = false,
        })
      end
    end,
  }
end

M.dbfp.queryfiles_name = "dbfp.queryfiles"
--- Deck action to show a list of query files
---@param opts? {get_opts?: fun(item: deck.Item): table}
---@return deck.Action|string
function M.dbfp.queryfiles(opts)
  opts = opts or {}
  return {
    name = M.dbfp.queryfiles_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local queryfiles_opts = opts.get_opts and opts.get_opts(item) or {}
      require("Beez.pickers.deck.dbfp").queryfiles(queryfiles_opts)
    end,
  }
end

M.dbfp.add_queryfile_name = "dbfp.add_queryfile"
--- Adds a new query file for a connection
---@param opts? {execute?: boolean, get_opts?: fun(item: deck.Item): {connection?: string, table?: string}}
---@return deck.Action
function M.dbfp.add_queryfile(opts)
  opts = opts or {}
  return {
    name = M.dbfp.add_queryfile_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local item = ctx.get_action_items()[1]
      local add_opts = opts.get_opts and opts.get_opts(item) or {}

      vim.ui.input({ prompt = "Query file name: " }, function(name)
        if name ~= nil and name ~= "" then
          local qf =
            dbfp.queryfiles:add(name, { connection = add_opts.connection, table = add_opts.table })
          if opts.execute ~= false then
            require("Beez.pickers.deck.dbfp").queryfiles({
              connection = add_opts.connection,
              select_queryfile = qf.basename,
              prompt = false,
            })
          end
        end
      end)
    end,
  }
end

M.dbfp.open_queryfile_name = "dbfp.open_queryfile"
--- Deck action to open a query file in a float
---@param opts? {get_opts?: fun(item: deck.Item): table}
---@return deck.Action
function M.dbfp.open_queryfile(opts)
  opts = opts or {}
  return {
    name = M.dbfp.open_queryfile_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      local open_opts = opts.get_opts and opts.get_opts(item) or {}

      dbfp.open_query_file(item.data.qf.path.filename, open_opts)
      ctx:hide()
    end,
  }
end

M.dbfp.execute_query_name = "dbfp.execute_query"
--- Deck action for executing a query string
---@param opts table?
---@return deck.Action
function M.dbfp.execute_query(opts)
  opts = opts or {}
  return {
    name = M.dbfp.execute_query_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")
      dbfp.execute_raw_query(item.data.qf.connection, item.data.q.query:gsub("\n", " "))
      dbfp.focus_dbout()
      ctx:hide()
    end,
  }
end

M.dbfp.rename_queryfile_name = "dbfp.rename_queryfile"
--- Deck action for renaming a query file
---@param opts table?
---@return deck.Action
function M.dbfp.rename_queryfile(opts)
  opts = opts or {}
  return {
    name = M.dbfp.rename_queryfile_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local u = require("Beez.u")
      local item = ctx.get_action_items()[1]
      local new_name = vim.fn.input("New query file name: ", u.paths.name(item.data.qf.basename))
      if new_name ~= nil and new_name ~= "" and new_name ~= item.data.qf.basename then
        item.data.qf:rename(new_name)
        ctx.execute()
      end
    end,
  }
end

M.dbfp.queryfile_set_connection_name = "dbfp.queryfile_set_connection"
--- Deck picker for setting the connection for a query file
---@param opts table?
---@return deck.Action
function M.dbfp.queryfile_set_connection(opts)
  opts = opts or {}
  return {
    name = M.dbfp.queryfile_set_connection_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      require("Beez.pickers.deck.dbfp").connections({
        default_action = function(con_ctx)
          local dbfp = require("Beez.dbfp")
          local con_item = con_ctx.get_action_items()[1]
          dbfp.queryfiles:set_queryfile_connection(item.data.qf.path.filename, con_item.data.name)
          require("Beez.pickers.deck.dbfp").queryfiles({
            prompt = false,
            select_queryfile = item.data.qf.basename,
          })
        end,
      })
    end,
  }
end

M.dbfp.queryfile_set_table_name = "dbfp.queryfile_set_table"
--- Deck action for setting the table for a query file
---@param opts table?
---@return deck.Action
function M.dbfp.queryfile_set_table(opts)
  opts = opts or {}
  return {
    name = M.dbfp.queryfile_set_table_name,
    resolve = function(ctx)
      local item = ctx:get_action_items()[1]
      return item.data.qf and item.data.qf.connection ~= nil
    end,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      vim.ui.input({ prompt = "Table: " }, function(res)
        if res == nil then
          return
        end

        item.data.qf:set_table(res)
        item.data.qf:save()
        require("Beez.pickers.deck.dbfp").queryfiles({
          prompt = false,
          select_queryfile = item.data.qf.basename,
        })
      end)
    end,
  }
end

M.dbfp.queryfile_delete_name = "dbfp.queryfile_delete"
--- Deck action for deleting a query file
---@param opts table?
---@return deck.Action
function M.dbfp.queryfile_delete(opts)
  opts = opts or {}
  return {
    name = M.dbfp.queryfile_delete_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local dbfp = require("Beez.dbfp")

      local choice = vim.fn.confirm(
        "Are you sure you want to delete query file: " .. item.data.qf.basename,
        "&Yes\n&No"
      )
      if choice == 1 then
        dbfp.queryfiles:delete_queryfile(item.data.qf.path.filename)
        ctx.execute()
      end
    end,
  }
end

M.dbfp.queries_name = "dbfp.queries"
--- Deck action to show a list of queries
---@param opts table?
---@return deck.Action
function M.dbfp.queries(opts)
  opts = opts or {}
  return {
    name = M.dbfp.queries_name,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      require("Beez.pickers.deck.dbfp").queries({
        queryfile = item.data.qf.path.filename,
      })
    end,
  }
end

return M
