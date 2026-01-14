local actions = require("beez.pickers.deck.cmdcenter.actions")
local decorators = require("beez.pickers.deck.cmdcenter.decorators")
local u = require("beez.u")
local utils = require("beez.pickers.deck.utils")
local M = {}

--- Deck source for cmdcenter cmds
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.cmds(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "cmdcenter.cmds",
    execute = function(ctx)
      local cc = require("beez.cmdcenter")
      local cmds = cc.list()

      for _, c in ipairs(cmds) do
        local item = {
          display_text = { { c.name, "String" }, { " ", "String" }, { table.concat(c.cmd), "Comment" } },
          data = { cmd = c },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(actions.run_cmd()),
    decorators = { decorators.hash_tags() },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

function M.db_headers(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local cc = require("beez.cmdcenter")

  local source = utils.resolve_source(opts, {
    name = "cmdcenter.db.headers",
    execute = function(ctx)
      local headers = cc.db.get_headers()
      local header_values = cc.db.get_header_values()
      for i, h in ipairs(headers) do
        local item = {
          display_text = { { h, "String" }, { " ", "String" }, { header_values[i], "Comment" } },
          data = { header = h },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(actions.move_to_header()),
  })

  local specifier = utils.resolve_specifier(opts, {
    view = function()
      local view = require("deck.builtin.view.current_picker")()
      view.hide = function(ctx)
        vim.api.nvim_set_current_buf(cc.op.bufnr())
      end
      return view
    end,
  })
  return source, specifier
end

return M
