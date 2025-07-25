local actions = require("Beez.pickers.deck.dbfp.actions")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for dbfp connections
---@param opts? {default_action?: string|fun(ctx: deck.Context), select_connection?: string}
---@return deck.Source, deck.StartConfigSpecifier
function M.connections(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local set_cursor = nil
  local custom_action_name = "dbfp.connections.custom"
  local default_action = actions.dbfp.queryfiles_name
  if type(opts.default_action) == "string" then
    default_action = opts.default_action
  elseif type(opts.default_action) == "function" then
    default_action = custom_action_name
  end

  local source = utils.resolve_source(opts, {
    name = "dbfp.connections",
    ---@param ctx deck.ExecuteContext
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local cons = dbfp.cons.cons

      if next(cons) == nil then
        actions.add_connection({ execute = false }).execute(ctx)
      end

      if next(cons) == nil then
        vim.notify("No connections found...", vim.log.levels.WARN)
      end

      local i = 1
      for name, con_str in pairs(cons) do
        local item = {
          display_text = {
            name,
            " ",
            { con_str, "Comment" },
          },
          data = {
            filename = dbfp.cons.path.filename,
            name = name,
            con_str = con_str,
          },
        }
        ctx.item(item)
        if opts.select_connection and opts.select_connection == name then
          set_cursor = i
        end
        i = i + 1
      end
      ctx.done()
    end,
    events = {
      BufWinEnter = function(ctx, _)
        if set_cursor then
          ctx.set_cursor(set_cursor)
        end
      end,
    },
    actions = {
      require("deck").alias_action("default", default_action),
      require("deck").alias_action("open_keep", actions.dbfp.add_connection_name),
      require("deck").alias_action("delete", actions.dbfp.delete_connection_name),
      require("deck").alias_action("replace_char", actions.dbfp.rename_connection_string_name),
      require("deck").alias_action("edit_line_end", actions.dbfp.rename_connection_string_name),
      require("deck").alias_action("edit_line_start", actions.dbfp.rename_connection_name),
      require("deck").alias_action("insert_above", actions.dbfp.add_queryfile_name),
      actions.dbfp.queryfiles({
        get_opts = function(item)
          return { connection = item.data.name, prompt = false }
        end,
      }),
      actions.dbfp.delete_connection(),
      actions.dbfp.add_connection(),
      actions.dbfp.set_active_connection(),
      actions.dbfp.rename_connection_string(),
      actions.dbfp.rename_connection(),
      actions.dbfp.add_queryfile({
        get_opts = function(item)
          return { connection = item.data.name }
        end,
      }),
    },
  })

  if type(opts.default_action) == "function" then
    table.insert(source.actions, {
      name = custom_action_name,
      execute = opts.default_action,
    })
  end

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source fo listing query files for a connection
---@param opts? {connection?: string, select_queryfile?: string}
---@return deck.Source, deck.StartConfigSpecifier
function M.queryfiles(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local set_cursor = nil

  local source = utils.resolve_source(opts, {
    name = "dbfp.queryfiles",
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local queryfiles = dbfp.queryfiles:list({ connection = opts.connection })
      if next(queryfiles) == nil then
        actions.dbfp
          .add_queryfile({
            get_opts = function(item)
              return { connection = opts.connection }
            end,
            execute = false,
          })
          .execute(ctx)
      end

      queryfiles = dbfp.queryfiles:list({ connection = opts.connection })
      if next(queryfiles) == nil then
        if opts.connection then
          vim.notify("No query files found for connection: " .. opts.connection, vim.log.levels.WARN)
        else
          vim.notify("No query files found...", vim.log.levels.WARN)
        end
      end

      for i, qf in ipairs(queryfiles) do
        local display_text = { qf.basename }
        if qf.connection then
          table.insert(display_text, " ")
          table.insert(display_text, { qf.connection, "Comment" })
        end
        if qf.table then
          table.insert(display_text, " ")
          table.insert(display_text, { qf.table, "Comment" })
        end
        local item = {
          display_text = display_text,
          data = {
            qf = qf,
            filename = qf.path.filename,
          },
        }
        ctx.item(item)
        if opts.select_queryfile and opts.select_queryfile == qf.basename then
          set_cursor = i
        end
      end
      ctx.done()
    end,
    events = {
      BufWinEnter = function(ctx, _)
        if set_cursor then
          ctx.set_cursor(set_cursor)
        end
      end,
    },
    actions = {
      require("deck").alias_action("default", actions.dbfp.open_queryfile_name),
      require("deck").alias_action("prev_default", actions.dbfp.connections_name),
      require("deck").alias_action("replace_char", actions.dbfp.rename_queryfile_name),
      require("deck").alias_action("edit_line_start", actions.dbfp.rename_queryfile_name),
      require("deck").alias_action("edit_line_end", actions.dbfp.queryfile_set_connection_name),
      require("deck").alias_action("open_keep", actions.dbfp.add_queryfile_name),
      require("deck").alias_action("insert_above", actions.dbfp.queryfile_set_table_name),
      require("deck").alias_action("delete", actions.dbfp.queryfile_delete_name),
      require("deck").alias_action("alt_default", actions.dbfp.queries_name),
      actions.dbfp.open_queryfile(),
      actions.dbfp.connections({ prompt = false }),
      actions.dbfp.rename_queryfile(),
      actions.dbfp.add_queryfile(),
      actions.dbfp.queryfile_set_connection(),
      actions.dbfp.queryfile_set_table(),
      actions.dbfp.queryfile_delete(),
      actions.dbfp.queries(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for dbfp queries
---@param opts? {queryfile?: string, connection?: string}
---@return deck.Source, deck.StartConfigSpecifier
function M.queries(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "dbfp.queries",
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local queryfiles = {}
      if opts.queryfile then
        queryfiles = { dbfp.queryfiles:get(opts.queryfile) }
      elseif opts.connection then
        queryfiles = dbfp.queryfiles:list({ connection = opts.connection })
      else
        queryfiles = dbfp.queryfiles:list()
      end

      if next(queryfiles) == nil then
        ctx.done()
        return vim.notify("No query files found...", vim.log.levels.WARN)
      end

      for _, qf in ipairs(queryfiles) do
        for _, q in ipairs(qf.queries) do
          local item = {
            display_text = {
              { q.comment, "String" },
              { " ", "String" },
              { qf.basename, "Comment" },
            },
            data = {
              qf = qf,
              q = q,
              filename = qf.path.filename,
              name = qf.basename,
            },
          }

          ctx.item(item)
        end
      end
      ctx.done()
    end,
    previewers = {
      {
        name = "dbfp.queries.preview",
        resolve = function(ctx)
          return true
        end,
        preview = function(_, item, env)
          local x = require("deck.x")
          local lines = item.data.q.paragraph
          x.open_preview_buffer(env.win, { contents = lines, filename = item.data.name })
        end,
      },
    },
    actions = {
      require("deck").alias_action("default", actions.dbfp.execute_query_name),
      require("deck").alias_action("open_keep", actions.dbfp.open_queryfile_name),
      require("deck").alias_action("prev_default", actions.dbfp.queryfiles_name),
      actions.dbfp.execute_query(),
      actions.dbfp.open_queryfile({
        get_opts = function(item)
          local search = nil
          if item.data.q.comment then
            search = item.data.q.paragraph[2]
          else
            search = item.data.q.paragraph[1]
          end
          return { search = search }
        end,
      }),
      actions.dbfp.queryfiles({
        get_opts = function(item)
          return { select_queryfile = item.data.qf.basename, prompt = false }
        end,
      }),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
