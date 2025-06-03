local actions = require("Beez.pickers.deck.dbfp.actions")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for dbfp connections
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.connections(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "dbfp.connections",
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local cons = dbfp.cons.cons

      if next(cons) == nil then
        actions.add_connection({ execute = false }).execute(ctx)
      end

      if next(cons) == nil then
        vim.notify("No connections found...", vim.log.levels.WARN)
      end

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
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", opts.default_action or "dbfp.choose_connection"),
      require("deck").alias_action("delete", "delete_connection"),
      require("deck").alias_action("open_keep", "dbfp.add_connection"),
      require("deck").alias_action("delete", "rename_connection"),
      actions.dbfp.choose_connection(),
      -- actions.delete_connection(),
      actions.dbfp.add_connection(),
      actions.dbfp.set_active_connection(),
      -- actions.rename_connection(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source fo listing query files for a connection
---@param opts? {connection?: string}
---@return deck.Source, deck.StartConfigSpecifier
function M.queryfiles(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "dbfp.queryfiles",
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local queryfiles = dbfp.queryfiles:list({ connection = opts.connection })
      if next(queryfiles) == nil then
        actions.dbfp.add_queryfile(opts.connection, { execute = false }).execute(ctx)
      end

      queryfiles = dbfp.queryfiles:list({ connection = opts.connection })
      if next(queryfiles) == nil then
        if opts.connection then
          vim.notify("No query files found for connection: " .. opts.connection, vim.log.levels.WARN)
        else
          vim.notify("No query files found...", vim.log.levels.WARN)
        end
      end

      for _, qf in ipairs(queryfiles) do
        local item = {
          display_text = {
            qf.basename,
            " ",
            { qf.dirname, "Comment" },
          },
          data = {
            qf = qf,
            filename = qf.path.filename,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", "dbfp.open_queryfile"),
      actions.dbfp.open_queryfile(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for dbfp queries
---@param opts table?
---@return deck.Source, deck.StartConfigSpecifier
function M.queries(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "dbfp.queries",
    execute = function(ctx)
      local dbfp = require("Beez.dbfp")
      local queryfiles = dbfp.queryfiles:list()
      if next(queryfiles) == nil then
        ctx.done()
        return vim.notify("No query files found...", vim.log.levels.WARN)
      end

      for _, qf in ipairs(queryfiles) do
        for _, q in ipairs(qf.queries) do
          local item = {
            display_text = {
              q.comment,
              " ",
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
      require("deck").alias_action("default", "dbfp.execute_query"),
      require("deck").alias_action("open_keep", "dbfp.open_queryfile"),
      actions.dbfp.execute_query(),
      actions.dbfp.open_queryfile(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
