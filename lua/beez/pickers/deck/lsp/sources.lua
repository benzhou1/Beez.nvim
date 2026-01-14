local actions = require("beez.pickers.deck.lsp.actions")
local u = require("beez.u")
local utils = require("beez.pickers.deck.utils")
local M = {}

--- Utility function for getting all definitions under cursor
---@param cb fun(items: deck.Item[])
function M.get_definitions(cb)
  vim.lsp.buf.definition({
    on_list = function(tt)
      local items = {}
      local unique_items = {}
      for _, t in ipairs(tt.items) do
        local target_uri = t.user_data.targetUri or t.user_data.uri
        if unique_items[t.text] == nil then
          local item = {
            display_text = {
              { t.text, "String" },
              { " " },
              { t.filename, "Comment" },
              { ":", "Comment" },
              { tostring(t.lnum), "Comment" },
            },
            data = {
              target_bufnr = vim.uri_to_bufnr(target_uri),
              filename = t.filename,
              lnum = t.lnum,
              end_lnum = t.end_lnum,
              col = t.col,
              end_col = t.end_col,
            },
          }
          table.insert(items, item)
          unique_items[t.text] = true
        end
      end
      cb(items)
    end,
  })
end

--- Utility function for getting all references under cursor
---@param cb fun(items: deck.Item[])
function M.get_references(cb)
  local filename = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)

  vim.lsp.buf.references({
    includeDeclaration = false,
  }, {
    on_list = function(tt)
      local unique = {}
      local items = {}
      for _, t in ipairs(tt.items) do
        local key = t.filename .. "_" .. t.lnum
        if (t.filename ~= filename or t.lnum ~= pos[1]) and unique[key] == nil then
          local target_uri = t.user_data.targetUri or t.user_data.uri
          local item = {
            display_text = {
              { t.text, "String" },
              { " " },
              { t.filename, "Comment" },
              { ":", "Comment" },
              { tostring(t.lnum), "Comment" },
            },
            data = {
              target_bufnr = vim.uri_to_bufnr(target_uri),
              filename = t.filename,
              lnum = t.lnum,
              end_lnum = t.end_lnum,
              col = t.col,
              end_col = t.end_col,
            },
          }
          table.insert(items, item)
          unique[key] = true
        end
      end
      cb(items)
    end,
  })
end

--- Deck source for go to definitions
---@param items? deck.Item[]
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.go_to_definitions(items, opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "lsp.go_to_definitions",
    execute = function(ctx)
      if items ~= nil then
        for _, i in ipairs(items) do
          ctx.item(i)
        end
        ctx.done()
        return
      end

      M.get_definitions(function(def_items)
        for _, i in ipairs(def_items) do
          ctx.item(i)
        end
        ctx.done()
      end)
    end,
    actions = u.tables.extend(actions.peek()),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for find references
---@param items? deck.Item[]
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.find_references(items, opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "lsp.find_references",
    execute = function(ctx)
      if items ~= nil then
        for _, i in ipairs(items) do
          ctx.item(i)
        end
        ctx.done()
        return
      end

      M.get_references(function(def_items)
        for _, i in ipairs(def_items) do
          ctx.item(i)
        end
        ctx.done()
      end)
    end,
    actions = u.tables.extend(actions.peek()),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
