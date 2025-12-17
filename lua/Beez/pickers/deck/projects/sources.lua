local actions = require("Beez.pickers.deck.projects.actions")
local decorators = require("Beez.pickers.deck.projects.decorators")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {
  data = {
    projects = {
      dotfiles = {
        path = vim.fn.expand("~/.local/share/chezmoi"),
      },
      config = {
        path = vim.fn.expand("~/.config"),
      },
      driverust = {
        path = vim.fn.expand("~/Projects/work-drive-rust"),
      },
      drive = {
        path = vim.fn.expand("~/Projects/set-changelog-client"),
        score_bonus = 5,
      },
      workflow = {
        path = vim.fn.expand("~/Projects/project_w"),
      },
      monoglow = {
        path = vim.fn.expand("~/Projects/nvim_forks/monoglow.nvim"),
      },
      kb = {
        path = vim.fn.expand("~/Projects/kb_firmware"),
      },
      macnative = {
        path = vim.fn.expand("~/Projects/work-drive-mac-native"),
      },
      beez = {
        path = vim.fn.expand("~/Projects/nvim_forks/Beez.nvim"),
      },
      pyscripts = {
        path = vim.fn.expand("~/Projects/ha_pyscripts"),
      },
      appdeamon = {
        path = vim.fn.expand("~/Projects/ha_app_daemon"),
      },
      zmkconfig = {
        path = vim.fn.expand("~/Projects/zmk"),
        root = vim.fn.expand("~/Projects/zmk/zmk-config"),
      },
      zmkataraxia = {
        path = vim.fn.expand("~/Projects/zmk"),
        root = vim.fn.expand("~/Projects/zmk/zmk-keyboards-ataraxia"),
      },
    },
  },
}

--- Deck source for picking a project
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.projects(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "projects",
    execute = function(ctx)
      for name, d in pairs(M.data.projects) do
        local item = {
          data = {
            path = d.path,
            root = d.root or d.path,
            name = name,
          },
          display_text = {
            { name, "String" },
          },
          score_bonus = d.score_bonus or 0,
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      actions.open_lazygit.action({ quit = opts.quit }),
      actions.open_neohub.action({ quit = opts.quit }),
      {
        require("deck").alias_action("default", opts.default_action or actions.open_neohub.name),
      }
    ),
    decorators = {
      decorators.root_path(),
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
