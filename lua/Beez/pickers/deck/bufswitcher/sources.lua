local actions = require("Beez.pickers.deck.bufswitcher.actions")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for bufswitcher stacks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.stacks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "bufswitcher.stacks",
    execute = function(ctx)
      local bs = require("Beez.bufswitcher")
      local stacks = bs.sl:list()
      -- Sort so that active stack is first
      table.sort(stacks, function(a, b)
        if a.name == bs.sl.active then
          return true
        end
        if b.name == bs.sl.active then
          return false
        end
        return a.name < b.name
      end)

      for _, s in ipairs(stacks) do
        local hl = "String"
        if s.name == bs.sl.active then
          hl = "Search"
        end
        local item = {
          display_text = { { s.name, hl } },
          data = { stack = s },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      actions.set_active_stack(),
      actions.add_stack(),
      actions.rename_stack(),
      actions.remove_stack()
    ),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
