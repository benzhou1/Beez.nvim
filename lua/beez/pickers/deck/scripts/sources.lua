local actions = require("beez.pickers.deck.projects.actions")
local decorators = require("beez.pickers.deck.projects.decorators")
local u = require("beez.u")
local utils = require("beez.pickers.deck.utils")
local M = {
  data = {
    scripts = {
      ["clean up work stuff"] = {
        cmd = {
          "uv",
          "--directory ~/.config/scripts/python",
          "run",
          "python",
          "~/.config/scripts/python/clean_up_work_stuff.py",
        },
      },
    },
  },
}

--- Deck source for picking a project
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.scripts(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "projects",
    execute = function(ctx)
      for name, d in pairs(M.data.scripts) do
        local item = {
          data = {
            cmd = d.cmd,
          },
          display_text = {
            { name, "String" },
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(actions.run_cmd_external.action({ quit = opts.quit }), {
      require("deck").alias_action("default", opts.default_action or actions.run_cmd_external.name),
    }),
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
